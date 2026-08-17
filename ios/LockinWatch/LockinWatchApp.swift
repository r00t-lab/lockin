import SwiftUI

/// Watch App entry point.
///
/// Same shape as `LockinApp` on the phone: a plain root, plus a sheet that the alarm
/// shoves in front of it. One rule drives it — **if something is ringing, nothing else
/// is on screen.** The user raised their wrist because an alarm went off, and every tap
/// between that raise and the proof screen is a person going back to bed.
///
/// The ringing commitment is latched into `@State` rather than read straight from
/// `sync.payload`. It has to be: recording proof clears `ringingCommitmentID`, and a
/// root that switched on the payload would yank the running countdown off screen on the
/// same frame the user tapped Start.
@main
struct LockinWatchApp: App {

    @State private var sync = PhoneSyncService.shared

    /// Set when the phone says an alarm is going off. Cleared when the user leaves.
    @State private var ringing: Commitment?

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchCommitmentListView()
                .environment(sync)
                .sheet(item: $ringing) { commitment in
                    NavigationStack {
                        WristProofView(commitment: commitment, isRinging: true)
                    }
                    .environment(sync)
                }
                .task {
                    sync.activate()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Coming back from a wrist-down means the snapshot on screen may be
                    // minutes old. Ask rather than render something stale.
                    guard phase == .active else { return }
                    sync.requestSnapshot()
                }
                .onChange(of: sync.payload.ringingCommitmentID) { _, _ in
                    claimRingingCommitment()
                }
                .onAppear {
                    claimRingingCommitment()
                }
        }
    }

    /// Only ever raises the sheet. Lowering it is the user's job — see the note above
    /// about not yanking a running countdown off screen.
    private func claimRingingCommitment() {
        guard let commitment = sync.payload.ringingCommitment else {
            WristHaptics.shared.stop()
            return
        }
        guard ringing?.id != commitment.id else { return }
        ringing = commitment
        WristHaptics.shared.startRinging()
    }
}
