import SwiftUI

@main
struct LockinApp: App {

    @State private var store = CommitmentStore.shared
    @State private var alarms = AlarmService.shared
    @State private var subscriptions = SubscriptionService.shared
    @State private var watchSync = WatchSyncService.shared

    /// Set when the user tapped "I'm starting" on the alarm. Drives the proof sheet.
    @State private var proofTarget: Commitment?
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Replace with your RevenueCat public SDK key (appl_…). It is safe to ship in
        // the binary — it is a public key — but do not paste your *secret* key here.
        SubscriptionService.configure(apiKey: "appl_REPLACE_ME")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    CommitmentListView(proofTarget: $proofTarget)
                } else {
                    OnboardingView(hasOnboarded: $hasOnboarded)
                }
            }
            .environment(store)
            .environment(alarms)
            .environment(subscriptions)
            .sheet(item: $proofTarget) { commitment in
                ProofView(commitment: commitment)
            }
            .task {
                // `onChange(of: scenePhase)` does not fire for the initial value, so a
                // cold launch used to skip the hand-off entirely — and a cold launch is
                // the normal case here, because the whole point is that the alarm goes
                // off while the app is closed.
                claimPendingProof()
                await store.refreshChains()

                // Activate before observing alarms — `observeAlarmUpdates` never returns,
                // and anything after it in this task would never run.
                watchSync.activate()
                await subscriptions.refresh()
                await alarms.observeAlarmUpdates()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                claimPendingProof()
                Task { await store.refreshChains() }
            }
        }
    }

    /// Decide what the user should be looking at, the moment the app comes forward.
    ///
    /// Two routes, and the second one is not a nicety. The alarm's "I'm starting" button
    /// runs `ProofIntent`, which stashes an id and asks the system to open us — but on
    /// device that button silences the ring without reliably bringing the app forward.
    /// Someone in that state is being nagged by an alarm they have no way to answer.
    ///
    /// So if no id was stashed, we ask a simpler question: is anything being nagged right
    /// now? If so, open onto it. Opening the app is now itself a valid way to answer the
    /// alarm, whatever happened to the intent.
    ///
    /// Nothing is armed here either way. Tapping "I'm starting" silences one ring; the
    /// rest of the chain was written when the alarm was scheduled, so walking away
    /// without proving is not a free escape — the next nag is already on the books.
    private func claimPendingProof() {
        guard proofTarget == nil else { return }

        if let id = PendingProof.shared.take(), let commitment = store.commitment(id: id) {
            proofTarget = commitment
            return
        }

        proofTarget = store.commitmentAwaitingProof
    }
}
