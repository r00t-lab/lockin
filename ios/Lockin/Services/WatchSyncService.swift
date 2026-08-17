import AlarmKit
import Foundation
import Observation
import WatchConnectivity

/// The phone half of the wrist link.
///
/// ## Why a watch app exists at all
/// AlarmKit alarms already mirror to a paired Apple Watch on their own — the ring, the
/// title and the Stop button reach the wrist with no watch app installed. So this
/// service does **not** exist to make the alarm audible. It exists so the three things
/// the mirrored alarm cannot do can happen:
///
///   1. Proof from the wrist (focus timer only — see `WristProofView`).
///   2. A complication that shows what is next without opening anything.
///   3. Streak and dismissal state staying honest on both devices.
///
/// ## Delivery shape
/// State goes out as an **application context** — latest-wins, survives the watch being
/// asleep, no queue to drain. When the ring starts we *also* fire a `sendMessage` if the
/// watch is reachable, because application context delivery is best-effort and can take
/// tens of seconds, which is useless for something that is ringing right now.
///
/// Proof comes back the other way as a message when reachable and a `transferUserInfo`
/// when not. Proof is the one payload we are not allowed to drop.
@MainActor
@Observable
final class WatchSyncService: NSObject {

    static let shared = WatchSyncService()

    private(set) var isPaired = false
    private(set) var isWatchAppInstalled = false
    private(set) var isReachable = false
    /// Last commitment we told the watch was ringing. Kept so we only push on change.
    private(set) var ringingCommitmentID: UUID?

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    private override init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// Call once from `LockinApp`. Safe to call again; activation is idempotent.
    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: - Outbound

    /// Push the current commitment list to the wrist.
    ///
    /// Call this after every mutation. It is cheap — WatchConnectivity coalesces
    /// application context updates, so spamming it costs nothing but a dictionary.
    func pushSnapshot(ringingCommitmentID: UUID? = nil) {
        guard let session, session.activationState == .activated else { return }

        self.ringingCommitmentID = ringingCommitmentID

        let payload = WatchSyncPayload(
            commitments: CommitmentStore.shared.commitments,
            ringingCommitmentID: ringingCommitmentID,
            generatedAt: .now
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        let context: [String: Any] = [WatchSyncPayload.transportKey: data]

        try? session.updateApplicationContext(context)

        // A ring cannot wait for best-effort delivery.
        if ringingCommitmentID != nil, session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: nil)
        }

        // Complication transfers are rationed (Apple gives roughly 50 a day), so only
        // spend one when a complication is actually on a face.
        if session.isComplicationEnabled {
            session.transferCurrentComplicationUserInfo(context)
        }
    }

    /// Called from `AlarmService.observeAlarmUpdates` with whatever AlarmKit currently
    /// holds. Maps the alerting alarm back to its commitment and tells the wrist.
    ///
    /// The mapping goes through `AlarmService.scheduledAlarmIDs` rather than a second
    /// consumer of `alarmUpdates` — that sequence is not safe to iterate twice.
    func announceRinging(_ alarms: [Alarm]) {
        // ⚠️ Unverified signature: `Alarm.state` and the `.alerting` case are AlarmKit
        // iOS 26 API that moved between betas, exactly like the two functions flagged in
        // `AlarmService`. If this does not compile, the fix is the case name — the rest
        // of the mapping is ours and is correct.
        let alertingIDs = Set(alarms.filter { $0.state == .alerting }.map(\.id))

        let ringing = AlarmService.shared.scheduledAlarmIDs
            .first { alertingIDs.contains($0.value) }?
            .key

        guard ringing != ringingCommitmentID else { return }
        pushSnapshot(ringingCommitmentID: ringing)
    }

    // MARK: - Inbound

    /// One place for every verb the watch can send, so the reachable and unreachable
    /// paths cannot drift apart.
    private func handle(_ message: [String: Any]) async {
        guard let (action, commitmentID) = WatchMessage.decode(message) else { return }

        switch action {
        case .proved:
            guard let commitmentID else { return }
            await CommitmentStore.shared.recordProof(for: commitmentID)
            pushSnapshot()

        case .dismissed:
            guard let commitmentID else { return }
            await CommitmentStore.shared.recordDismissal(for: commitmentID)
            pushSnapshot()

        case .requestSnapshot:
            pushSnapshot(ringingCommitmentID: ringingCommitmentID)
        }
    }

    private func refreshReachability() {
        guard let session else { return }
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
    }
}

// MARK: - WCSessionDelegate

/// Delegate callbacks arrive on a background queue, so every one of these hops back to
/// the main actor before touching the store. Do not be tempted to drop the hop —
/// `CommitmentStore` is `@MainActor` and this is the exact shape Swift 6 will reject.
extension WatchSyncService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.refreshReachability()
            guard activationState == .activated else { return }
            self.pushSnapshot(ringingCommitmentID: self.ringingCommitmentID)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshReachability() }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in await self.handle(message) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            await self.handle(message)
            replyHandler([:])
        }
    }

    /// The guaranteed-delivery path. Proof taken while the phone was in a pocket in
    /// another room arrives here, possibly minutes later.
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in await self.handle(userInfo) }
    }

    // iOS-only requirements. The watch can be unpaired and re-paired underneath us; the
    // only correct response is to reactivate and resend everything.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
