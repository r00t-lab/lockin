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

    /// The intent stashed a commitment id before foregrounding us. Pick it up and
    /// go straight to proof — never make the user find the row themselves at 7am.
    ///
    /// Nothing is armed here. Tapping "I'm starting" silences this ring, but the rest of
    /// the chain was already written when the alarm was scheduled, so walking away
    /// without proving is not a free escape — the next nag is already on the books.
    private func claimPendingProof() {
        guard let id = PendingProof.shared.take(),
              let commitment = store.commitment(id: id) else { return }
        proofTarget = commitment
    }
}
