import SwiftUI

/// Home screen. Deliberately boring — the product's personality lives in the alarm,
/// not here. A list, a streak, one button.
struct CommitmentListView: View {

    @Binding var proofTarget: Commitment?

    @Environment(CommitmentStore.self) private var store
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var showNewCommitment = false
    @State private var showPaywall = false
    @State private var rehearsalError: String?

    var body: some View {
        NavigationStack {
            List {
                if store.rehearsal != nil {
                    Section { rehearsalBanner }
                }

                if !store.visibleCommitments.isEmpty {
                    Section {
                        statsRow
                    }
                }

                Section {
                    ForEach(store.visibleCommitments) { commitment in
                        CommitmentRow(commitment: commitment)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    Task { await store.delete(commitment) }
                                }
                            }
                    }
                } header: {
                    if !store.visibleCommitments.isEmpty {
                        Text("Commitments")
                    }
                }

                if store.visibleCommitments.isEmpty {
                    emptyState
                }

                Section {
                    rehearsalButton
                } footer: {
                    Text("Rings in 20 seconds, then every 30 — the real alarm on fast-forward. Put the phone down and don't prove anything; that's the part worth seeing.")
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

    // MARK: - Rehearsal
    //
    // The one screen where showing the user the alarm is better than describing it. It
    // doubles as the only practical way to verify the nag chain on a device — a real run
    // takes ten minutes, this takes under three — and as the shot for every video.

    private var rehearsalButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task {
                    do {
                        guard await AlarmService.shared.ensureAuthorized() else {
                            rehearsalError = "Nagg needs alarm permission before it can ring."
                            return
                        }
                        rehearsalError = nil
                        try await store.startRehearsal()
                    } catch {
                        rehearsalError = "Couldn't schedule the rehearsal: \(error.localizedDescription)"
                    }
                }
            } label: {
                Label("Rehearse the alarm", systemImage: "bell.badge.waveform")
            }

            if let rehearsalError {
                Text(rehearsalError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var rehearsalBanner: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rehearsal armed")
                    .font(.headline)
                Text("Lock the phone. It rings even on Silent.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Stop", role: .destructive) {
                Task { await store.endRehearsal() }
            }
            .font(.footnote.weight(.semibold))
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
