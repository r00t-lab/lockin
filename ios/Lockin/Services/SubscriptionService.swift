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

    private init() {}

    /// Call once, from `LockinApp.init` or the app delegate, before any other RC call.
    static func configure(apiKey: String) {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }

    func refresh() async {
        async let info = try? Purchases.shared.customerInfo()
        async let offerings = try? Purchases.shared.offerings()

        if let info = await info {
            isPro = info.entitlements[entitlementID]?.isActive == true
        }
        offering = await offerings?.current
    }

    @discardableResult
    func purchase(_ package: Package) async -> Bool {
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
        guard let info = try? await Purchases.shared.restorePurchases() else { return false }
        isPro = info.entitlements[entitlementID]?.isActive == true
        return isPro
    }
}
