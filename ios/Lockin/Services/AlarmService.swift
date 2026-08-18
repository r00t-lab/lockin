import AlarmKit
import Foundation
import OSLog
import SwiftUI

// Tuning lives at file scope, not as properties. The `nonisolated` helpers in
// `AlarmService` read these, and a stored constant on a `@MainActor` type is one
// Swift-version argument away from needing an `await` to look at. File-scope constants
// end that argument.

/// How long after a ring the next nag lands.
private let nagInterval: TimeInterval = 120
/// Stop nagging eventually. Being unstoppable is a feature; being a bug report is not.
private let maxNags = 5

/// A rehearsal replays the whole chain in under three minutes instead of ten. Same code
/// path, compressed clock — see `Commitment.rehearsal`.
private let rehearsalLeadIn: TimeInterval = 20
private let rehearsalNagInterval: TimeInterval = 30

/// What we scheduled for one commitment.
///
/// Persisted, and not only as a convenience: proof has to cancel a chain that was written
/// before the process was last killed, and `refreshChains` has to know when a chain has
/// aged out without having been able to watch it fire.
///
/// Top level rather than nested in `AlarmService` — a type nested inside a `@MainActor`
/// class is a standing question about whether it picks up that isolation, and this one
/// crosses to `nonisolated` code.
struct AlarmChain: Codable, Sendable {
    /// Index 0 is the ring; the rest is the nag chain in order.
    var alarmIDs: [UUID]
    /// When the ring goes off. The nags hang off this.
    var firstFire: Date
    /// The moment the last nag has fired and the chain is spent.
    var expiresAt: Date
}

/// One rung of a chain.
private struct AlarmLink: Sendable {
    let alarmID: UUID
    /// 0 is the ring itself; 1...maxNags are the nags that follow it.
    let step: Int
    /// An exact time, or nil to use the commitment's own repeating rule.
    let fireDate: Date?

    var isNag: Bool { step > 0 }
}

