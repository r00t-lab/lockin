import Foundation
import Observation

/// Single source of truth for commitments. JSON in the App Group container so the
/// widget extension can read the same data without a database dependency.
///
/// Do not reach for SwiftData or Core Data here. There are at most a few dozen records,
/// they are written on user action only, and every hour you spend on a persistence
/// layer is an hour not spent filming.
@MainActor
@Observable
final class CommitmentStore {

    static let shared = CommitmentStore()

    private(set) var commitments: [Commitment] = []

    /// Free tier ceiling. The paywall exists because of this number — pick it once and
    /// do not soften it. Two is enough to feel the mechanic, not enough to live on.
    static let freeCommitmentLimit = 2

    private let filename = "commitments.json"

    private var fileURL: URL {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
            ?? URL.documentsDirectory
        return container.appending(path: filename)
    }

    private init() {
        load()
    }

    // MARK: - Queries

    /// Everything the user actually committed to. The rehearsal lives in the same array
    /// so that the alarm, intent and proof paths need no special case, but it is not a
    /// commitment — it must never show in the list, count against the free tier, or move
    /// a streak. Every query below goes through this; `commitments` is for the alarm layer.
    var visibleCommitments: [Commitment] {
        commitments.filter { !$0.isRehearsal }
    }

    var rehearsal: Commitment? {
        commitments.first(where: \.isRehearsal)
    }

    var activeCount: Int {
        visibleCommitments.filter(\.isEnabled).count
    }

    func canAddAnother(isPro: Bool) -> Bool {
        isPro || activeCount < Self.freeCommitmentLimit
    }

    func commitment(id: UUID) -> Commitment? {
        commitments.first { $0.id == id }
    }

    /// Everything the weekly report needs, in one pass.
    var weeklyStats: (proved: Int, missed: Int, bestStreak: Int) {
        visibleCommitments.reduce(into: (0, 0, 0)) { result, commitment in
            if commitment.isDoneToday { result.0 += 1 }
            result.1 += commitment.missCount
            result.2 = max(result.2, commitment.bestStreak)
        }
    }

    // MARK: - Mutations

    func add(_ commitment: Commitment) async throws {
        commitments.append(commitment)
        save()
        try await AlarmService.shared.schedule(commitment)
    }

    func update(_ commitment: Commitment) async throws {
        guard let index = commitments.firstIndex(where: { $0.id == commitment.id }) else { return }
        commitments[index] = commitment
        save()
        try await AlarmService.shared.schedule(commitment)
    }

    func delete(_ commitment: Commitment) async {
        commitments.removeAll { $0.id == commitment.id }
        save()
        await AlarmService.shared.cancel(commitment.id)
    }

    // MARK: - Rehearsal

    /// True while this commitment is being nagged and has not been proved. Drives the
    /// "Prove you started" card, which is the route to the proof screen that does not
    /// depend on the alarm's own button having worked.
    func needsProof(_ commitment: Commitment) -> Bool {
        !commitment.isDoneToday && AlarmService.shared.isMidChain(commitment.id)
    }

    /// What the proof screen should open onto when the app comes to the front.
    ///
    /// The intent behind the alarm's own button is not reliable enough to be the only
    /// way in — on device it silences the ring and does not always bring the app forward,
    /// which leaves someone holding a phone that is nagging them with no way to answer.
    /// So *opening the app at all* now counts as answering the alarm.
    ///
    /// Skipped once the user has said "I'm not doing it" for this occurrence. The alarm
    /// keeps nagging — that is its job, and it is the product — but a modal that reopens
    /// every time they return to the app is not nagging, it is a bug.
    var commitmentAwaitingProof: Commitment? {
        commitments.first { commitment in
            guard needsProof(commitment) else { return false }
            guard let chain = AlarmService.shared.chains[commitment.id] else { return false }
            guard let bailed = commitment.bailedAt else { return true }
            return bailed < chain.firstFire
        }
    }

