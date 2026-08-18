import UIKit

/// The two moments in this app worth feeling.
///
/// Proof is the payoff for getting out of bed, and rejection is the app telling someone
/// their photo of the ceiling did not fool it. Both land better through the hand than
/// through the eye — the user is often not looking directly at the screen at 7am, and a
/// silent success is indistinguishable from a tap that did not register.
///
/// Deliberately only two. A haptic on every button is noise, and noise is exactly how an
/// app trains people to ignore it — which is the one thing this product cannot afford.
///
/// `@MainActor` because every UIKit type is, under Swift 6 strict concurrency. Both
/// call sites are already on the main actor — SwiftUI views and the tasks they spawn
/// inherit it — so this costs nothing and turns a compile error into a no-op.
@MainActor
enum Haptics {

    static func proved() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func rejected() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
