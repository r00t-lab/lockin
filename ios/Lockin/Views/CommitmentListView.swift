import SwiftUI

/// Home screen.
///
/// Not a `List`. The stock grouped list was the right instinct for "the personality lives
/// in the alarm" and the wrong call for a product whose distribution is screen recordings
/// — a system list is the one visual that guarantees nobody can tell this app from the
/// other twelve. The layout below is the prototype's, one-to-one: wordmark, a three-up
/// figure strip, hairline cards, and the rehearse rail pinned at the bottom.
///
/// Everything visual comes from `Nagg`. If you find yourself typing a colour or a font
/// size literal in this file, it belongs in `NaggStyle.swift` instead.
struct CommitmentListView: View {

    @Environment(CommitmentStore.self) private var store
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var showNewCommitment = false
    @State private var showPaywall = false
    @State private var rehearsalError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            figures

            ScrollView {
                LazyVStack(spacing: 10) {
                    if let rehearsal = store.rehearsal {
                        RehearsalCard(commitment: rehearsal) {
                            Task { await store.endRehearsal() }
                        }
                    }

                    if store.visibleCommitments.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.visibleCommitments) { commitment in
                            CommitmentCard(commitment: commitment) {
                                Task { await store.delete(commitment) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }

            rail
        }
        .naggGround()
        .sheet(isPresented: $showNewCommitment) { NewCommitmentView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            // The one place a second colour is allowed to be decorative. It is also the
            // app's whole logo — there is no mark, and there does not need to be one.
            (Text("na").foregroundStyle(Nagg.ink) + Text("gg").foregroundStyle(Nagg.alarm))
                .font(Nagg.mono(17))
                .tracking(-0.3)

            Spacer()

            Button {
                if store.canAddAnother(isPro: subscriptions.isPro) {
                    showNewCommitment = true
                } else {
                    showPaywall = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Nagg.ink)
                    .frame(width: 34, height: 34)
                    .overlay { Circle().stroke(Nagg.line, lineWidth: 1) }
            }
            .accessibilityLabel("New commitment")
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    /// Three numbers, hairline-separated. The middle one is the only one that moves on a
    /// good day, which is the point of putting "excuses" next to it.
    private var figures: some View {
        let stats = store.weeklyStats
        return HStack(spacing: 1) {
            figure("\(stats.bestStreak)", "streak")
            figure("\(stats.proved)", "today")
            figure("\(stats.missed)", "excuses")
        }
        .background(Nagg.line)
        .overlay(alignment: .top) { Rectangle().fill(Nagg.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Nagg.line).frame(height: 1) }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .naggFigure(26)
                .foregroundStyle(Nagg.ink)
            Text(label).naggLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Nagg.ground)
    }

    private var rail: some View {
        VStack(spacing: 9) {
            Button("Rehearse the alarm") {
                Task { await armRehearsal() }
            }
            .buttonStyle(NaggPrimaryButton())
            .disabled(store.rehearsal != nil)
            .opacity(store.rehearsal == nil ? 1 : 0.4)

            Text(rehearsalError ?? "Rings in 20 seconds, then every 30 — the real thing on fast-forward. Put the phone down and prove nothing; that's the part worth watching.")
                .font(Nagg.sans(12))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(rehearsalError == nil ? Nagg.ink3 : Nagg.alarm)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
    }

    private func armRehearsal() async {
        guard await AlarmService.shared.ensureAuthorized() else {
            rehearsalError = "Nagg needs alarm permission before it can ring. Allow it in Settings."
            return
        }
        do {
            rehearsalError = nil
            try await store.startRehearsal()
        } catch {
            rehearsalError = "Couldn't schedule the rehearsal: \(error.localizedDescription)"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Nothing is holding you to anything.")
            Text("Add the thing you keep putting off.")
        }
        .font(Nagg.sans(14))
        .lineSpacing(4)
        .multilineTextAlignment(.center)
        .foregroundStyle(Nagg.ink2)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 22)
        .overlay {
            RoundedRectangle(cornerRadius: Nagg.radius)
                .stroke(Nagg.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
    }
}

// MARK: - Cards

private struct CommitmentCard: View {
    let commitment: Commitment
    let onDelete: () -> Void

    private var isDone: Bool { commitment.isDoneToday }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(commitment.title)
                    .font(Nagg.sans(15, .medium))
                    .strikethrough(isDone, pattern: .solid)
                    .foregroundStyle(isDone ? Nagg.go : Nagg.ink)

                Text(meta)
                    .font(Nagg.mono(12, .regular))
                    .monospacedDigit()
                    .foregroundStyle(isDone ? Nagg.go : Nagg.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if commitment.currentStreak > 0 {
                Text("\(commitment.currentStreak)")
                    .naggFigure(15)
                    .foregroundStyle(isDone ? Nagg.go : Nagg.ink)
            }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Nagg.ink3)
                    .padding(4)
            }
            .accessibilityLabel("Delete \(commitment.title)")
        }
        .naggCard(done: isDone)
        .opacity(commitment.isEnabled ? 1 : 0.4)
    }

    /// "07:00 · Mon–Fri · photo". Mono, because the user scans it rather than reads it.
    private var meta: String {
        var parts = [commitment.fireDate.formatted(date: .omitted, time: .shortened)]
        if let days = commitment.repeats.shortLabel { parts.append(days) }
        parts.append(commitment.proofKind.shortLabel)
        return parts.joined(separator: "  ·  ")
    }
}

/// Deliberately the loudest thing on the screen while it is armed. A rehearsal that the
/// user forgets they started is an alarm going off in a lecture.
private struct RehearsalCard: View {
    let commitment: Commitment
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Rehearsal armed").naggLabel(Nagg.alarm)
                Text("Lock the phone. It rings through Silent.")
                    .font(Nagg.sans(14))
                    .foregroundStyle(Nagg.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Stop", action: onStop)
                .font(Nagg.sans(13, .medium))
                .foregroundStyle(Nagg.alarm)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Nagg.surface)
        .clipShape(.rect(cornerRadius: Nagg.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Nagg.radius).stroke(Nagg.alarm, lineWidth: 1)
        }
    }
}

// MARK: - Compact labels
//
// Card meta has one line and the user reads it at a glance, so these are shorter than the
// full labels used on the editing screen. Kept here rather than on the models because
// they are a presentation choice, not a property of a commitment.

private extension Commitment.ProofKind {
    var shortLabel: String {
        switch self {
        case .photo:      return "photo"
        case .focusTimer: return "timer"
        case .deskCode:   return "desk code"
        }
    }
}

private extension Commitment.Repeat {
    /// Nil for a one-off — the absence of a repeat is not worth a word.
    var shortLabel: String? {
        guard isRecurring else { return nil }
        if weekdays == Commitment.Repeat.weekdaysOnly.weekdays { return "weekdays" }
        if weekdays.count == 7 { return "daily" }

        let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekdays.sorted().compactMap { names.indices.contains($0) ? names[$0] : nil }
            .joined(separator: " ")
    }
}