    /// Arm a compressed run of the whole mechanic. See `Commitment.rehearsal`.
    ///
    /// The proof kind is the caller's choice and there is no sensible default: a timer
    /// rehearsal and a photo rehearsal exercise completely different screens, and picking
    /// one silently means whoever is testing gets the other one and concludes the camera
    /// is broken.
    func startRehearsal(proofKind: Commitment.ProofKind) async throws {
        await endRehearsal()

        let commitment = Commitment.rehearsal(
            firing: AlarmService.shared.rehearsalFireDate(),
            proofKind: proofKind
        )
        commitments.append(commitment)
        save()
        try await AlarmService.shared.schedule(commitment)
    }

    /// Tear it down without touching any streak. Called when the rehearsal is proved,
    /// dismissed for good, or cancelled from the list.
    func endRehearsal() async {
        guard let existing = rehearsal else { return }
        commitments.removeAll(where: \.isRehearsal)
        save()
        await AlarmService.shared.cancel(existing.id)
    }

    /// Count the occurrences that came and went while nobody was watching.
    ///
    /// This is the only thing that ever breaks a streak on iOS. Nothing reports a
    /// dismissed or ignored alarm to us, so a miss has to be derived from the schedule —
    /// see the occurrence section of `Commitment`. Idempotent: each commitment remembers
    /// how far it has been counted.
    func reconcile() {
        for index in commitments.indices where !commitments[index].isRehearsal {
            commitments[index].reconcile()
        }
        // Save unconditionally. `reconcile` moves each commitment's watermark whether or
        // not anything was missed, and dropping that write means walking the same window
        // again on the next launch. `save` pushes to the watch on its way out.
        save()
    }

    /// Repair chains that have been spent or aged out. Cheap and idempotent — call on
    /// every foreground.
    func refreshChains() async {
        reconcile()
        await AlarmService.shared.refreshChains(for: commitments)

        // A rehearsal is over the moment its chain runs out, whether it was proved,
        // dismissed five times, or simply ignored. Nothing else clears it, and a stale
        // "Rehearsal armed" banner on a rehearsal that will never ring again is worse
        // than no banner — it teaches the user the alarm lies.
        if let rehearsal, AlarmService.shared.isSpent(rehearsal.id) {
            await endRehearsal()
        }
    }

    // MARK: - Occurrences

    /// The happy path: user proved they started.
    func recordProof(for commitmentID: UUID) async {
        guard let index = commitments.firstIndex(where: { $0.id == commitmentID }) else { return }

        // A rehearsal proves nothing about a real habit. Clear the chain, drop the row,
        // leave the streak alone — otherwise the demo would inflate the number the app
        // exists to keep honest.
        guard !commitments[index].isRehearsal else {
            await endRehearsal()
            return
        }

        commitments[index].recordProof()
        save()
        await AlarmService.shared.clearNags(for: commitmentID)

        // Put the next occurrence back on the schedule — `clearNags` cancelled the ring
        // along with the nags, and a one-off is genuinely finished.
        if commitments[index].repeats.isRecurring {
            try? await AlarmService.shared.schedule(commitments[index])
        }
    }

    /// User walked away from the proof screen without proving.
    ///
    /// This does **not** schedule anything. The nag chain was written in full when the
    /// alarm was scheduled, precisely because on iOS nothing tells us the user hit Stop
    /// — see the header of `AlarmService`. All that is left to record is the miss.
    func recordDismissal(for commitmentID: UUID) async {
        guard let index = commitments.firstIndex(where: { $0.id == commitmentID }) else { return }

        guard !commitments[index].isRehearsal else {
            await endRehearsal()
            return
        }

        commitments[index].recordMiss()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        commitments = (try? JSONDecoder().decode([Commitment].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(commitments) else { return }
        try? data.write(to: fileURL, options: .atomic)

        // Every mutation funnels through here, so this is the one place the wrist has to
        // be told about. WatchConnectivity coalesces application context updates, so
        // pushing on every save costs a dictionary and nothing else.
    }
}
