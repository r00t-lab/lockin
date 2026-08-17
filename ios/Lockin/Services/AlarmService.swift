import AlarmKit
import Foundation
import SwiftUI

/// Owns every interaction with AlarmKit.
///
/// ## The one mechanic that matters
/// AlarmKit always renders a Stop button and Apple will not let you remove it — an alarm
/// the user physically cannot silence would never pass review. So "you can't dismiss it
/// without proof" is not enforced by hiding Stop. It is enforced by the **nag loop**:
///
///   1. The commitment alarm fires (through Silent + Focus, that is the AlarmKit gift).
///   2. Secondary button = "I'm starting" → opens the app straight to the proof screen.
///   3. Stop button = silences *this* ring, then `scheduleNag` puts another alarm
///      `nagInterval` later. Up to `maxNags` times.
///   4. Proof recorded → `clearNags` cancels the whole chain.
///
/// This is the same shape as Alarmy's anti-cheat, which is the moat on a $500K/mo app.
/// Do not water it down: if the nag loop is polite, the product has no reason to exist.
///
/// ## API drift warning
/// AlarmKit shipped in iOS 26 and the signatures moved between betas. Everything Apple
/// might have renamed is isolated in `makeConfiguration` and `makeSchedule` below. If the
/// project does not build on your Mac, those two functions are the only place to look —
/// let Xcode autocomplete fill them in and leave the rest of this file alone.
@MainActor
@Observable
final class AlarmService {

    static let shared = AlarmService()

    /// How long after a dismissed-without-proof ring we come back.
    private let nagInterval: TimeInterval = 120
    /// Stop nagging eventually. Being unstoppable is a feature; being a bug report is not.
    private let maxNags = 5

    private(set) var authorizationState: AlarmManager.AuthorizationState = .notDetermined
    /// Alarm ids currently live, keyed by the commitment they belong to.
    private(set) var scheduledAlarmIDs: [UUID: UUID] = [:]

    /// Nag counts have to survive process death. Two rings are two minutes apart and iOS
    /// will happily terminate us in between — an in-memory counter resets every time,
    /// which quietly turns "at most 5 nags" into "forever". Found by the Android port,
    /// where the process is killed far more aggressively.
    private var nagCounts: [UUID: Int] {
        get {
            let raw = defaults.dictionary(forKey: nagCountsKey) as? [String: Int] ?? [:]
            return raw.reduce(into: [:]) { out, pair in
                if let id = UUID(uuidString: pair.key) { out[id] = pair.value }
            }
        }
        set {
            let raw = newValue.reduce(into: [String: Int]()) { out, pair in
                out[pair.key.uuidString] = pair.value
            }
            defaults.set(raw, forKey: nagCountsKey)
        }
    }

    private let nagCountsKey = "lockin.nagCounts"
    private var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    private let manager = AlarmManager.shared

    private init() {}

    // MARK: - Authorization

