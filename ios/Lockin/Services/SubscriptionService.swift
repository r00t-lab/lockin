import Foundation
import Observation
import RevenueCat

/// Thin wrapper over RevenueCat. Everything the rest of the app needs is `isPro`.
///
/// RevenueCat is free until $2,500/mo tracked revenue, which is well past the point
/// where paying for it stops hurting. Do not hand-roll StoreKit for v1.
@MainActor
@Observable
final class SubscriptionService {

    static let shared = SubscriptionService()

    /// Entitlement identifier as configured in the RevenueCat dashboard.
    private let entitlementID = "pro"

    private(set) var isPro = false
    private(set) var offering: Offering?
    private(set) var isPurchasing = false

    /// False until a real key has been handed to `configure`. Every call below checks it.
    ///
    /// Configuring RevenueCat with the placeholder does not fail loudly — it fails in a
    /// loop. On device it produced dozens of `storekitd` tasks a second against the
    /// sandbox, burning battery and, worse, burying every other line in the system log
    /// at exactly the point we were reading logs to chase a real bug.
    private(set) static var isConfigured = false

    /// The value that ships in the repo. Anything equal to it is not a key.
    private static let placeholderKey = "appl_REPLACE_ME"

    private init() {}

    /// Call once, from `LockinApp.init`, before any other RevenueCat call.
    ///
    /// Refuses the placeholder rather than passing it through. A paywall with nothing in
    /// it is a bug someone notices; a silent retry storm is one nobody does.
    static func configure(apiKey: String) {
        guard apiKey != placeholderKey, apiKey.hasPrefix("appl_") else {
            isConfigured = false
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true
    }

    func refresh() async {
        guard Self.isConfigured else { return }

        async let info = try? Purchases.shared.customerInfo()
        async let offerings = try? Purchases.shared.offerings()

        if let info = await info {
            isPro = info.entitlements[entitlementID]?.isActive == true
        }
        offering = await offerings?.current
    }

    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        guard Self.isConfigured else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return false }
            isPro = result.customerInfo.entitlements[entitlementID]?.isActive == true
            return isPro
        } catch {
            return false
        }
    }

    /// Apple requires a visible restore path on any paywall. Missing it is a
    /// guaranteed rejection, and it is two lines.
    @discardableResult
    func restore() async -> Bool {
        guard Self.isConfigured,
              let info = try? await Purchases.shared.restorePurchases() else { return false }
        isPro = info.entitlements[entitlementID]?.isActive == true
        return isPro
    }
}