/// Owns every interaction with AlarmKit.
///
/// ## The one mechanic that matters
/// AlarmKit always renders a Stop button and Apple will not let you remove it — an alarm
/// the user physically cannot silence would never pass review. So "you can't dismiss it
/// without proof" is not enforced by hiding Stop. It is enforced by the **nag chain**:
/// the ring comes back, and back, until the user proves they started.
///
/// ## Why the chain is scheduled up front
/// The obvious implementation is reactive: user taps Stop → we schedule the next nag.
/// **That cannot work on iOS.** AlarmKit's Stop button belongs to the system. It does not
/// launch us, does not run an App Intent, and does not deliver a callback. Neither does
/// letting the ring time out untouched. The one and only path that wakes this process is
/// the *secondary* button ("I'm starting"), which is precisely the path where we do not
/// want to nag. So a reactive chain is a chain that never fires — the product's entire
/// thesis, quietly absent. (Android is reactive and correct, because there the ringing
/// service is our own process. Do not port that shape back here.)
///
/// Instead `schedule(_:)` writes the whole chain at once: the ring, then `maxNags` fixed
/// alarms spaced `nagInterval` apart. They fire whether or not we are alive to see it.
/// `clearNags` tears the rest down the moment proof lands. Escaping still costs the user
/// six deliberate taps spread over ten minutes, which is the point.
///
/// The cost is that the chain for a *repeating* commitment only covers the next
/// occurrence — the nags are fixed dates, the ring is a weekly rule. Proof reschedules
/// it, and so does `refreshChains()` on foreground. A user who never opens the app again
/// still gets the ring; they just stop getting nagged. That degradation is acceptable and
/// deliberate; do not "fix" it by scheduling a week of chains, which blows the alarm budget.
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

    private(set) var authorizationState: AlarmManager.AuthorizationState = .notDetermined

    private(set) var chains: [UUID: AlarmChain] = [:] {
        didSet { persistChains() }
    }

    private let chainsKey = "lockin.alarmChains"
    private var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    private init() {
        loadChains()
    }

    // MARK: - The isolation boundary
    //
    // AlarmManager and AlarmConfiguration are not Sendable. Holding the manager as a
    // property of this @MainActor class, or building a configuration here and then
    // awaiting a call with it, means sending non-Sendable state across an isolation
    // boundary — an error under Swift 6, and a real data race under Swift 5.
    //
    // So every call that actually touches AlarmKit lives in a `nonisolated` helper
    // that builds what it needs locally. Only `Commitment` and `AlarmLink` cross the
    // boundary, and both are Sendable. Do not move these back inline "to simplify".

    private nonisolated func performSchedule(_ link: AlarmLink, commitment: Commitment) async throws {
        let configuration = try makeConfiguration(for: commitment, link: link)
        do {
            _ = try await AlarmManager.shared.schedule(id: link.alarmID, configuration: configuration)
        } catch {
            NaggLog.alarms.error(
                "NAGG schedule failed: step=\(link.step, privacy: .public) \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    private nonisolated func performCancel(alarmID: UUID) async {
        try? await AlarmManager.shared.cancel(id: alarmID)
    }

    private nonisolated func performAuthorizationRequest() async throws -> AlarmManager.AuthorizationState {
        try await AlarmManager.shared.requestAuthorization()
    }

    // MARK: - Authorization

    /// Ask once, at the moment the user creates their first commitment — never on launch.
    /// A cold permission prompt on launch is the single biggest conversion leak in this
    /// category; the user has to want the alarm before they are asked to allow it.
    @discardableResult
    func ensureAuthorized() async -> Bool {
        authorizationState = AlarmManager.shared.authorizationState
        switch authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let state = try await performAuthorizationRequest()
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

    /// Schedule (or reschedule) the ring **and its whole nag chain** for a commitment.
    ///
    /// The ring is scheduled with `try`: if it fails the caller must hear about it, an
    /// alarm that silently did not arm is the worst bug this app can ship. The nags are
    /// best-effort — a device at its alarm limit should still get the ring rather than
    /// have the whole commitment fail because rung four would not fit.
    func schedule(_ commitment: Commitment) async throws {
        await cancel(commitment.id)
        guard commitment.isEnabled else { return }

        let firstFire = nextFire(for: commitment)
        let spacing = nagSpacing(for: commitment)
        var ids: [UUID] = []

        let ring = AlarmLink(
            alarmID: UUID(),
            step: 0,
            fireDate: commitment.repeats.isRecurring ? nil : firstFire
        )
        try await performSchedule(ring, commitment: commitment)
        ids.append(ring.alarmID)

        for step in 1...maxNags {
            let link = AlarmLink(
                alarmID: UUID(),
                step: step,
                fireDate: firstFire.addingTimeInterval(spacing * Double(step))
            )
            do {
                try await performSchedule(link, commitment: commitment)
                ids.append(link.alarmID)
            } catch {
                break
            }
        }

        chains[commitment.id] = AlarmChain(
            alarmIDs: ids,
            firstFire: firstFire,
            expiresAt: firstFire.addingTimeInterval(spacing * Double(maxNags))
        )

        // `ids.count` is the number that matters. One means the ring armed and every nag
        // was refused — the product silently reduced to an ordinary alarm, which is the
        // failure this whole file was rewritten to prevent and is invisible from the UI.
        NaggLog.alarms.notice(
            "NAGG scheduled: commitment=\(commitment.id, privacy: .public) alarms=\(ids.count, privacy: .public) firstFire=\(firstFire.timeIntervalSince1970, privacy: .public) spacing=\(spacing, privacy: .public)"
        )
    }

    /// Proof accepted. Tear the chain down.
    func clearNags(for commitmentID: UUID) async {
        await cancel(commitmentID)
    }

    func cancel(_ commitmentID: UUID) async {
        guard let chain = chains[commitmentID] else { return }
        for alarmID in chain.alarmIDs {
            await performCancel(alarmID: alarmID)
        }
        chains[commitmentID] = nil
    }

    func cancelAll() async {
        for commitmentID in chains.keys {
            await cancel(commitmentID)
        }
    }

    /// No chain left, or one whose last nag is behind us. A missing chain counts as
    /// spent: `observeAlarmUpdates` drops the entry once every alarm in it has gone.
    func isSpent(_ commitmentID: UUID) -> Bool {
        guard let chain = chains[commitmentID] else { return true }
        return chain.expiresAt < .now
    }

    /// The ring has happened and the chain has not run out: this commitment is being
    /// nagged *right now*, whether or not an alarm is making noise this second.
    ///
    /// The list screen uses this to offer proof directly. That matters more than it
    /// looks: until now the only route to the proof screen was the alarm's "I'm starting"
    /// button firing an App Intent, so anything that swallowed that tap — the user
    /// opening the app themselves, a banner rather than the full-screen alert, an intent
    /// that simply did not run — left them with no way to prove anything and no way to
    /// stop the nagging. One system button on someone else's surface is too thin a thread
    /// to hang the whole product on.
    func isMidChain(_ commitmentID: UUID) -> Bool {
        guard let chain = chains[commitmentID] else { return false }
        return chain.firstFire <= .now && .now <= chain.expiresAt
    }

    /// Re-arm any commitment whose chain has been spent or has drifted into the past.
    ///
    /// Call on foreground. A repeating commitment's nags are fixed dates covering exactly
    /// one occurrence, so without this the second morning rings but never nags. The check
    /// is on the clock rather than on how many ids survive, because `observeAlarmUpdates`
    /// only prunes while we are running — a chain consumed with the app closed still looks
    /// complete on the next launch.
    ///
    /// Repeating commitments only. A one-off that has already fired is finished, and
    /// re-arming it here would quietly turn "once" into "every day at this time".
    func refreshChains(for commitments: [Commitment]) async {
        for commitment in commitments
        where commitment.isEnabled && commitment.repeats.isRecurring && !commitment.isRehearsal {
            // Only the clock decides. A chain that came up short because the device was
            // at its alarm limit is not worth retrying on every single foreground.
            if let expiry = chains[commitment.id]?.expiresAt, expiry >= .now { continue }
            try? await schedule(commitment)
        }
    }

    /// Mirror AlarmKit's own state back into ours. Alarms can disappear underneath us
    /// (fired and stopped, user deleted from the system UI, device restored), and a stale
    /// id means we would try to cancel something that no longer exists.
    func observeAlarmUpdates() async {
        for await alarms in AlarmManager.shared.alarmUpdates {
            let live = Set(alarms.map(\.id))
            for (commitmentID, chain) in chains {
                let survivors = chain.alarmIDs.filter(live.contains)
                guard survivors.count != chain.alarmIDs.count else { continue }
                if survivors.isEmpty {
                    chains[commitmentID] = nil
                } else {
                    chains[commitmentID]?.alarmIDs = survivors
                }
            }

            // Forward the same batch to the wrist. This is the only signal the watch app
            // cannot get for itself — AlarmKit has no watchOS surface, the ring reaches
            // the wrist by system mirroring and tells our code nothing. Do not add a
            // second `for await alarms in manager.alarmUpdates` elsewhere to get it;
            // that sequence is not safe to iterate twice.
            WatchSyncService.shared.announceRinging(alarms)
        }
    }

    // MARK: - Timing

    private nonisolated func nagSpacing(for commitment: Commitment) -> TimeInterval {
        commitment.isRehearsal ? rehearsalNagInterval : nagInterval
    }

    /// When the ring will actually go off. Anchors the nag chain.
    private nonisolated func nextFire(for commitment: Commitment) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = commitment.hour
        components.minute = commitment.minute

        guard commitment.repeats.isRecurring else {
            // A one-off keeps the exact date it was given, seconds included. Matching on
            // hour/minute here would push an alarm set for 90 seconds from now to the
            // same clock minute *tomorrow* — which is how a rehearsal silently never rings.
            if commitment.fireDate > Date().addingTimeInterval(1) {
                return commitment.fireDate
            }
            return calendar.nextDate(
                after: .now,
                matching: components,
                matchingPolicy: .nextTime
            ) ?? Date().addingTimeInterval(60)
        }

        // Walk forward to the first day the commitment actually repeats on. Re-matching
        // each step rather than adding 24h keeps the wall-clock time correct across a
        // daylight-saving change.
        var candidate = calendar.nextDate(after: .now, matching: components, matchingPolicy: .nextTime)
        for _ in 0..<7 {
            guard let date = candidate else { break }
            if commitment.repeats.weekdays.contains(calendar.component(.weekday, from: date)) {
                return date
            }
            candidate = calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
        }
        return candidate ?? Date().addingTimeInterval(60)
    }

    /// A rehearsal ring, far enough out that the user can put the phone down first.
    nonisolated func rehearsalFireDate() -> Date {
        Date().addingTimeInterval(rehearsalLeadIn)
    }

    // MARK: - Persistence

    private func loadChains() {
        guard let data = defaults.data(forKey: chainsKey),
              let stored = try? JSONDecoder().decode([UUID: AlarmChain].self, from: data) else { return }
        chains = stored
    }

    private func persistChains() {
        guard let data = try? JSONEncoder().encode(chains) else { return }
        defaults.set(data, forKey: chainsKey)
    }

    // MARK: - AlarmKit plumbing (the only API-drift-prone part)

    private nonisolated func makeConfiguration(
        for commitment: Commitment,
        link: AlarmLink
    ) throws -> AlarmManager.AlarmConfiguration<LockinMetadata> {

        let stopButton = AlarmButton(
            text: link.isNag ? "Still not started" : "Dismiss",
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
            // Not `Color.accentColor`. There is no AccentColor in the asset catalog, so
            // that resolved to system blue — the alarm, the one surface people photograph,
            // was wearing another app's colour.
            tintColor: Nagg.alarm
        )

        return AlarmManager.AlarmConfiguration(
            schedule: try makeSchedule(for: commitment, link: link),
            attributes: attributes,
            secondaryIntent: ProofIntent(commitmentID: commitment.id.uuidString),
            sound: .default
        )
    }

    private nonisolated func makeSchedule(
        for commitment: Commitment,
        link: AlarmLink
    ) throws -> Alarm.Schedule {

        // Nags — and one-off rings — are always an exact moment, never a weekly pattern.
        if let fireDate = link.fireDate {
            return .fixed(fireDate)
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
