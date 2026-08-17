import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// The wrist half of the link. Mirror image of `WatchSyncService` on the phone.
///
/// Named differently from its phone counterpart on purpose: two files called
/// `WatchSyncService.swift` in one project is a five-minute mistake every single time
/// you open the jump bar.
///
/// ## What it guarantees
/// - Inbound state is **latest-wins**, guarded by `generatedAt`. WatchConnectivity does
///   not promise ordering, and a stale snapshot arriving after a fresh one would undo a
///   streak in front of the user.
/// - Outbound proof is **never dropped**. Reachable → `sendMessage`. Not reachable →
///   `transferUserInfo`, which survives the app being killed and the watch going flat.
///   Proof taken in a library basement has to land when the phone comes back.
@MainActor
@Observable
final class PhoneSyncService: NSObject {

    static let shared = PhoneSyncService()

    private(set) var payload = WatchSyncPayload()
    private(set) var isReachable = false
    /// Set when the user acted on the wrist but the phone has not confirmed yet. Drives
    /// the "sent" state on the button so the wrist never looks like nothing happened.
    private(set) var pendingActionIDs: Set<UUID> = []

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    private override init() {
        super.init()
        // Start from disk so the first frame after launch is never empty. The watch app
        // is opened from a wrist raise mid-alarm; a spinner there is a lost commitment.
        if let cached = WatchSnapshotCache.read() {
            payload = cached
        }
    }

    // MARK: - Lifecycle

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: - Outbound

    /// User started the focus timer on the wrist. Breaks the nag chain on the phone.
    func sendProof(for commitmentID: UUID) {
        pendingActionIDs.insert(commitmentID)
        send(.proved, commitmentID: commitmentID)

        // Optimistic local update. The phone is authoritative and will overwrite this
        // within a second or two, but the wrist must react on the same frame as the tap.
        if let index = payload.commitments.firstIndex(where: { $0.id == commitmentID }) {
            payload.commitments[index].recordProof()
            payload.ringingCommitmentID = nil
            persist()
        }
    }

    /// User bailed from the wrist. This is not a softer exit than the phone's — it feeds
    /// the same nag chain, and the alarm comes back in two minutes.
    func sendDismissal(for commitmentID: UUID) {
        pendingActionIDs.insert(commitmentID)
        send(.dismissed, commitmentID: commitmentID)

        if let index = payload.commitments.firstIndex(where: { $0.id == commitmentID }) {
            payload.commitments[index].recordMiss()
            payload.ringingCommitmentID = nil
            persist()
        }
    }

    func requestSnapshot() {
        send(.requestSnapshot)
    }

    private func send(_ action: WatchMessage.Action, commitmentID: UUID? = nil) {
        guard let session, session.activationState == .activated else { return }
        let message = WatchMessage.payload(action, commitmentID: commitmentID)

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                // Reachability lies often enough that the fallback is not optional.
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Inbound

    private func apply(_ context: [String: Any]) {
        guard let data = context[WatchSyncPayload.transportKey] as? Data,
              let incoming = try? JSONDecoder().decode(WatchSyncPayload.self, from: data),
              incoming.generatedAt >= payload.generatedAt else { return }

        payload = incoming
        pendingActionIDs.removeAll()
        persist()
    }

    private func persist() {
        WatchSnapshotCache.write(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - WCSessionDelegate

/// Every callback lands on a background queue and hops to the main actor. watchOS has
/// no `sessionDidBecomeInactive`/`sessionDidDeactivate` — those are iOS-only.
extension PhoneSyncService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            guard activationState == .activated else { return }
            self.requestSnapshot()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in self.apply(message) }
    }

    /// Complication-priority transfers arrive here too, which is what keeps the face
    /// current without the app ever being launched.
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in self.apply(userInfo) }
    }
}
