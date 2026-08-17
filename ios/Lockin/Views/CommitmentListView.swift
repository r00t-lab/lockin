import SwiftUI

/// Home screen. Deliberately boring — the product's personality lives in the alarm,
/// not here. A list, a streak, one button.
struct CommitmentListView: View {

    @Binding var proofTarget: Commitment?

    @Environment(CommitmentStore.self) private var store
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var showNewCommitment = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                if !store.commitments.isEmpty {
                    Section {
                        statsRow
                    }
                }

                Section {
                    ForEach(store.commitments) { commitment in
                        CommitmentRow(commitment: commitment)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    Task { await store.delete(commitment) }
                                }
                            }
                    }
                } header: {
                    if !store.commitments.isEmpty {
                        Text("Commitments")
                    }
                }

                if store.commitments.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Nagg")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if store.canAddAnother(isPro: subscriptions.isPro) {
                            showNewCommitment = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewCommitment) {
                NewCommitmentView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var statsRow: some View {
        let stats = store.weeklyStats
        return HStack {
            stat("\(stats.bestStreak)", "best streak")
            Divider()
            stat("\(stats.proved)", "done today")
            Divider()
            stat("\(stats.missed)", "excuses")
        }
        .frame(maxWidth: .infinity)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing holding you accountable", systemImage: "lock.open")
        } description: {
            Text("Add the thing you keep putting off. Nagg will make sure you can't ignore it.")
        } actions: {
            Button("Add a commitment") { showNewCommitment = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct CommitmentRow: View {
    let commitment: Commitment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(commitment.title)
                    .font(.headline)
                    .strikethrough(commitment.isDoneToday)
                Text(commitment.fireDate.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if commitment.currentStreak > 0 {
                Text("\(commitment.currentStreak)🔥")
                    .font(.callout.weight(.semibold))
            }
        }
        .opacity(commitment.isEnabled ? 1 : 0.4)
    }
}
