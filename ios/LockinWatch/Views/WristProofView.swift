import SwiftUI

/// Proof, from the wrist, without picking up the phone.
///
/// ## Why only the focus timer
/// The phone supports three proof types. The wrist supports exactly one, on purpose:
///
/// - **Photo** — the Apple Watch camera is a remote viewfinder for the iPhone's camera,
///   not a camera. Proving you got out of bed by pointing your *phone* at your desk from
///   your wrist is not proof of anything, it is a worse version of the phone flow.
/// - **Desk code (QR)** — no code scanning API on watchOS, and the point of the QR is
///   that you had to physically walk to the desk holding the scanner. A watch you are
///   already wearing carries itself there for free.
///
/// Both of those stay phone-only. This screen does not half-build them — if the
/// commitment's proof kind is photo or deskCode, it says so and hands the user back to
/// the phone. A stub that pretends to work would let someone clear an alarm from bed,
/// which is the exact failure the product exists to prevent.
///
/// ## Why starting is enough
/// Same rule as `ProofView` on the phone: starting the 25 minutes is the proof, finishing
/// it is between them and their degree. So no `WKExtendedRuntimeSession` here — nothing
/// needs to survive backgrounding, because the streak is banked on the first tap.
struct WristProofView: View {

    let commitment: Commitment
    /// True when we got here because the alarm is going off, rather than the user
    /// browsing the list. Changes the copy and the exit, not the mechanic.
    let isRinging: Bool

    @Environment(PhoneSyncService.self) private var sync
    @Environment(\.dismiss) private var dismiss

    /// When the user tapped Start. The countdown range is derived from this rather than
    /// from `Date.now`, because a `now...end` range inverts once the 25 minutes are up
    /// and an inverted `ClosedRange` is a trap, not a nil.
    @State private var timerStartedAt: Date?

    /// 25 minutes. The number is in the product spec and on the App Store screenshots —
    /// if you change it here, change it in `ProofView` too or the two devices disagree.
    private let focusDuration: TimeInterval = 25 * 60

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header

                switch commitment.proofKind {
                case .focusTimer:
                    timerProof
                case .photo, .deskCode:
                    phoneOnlyProof
                }

                exitButton
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(isRinging ? "Now" : "Commitment")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Three different exits, and which one you get is the whole ethics of this screen.
    @ViewBuilder
    private var exitButton: some View {
        if commitment.proofKind != .focusTimer {
            // Phone-only proof. Closing here must NOT record a miss — the user walking
            // to their desk to scan the code is the behaviour we want, and the phone
            // alarm is still ringing anyway. Punishing them for leaving the wrist screen
            // would be the app fighting its own mechanic.
            Button("Close") { dismiss() }
                .font(.caption2)
        } else if timerStartedAt == nil {
            Button("I'm not doing it", role: .destructive) {
                WristHaptics.shared.confirmDismissal()
                sync.sendDismissal(for: commitment.id)
                dismiss()
            }
            .font(.caption2)
        } else {
            // The streak was banked on the first tap, so leaving now is free and has to
            // be offered. No `interactiveDismissDisabled` on this screen either: on
            // watchOS the dismiss gesture *is* the back gesture, and trapping someone on
            // a wrist for 25 minutes is not toughness, it is a support ticket. The nag
            // chain is the pressure, not the sheet.
            Button("Close") { dismiss() }
                .font(.caption2)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(isRinging ? "YOU SAID YOU'D START" : "COMING UP")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.secondary)

            Text(commitment.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if commitment.currentStreak > 0 {
                Text("\(commitment.currentStreak) day streak on the line")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Focus timer

    @ViewBuilder
    private var timerProof: some View {
        if let timerStartedAt {
            VStack(spacing: 6) {
                // `Text(timerInterval:)` is rendered by the system, so the countdown keeps
                // ticking without a Task waking the app every second. On a watch that
                // difference is measured in percent of battery, not milliseconds.
                Text(
                    timerInterval: timerStartedAt...timerStartedAt.addingTimeInterval(focusDuration),
                    countsDown: true
                )
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)

                Text("Streak banked. Go.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Button {
                start()
            } label: {
                Label("Start 25 minutes", systemImage: "timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
    }

    private func start() {
        timerStartedAt = .now
        WristHaptics.shared.confirmProof()
        // Starting is the proof — tell the phone immediately so the nag chain dies now,
        // not in 25 minutes. If the phone is out of range this queues and lands later.
        sync.sendProof(for: commitment.id)
    }

    // MARK: - Photo / desk code

    private var phoneOnlyProof: some View {
        VStack(spacing: 8) {
            Image(systemName: commitment.proofKind.systemImageName)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(commitment.proofKind.label)
                .font(.caption)
                .multilineTextAlignment(.center)

            Text("Finish this one on your iPhone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
