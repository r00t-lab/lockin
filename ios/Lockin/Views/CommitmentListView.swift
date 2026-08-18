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

    /// Shared with `LockinApp` so both routes to the proof screen — the alarm's
    /// "I'm starting" intent and the card below — land on the same sheet.
    @Binding var proofTarget: Commitment?

    @Environment(CommitmentStore.self) private var store
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var showNewCommitment = false
    @State private var showPaywall = false
    @State private var showReport = false
    @State private var deskCodeTarget: Commitment?
    @State private var rehearsalError: String?

    /// Nudged every few seconds so "is this ringing right now" stays true while the app
    /// is open. `needsProof` is a comparison against the clock, and the clock is not an
    /// observable — without this, an alarm that starts ringing while the user is looking
    /// at the list leaves the card sitting there saying nothing is happening.
    @State private var tick = Date.now
    private let clock = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            figures

            ScrollView {
                LazyVStack(spacing: 10) {
                    if let rehearsal = store.rehearsal {
                        RehearsalCard(
                            commitment: rehearsal,
                            needsProof: store.needsProof(rehearsal),
                            onProve: { proofTarget = rehearsal },
                            onStop: { Task { await store.endRehearsal() } }
                        )
                    }

                    if store.visibleCommitments.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.visibleCommitments) { commitment in
                            CommitmentCard(
                                commitment: commitment,
                                needsProof: store.needsProof(commitment),
                                onProve: { proofTarget = commitment },
                                onShowCode: { deskCodeTarget = commitment },
                                onDelete: { Task { await store.delete(commitment) } }
                            )
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
        .onReceive(clock) { tick = $0 }
        .animation(.easeOut(duration: 0.22), value: store.commitments)
        .sheet(isPresented: $showNewCommitment) { NewCommitmentView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showReport) { WeeklyReportView() }
        .sheet(item: $deskCodeTarget) { DeskCodeView(commitment: $0) }
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
        // The whole strip is the way into the report. No button, no chevron — the numbers
        // are already the thing the user's eye lands on, and anyone who wants more detail
        // reaches for them first.
        .contentShape(.rect)
        .onTapGesture { showReport = true }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the report")
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

    /// A menu rather than a button, because which proof you rehearse decides which screen
    /// you get. Picking one silently is how someone rehearses the timer, waits for a
    /// camera, and concludes the camera is broken.
    private var rail: some View {
        VStack(spacing: 9) {
            Menu {
                ForEach(Commitment.ProofKind.allCases, id: \.self) { kind in
                    Button {
                        Task { await armRehearsal(kind) }
                    } label: {
                        Label(kind.label, systemImage: kind.systemImageName)
                    }
                }
            } label: {
                // Loud on an empty app, quiet once there is something real on the list.
                // Before the first commitment this is the only way to find out the alarm
                // is not a bluff, and that is the whole conversion moment; afterwards it
                // is a utility and should not outrank the user's own commitments.
                Text("Rehearse the alarm")
                    .font(Nagg.sans(15, .medium))
                    .foregroundStyle(isFirstRun ? Nagg.ground : Nagg.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isFirstRun ? 15 : 13)
                    .background {
                        if isFirstRun {
                            RoundedRectangle(cornerRadius: 11).fill(Nagg.ink)
                        } else {
                            RoundedRectangle(cornerRadius: 11).stroke(Nagg.line, lineWidth: 1)
                        }
                    }
            }
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

    private var isFirstRun: Bool { store.visibleCommitments.isEmpty }

    private func armRehearsal(_ proofKind: Commitment.ProofKind) async {
        guard await AlarmService.shared.ensureAuthorized() else {
            rehearsalError = "Nagg needs alarm permission before it can ring. Allow it in Settings."
            return
        }
        do {
            rehearsalError = nil
            try await store.startRehearsal(proofKind: proofKind)
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
    let needsProof: Bool
    let onProve: () -> Void
    let onShowCode: () -> Void
    let onDelete: () -> Void

    private var isDone: Bool { commitment.isDoneToday }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(commitment.title)
                        .font(Nagg.sans(15, .medium))
                        .strikethrough(isDone, pattern: .solid)
                        .foregroundStyle(isDone ? Nagg.go : Nagg.ink)

                    Text(needsProof ? "Ringing — you haven't proved it" : meta)
                        .font(Nagg.mono(12, .regular))
                        .monospacedDigit()
                        .foregroundStyle(statusColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Without this the desk-code mode is unusable: the scanner only accepts
                // this commitment's id and nothing else in the app ever shows it.
                if commitment.proofKind == .deskCode {
                    Button(action: onShowCode) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Nagg.ink2)
                            .padding(4)
                    }
                    .accessibilityLabel("Show the desk code for \(commitment.title)")
                }

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

            if needsProof {
                Button("Prove you started", action: onProve)
                    .buttonStyle(NaggPrimaryButton(tint: Nagg.alarm, label: .white))
            }
        }
        .naggCard(done: isDone, alert: needsProof)
        .opacity(commitment.isEnabled ? 1 : 0.4)
    }

    private var statusColor: Color {
        if needsProof { return Nagg.alarm }
        return isDone ? Nagg.go : Nagg.ink2
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
    let needsProof: Bool
    let onProve: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Rehearsal armed").naggLabel(Nagg.alarm)
                    Text(needsProof
                         ? "It's ringing. \(commitment.proofKind.label) — nothing else stops it."
                         : "Lock the phone. It rings through Silent.")
                        .font(Nagg.sans(14))
                        .foregroundStyle(Nagg.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Stop", action: onStop)
                    .font(Nagg.sans(13, .medium))
                    .foregroundStyle(Nagg.alarm)
            }

            if needsProof {
                Button("Prove you started", action: onProve)
                    .buttonStyle(NaggPrimaryButton(tint: Nagg.alarm, label: .white))
            }
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
