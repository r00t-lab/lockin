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

    var activeCount: Int {
        commitments.filter(\.isEnabled).count
    }

    func canAddAnother(isPro: Bool) -> Bool {
        isPro || activeCount < Self.freeCommitmentLimit
    }

    func commitment(id: UUID) -> Commitment? {
        commitments.first { $0.id == id }
    }

    /// Everything the weekly report needs, in one pass.
    var weeklyStats: (proved: Int, missed: Int, bestStreak: Int) {
        commitments.reduce(into: (0, 0, 0)) { result, commitment in
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

    /// The happy path: user proved they started.
    func recordProof(for commitmentID: UUID) async {
        guard let index = commitments.firstIndex(where: { $0.id == commitmentID }) else { return }
        commitments[index].recordProof()
        save()
        await AlarmService.shared.clearNags(for: commitmentID)

        // Recurring commitments need their next occurrence put back on the schedule,
        // because clearNags cancelled the live alarm along with the nag chain.
        if commitments[index].repeats.isRecurring {
            try? await AlarmService.shared.schedule(commitments[index])
        }
    }

    /// User hit Stop without proving. Start (or continue) the nag chain.
    func recordDismissal(for commitmentID: UUID) async {
        guard let index = commitments.firstIndex(where: { $0.id == commitmentID }) else { return }
        commitments[index].recordMiss()
        save()

        let stillNagging = (try? await AlarmService.shared.scheduleNag(for: commitments[index])) ?? false
        if !stillNagging, commitments[index].repeats.isRecurring {
            try? await AlarmService.shared.schedule(commitments[index])
        }
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
        WatchSyncService.shared.pushSnapshot()
    }
}
