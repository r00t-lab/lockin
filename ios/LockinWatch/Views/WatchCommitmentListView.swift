import SwiftUI

/// The wrist home screen. Same job as `CommitmentListView` on the phone and the same
/// personality: none. What is next, how long the streak is, and a way in.
///
/// Notably missing: adding, editing and deleting commitments. Setting an alarm is a
/// typing task and the wrist is not a typing surface — the phone owns creation, the
/// wrist owns the moment it fires. Do not add a plus button here.
struct WatchCommitmentListView: View {

    @Environment(PhoneSyncService.self) private var sync

    var body: some View {
        NavigationStack {
            List {
                if let next = sync.payload.nextUp {
                    Section {
                        nextUpRow(next)
                    } header: {
                        Text("Next")
                    }
                }

                if !others.isEmpty {
                    Section {
                        ForEach(others) { commitment in
                            NavigationLink {
                                WristProofView(commitment: commitment, isRinging: false)
                            } label: {
                                CommitmentRow(commitment: commitment)
                            }
                        }
                    } header: {
                        Text("Later")
                    }
                }

                if sync.payload.commitments.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Lockin")
        }
    }

    /// Everything except the one already shown under "Next".
    private var others: [Commitment] {
        let nextID = sync.payload.nextUp?.id
        return sync.payload.commitments.filter { $0.id != nextID }
    }

    private func nextUpRow(_ commitment: Commitment) -> some View {
        NavigationLink {
            WristProofView(commitment: commitment, isRinging: false)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(commitment.title)
                    .font(.headline)
                    .lineLimit(2)

                if let fire = commitment.nextFireDate() {
                    Text(fire, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if commitment.currentStreak > 0 {
                    Text("\(commitment.currentStreak) day streak on the line")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing set", systemImage: "lock.open")
        } description: {
            Text("Add a commitment on your iPhone. It'll show up here.")
        }
    }
}

private struct CommitmentRow: View {
    let commitment: Commitment

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(commitment.title)
                .font(.body)
                .strikethrough(commitment.isDoneToday)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(commitment.fireDate.formatted(date: .omitted, time: .shortened))
                if commitment.currentStreak > 0 {
                    Text("· \(commitment.currentStreak)🔥")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .opacity(commitment.isEnabled ? 1 : 0.4)
    }
}