    /// Ask once, at the moment the user creates their first commitment — never on launch.
    /// A cold permission prompt on launch is the single biggest conversion leak in this
    /// category; the user has to want the alarm before they are asked to allow it.
    @discardableResult
    func ensureAuthorized() async -> Bool {
        authorizationState = manager.authorizationState
        switch authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let state = try await manager.requestAuthorization()
                authorizationState = state
                return state == .authorized
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    /// Schedule (or reschedule) the alarm chain for a commitment.
    func schedule(_ commitment: Commitment) async throws {
        await cancel(commitment.id)
        guard commitment.isEnabled else { return }

        let alarmID = UUID()
        let configuration = try makeConfiguration(for: commitment, isNag: false)
        _ = try await manager.schedule(id: alarmID, configuration: configuration)

        scheduledAlarmIDs[commitment.id] = alarmID
        nagCounts[commitment.id] = 0
    }

    /// Called when the user hit Stop but has not proved they started.
    /// Returns false once we have run out of patience so the UI can stop promising more.
    @discardableResult
    func scheduleNag(for commitment: Commitment) async throws -> Bool {
        let count = nagCounts[commitment.id, default: 0]
        guard count < maxNags else { return false }

        let alarmID = UUID()
        let configuration = try makeConfiguration(for: commitment, isNag: true)
        _ = try await manager.schedule(id: alarmID, configuration: configuration)

        scheduledAlarmIDs[commitment.id] = alarmID
        nagCounts[commitment.id] = count + 1
        return true
    }

    /// Proof accepted. Tear the chain down.
    func clearNags(for commitmentID: UUID) async {
        await cancel(commitmentID)
        nagCounts[commitmentID] = 0
    }

    func cancel(_ commitmentID: UUID) async {
        guard let alarmID = scheduledAlarmIDs[commitmentID] else { return }
        try? await manager.cancel(id: alarmID)
        scheduledAlarmIDs[commitmentID] = nil
    }

    func cancelAll() async {
        for commitmentID in scheduledAlarmIDs.keys {
            await cancel(commitmentID)
        }
        nagCounts.removeAll()
    }

    /// Mirror AlarmKit's own state back into ours. Alarms can disappear underneath us
    /// (user deleted from the system UI, device restored), and a stale id means a
    /// commitment silently stops firing — the worst possible bug for this app.
    func observeAlarmUpdates() async {
        for await alarms in manager.alarmUpdates {
            let live = Set(alarms.map(\.id))
            for (commitmentID, alarmID) in scheduledAlarmIDs where !live.contains(alarmID) {
                scheduledAlarmIDs[commitmentID] = nil
            }

            // Forward the same batch to the wrist. This is the only signal the watch app
            // cannot get for itself — AlarmKit has no watchOS surface, the ring reaches
            // the wrist by system mirroring and tells our code nothing. Do not add a
            // second `for await alarms in manager.alarmUpdates` elsewhere to get it;
            // that sequence is not safe to iterate twice.
            WatchSyncService.shared.announceRinging(alarms)
        }
    }

    // MARK: - AlarmKit plumbing (the only API-drift-prone part)

    private func makeConfiguration(
        for commitment: Commitment,
        isNag: Bool
    ) throws -> AlarmManager.AlarmConfiguration<LockinMetadata> {

        let stopButton = AlarmButton(
            text: isNag ? "Still not started" : "Dismiss",
            textColor: .white,
            systemImageName: "xmark"
        )

        let proofButton = AlarmButton(
            text: "I'm starting",
            textColor: .white,
            systemImageName: commitment.proofKind.systemImageName
        )

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: commitment.title),
            stopButton: stopButton,
            secondaryButton: proofButton,
            secondaryButtonBehavior: .custom
        )

        let attributes = AlarmAttributes<LockinMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: LockinMetadata(commitment: commitment),
            tintColor: Color.accentColor
        )

        return AlarmManager.AlarmConfiguration(
            schedule: try makeSchedule(for: commitment, isNag: isNag),
            attributes: attributes,
            secondaryIntent: ProofIntent(commitmentID: commitment.id.uuidString),
            sound: .default
        )
    }

    private func makeSchedule(
        for commitment: Commitment,
        isNag: Bool
    ) throws -> Alarm.Schedule {

        // A nag is always "n seconds from right now", never on the weekly pattern.
        if isNag {
            return .fixed(Date().addingTimeInterval(nagInterval))
        }

        guard commitment.repeats.isRecurring else {
            // One-off. If the time has already passed today, roll to tomorrow rather
            // than scheduling in the past (AlarmKit throws on past dates).
            let next = nextOccurrence(hour: commitment.hour, minute: commitment.minute)
            return .fixed(next)
        }

        let time = Alarm.Schedule.Relative.Time(
            hour: commitment.hour,
            minute: commitment.minute
        )
        let weekdays = commitment.repeats.weekdays
            .sorted()
            .compactMap(Locale.Weekday.init(calendarWeekdayIndex:))

        return .relative(
            Alarm.Schedule.Relative(
                time: time,
                repeats: .weekly(weekdays)
            )
        )
    }

    private func nextOccurrence(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return calendar.nextDate(
            after: .now,
            matching: components,
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(60)
    }
}

private extension Locale.Weekday {
    /// `Calendar` uses 1 = Sunday ... 7 = Saturday. `Locale.Weekday` is a named enum.
    init?(calendarWeekdayIndex index: Int) {
        switch index {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
