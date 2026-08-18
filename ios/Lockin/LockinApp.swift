import OSLog
import SwiftUI

/// ## Why this file was rewritten
/// On device the app stopped opening once an alarm had fired, and the camera never
/// appeared. Those looked like two bugs and were one: the proof screen was presented as a
/// sheet, the app auto-presents it whenever a chain is live, and so whatever went wrong
/// in that presentation took the entire launch with it. Before the auto-present existed
/// the same fault showed up as "tapping Prove you started throws me out of the app". One
/// fault, three disguises, three rounds lost to it.
///
/// So proof is not presented any more. It is a state of the root view — an `if`, not a
/// `.sheet`. This app has now been bitten by SwiftUI presentation three separate times:
/// four stacked sheets on the list screen, the camera picker inside the proof sheet, and
/// this. The rule that comes out of it is worth keeping: **nothing on the path between a
/// ringing alarm and proof may depend on a presentation succeeding.**
///
/// Dependencies are passed as parameters rather than read from the environment, for the
/// same reason. `@Environment(Type.self)` on a non-optional property traps at runtime if
/// the value is absent, and that crash is indistinguishable from the one above on a phone
/// with no debugger attached. A parameter cannot go missing.
@main
struct LockinApp: App {

    @State private var store = CommitmentStore.shared
    @State private var alarms = AlarmService.shared
    @State private var subscriptions = SubscriptionService.shared

    @AppStorage("hasOnboarded") private var hasOnboarded = false

    init() {
        // Replace with your RevenueCat public SDK key (appl_…). Safe to ship — it is a
        // public key. The placeholder is refused rather than passed through, see
        // `SubscriptionService`.
        SubscriptionService.configure(apiKey: "appl_REPLACE_ME")
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                store: store,
                alarms: alarms,
                subscriptions: subscriptions,
                hasOnboarded: $hasOnboarded
            )
        }
    }
}

/// The app is one of three screens at a time. No navigation stack, and no presentation
/// anywhere on the critical path.
struct RootView: View {

    let store: CommitmentStore
    let alarms: AlarmService
    let subscriptions: SubscriptionService
    @Binding var hasOnboarded: Bool

    /// Non-nil while the user owes proof. Swaps the whole screen rather than covering it.
    @State private var proofTarget: Commitment?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if !hasOnboarded {
                OnboardingView(hasOnboarded: $hasOnboarded)
            } else if let commitment = proofTarget {
                ProofView(commitment: commitment, store: store) {
                    proofTarget = nil
                }
            } else {
                CommitmentListView(
                    store: store,
                    subscriptions: subscriptions,
                    onProve: { proofTarget = $0 }
                )
            }
        }
        .task {
            // `onChange(of: scenePhase)` does not fire for the initial value, and a cold
            // launch is the normal case here — the whole premise is that the alarm goes
            // off while the app is closed.
            await openWhateverIsOwed()

            // `observeAlarmUpdates` never returns, so nothing may follow it in this task.
            await subscriptions.refresh()
            await alarms.observeAlarmUpdates()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await openWhateverIsOwed() }
        }
    }

    /// Decide what the user should be looking at whenever the app comes forward.
    ///
    /// Two routes. The alarm's "I'm starting" button runs `ProofIntent`, which stashes an
    /// id — but on device that button silences the ring without reliably bringing the app
    /// forward, so it cannot be the only way in. When no id was stashed we ask the simpler
    /// question instead: is anything being nagged right now? Opening the app is itself a
    /// valid way to answer an alarm.
    ///
    /// Nothing is armed here either way. Tapping "I'm starting" silences one ring; the
    /// rest of the chain was written when the alarm was scheduled, so walking away without
    /// proving is not a free escape — the next nag is already on the books.
    private func openWhateverIsOwed() async {
        await store.refreshChains()
        guard proofTarget == nil else { return }

        if let id = PendingProof.shared.take(), let commitment = store.commitment(id: id) {
            NaggLog.proof.notice("NAGG handoff: from intent, commitment=\(id, privacy: .public)")
            proofTarget = commitment
            return
        }

        if let awaiting = store.commitmentAwaitingProof {
            NaggLog.proof.notice("NAGG handoff: mid-chain, commitment=\(awaiting.id, privacy: .public)")
            proofTarget = awaiting
        } else {
            NaggLog.proof.notice("NAGG handoff: nothing to prove")
        }
    }
}
