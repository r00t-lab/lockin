import Foundation
import WatchKit

/// The nag, translated into taps.
///
/// The mirrored AlarmKit alarm already plays the system's own alarm haptic. This is the
/// layer on top of it: while the wrist app is open on a ringing commitment, it keeps
/// tapping until the user does something. Same principle as the nag chain — being easy
/// to ignore is the only way this product fails.
///
/// It stops on its own after `pulseCount`. An unbounded haptic loop is a one-star review
/// and, on a wrist, arguably a support ticket.
@MainActor
final class WristHaptics {

    static let shared = WristHaptics()

    /// Roughly a minute of tapping. Long enough to be impossible to sit through,
    /// short enough that a watch left on a nightstand goes quiet by itself.
    private let pulseCount = 20
    private let pulseInterval: Duration = .seconds(3)

    private var pulseTask: Task<Void, Never>?

    private init() {}

    /// Start pulsing. Calling it twice does not stack — the previous loop is cancelled.
    func startRinging() {
        stop()
        pulseTask = Task { [pulseCount, pulseInterval] in
            for _ in 0..<pulseCount {
                guard !Task.isCancelled else { return }
                WKInterfaceDevice.current().play(.notification)
                try? await Task.sleep(for: pulseInterval)
            }
        }
    }

    func stop() {
        pulseTask?.cancel()
        pulseTask = nil
    }

    /// Proof accepted. The one moment in this app that should feel good.
    func confirmProof() {
        stop()
        WKInterfaceDevice.current().play(.success)
    }

    /// User bailed. Deliberately the `.failure` haptic, not a neutral one — the wrist
    /// should not feel the same when you quit as when you start.
    func confirmDismissal() {
        stop()
        WKInterfaceDevice.current().play(.failure)
    }
}
