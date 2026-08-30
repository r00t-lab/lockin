import RevenueCat
import SwiftUI

/// The paywall earns more than any feature you could build instead. Treat it as the
/// product, not as a tax on the product.
///
/// Pricing rationale (RevenueCat, 115k apps, 2026): median high-priced apps convert
/// downloads roughly 2x better than low-priced ones — 2.8% vs 1.4%. Cheap pricing is
/// punished twice, once on price and once on conversion. Do not discount your way in.
/// Productivity revenue is ~77% monthly, so lead with monthly and offer annual as the
/// saving, rather than the reverse.
///
/// Visually: no padlock, no gradient, no "PRO" badge. The user hit this wall because
/// they were using the app, so the screen leads with what they already did — their
/// streak and their excuse count — and the price is set in the same mono as those
/// numbers, because it is another fact and not a pitch.
struct PaywallView: View {

    let subscriptions: SubscriptionService
    let store: CommitmentStore
    let onFinish: () -> Void

    @State private var selected: Package?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Nagg Pro").naggLabel(Nagg.alarm).padding(.bottom, 10)

                Text("Two commitments is where free ends.")
                    .font(Nagg.sans(26, .medium))
                    .lineSpacing(2)
                    .foregroundStyle(Nagg.ink)

                Text("Unlimited commitments and the weekly report on every excuse you made.")
                    .font(Nagg.sans(15))
                    .lineSpacing(4)
                    .foregroundStyle(Nagg.ink2)
                    .padding(.top, 10)

                receipts.padding(.top, 22)

                if packages.isEmpty {
                    unavailable.padding(.top, 22)
                } else {
                    VStack(spacing: 8) {
                        ForEach(packages, id: \.identifier) { package in
                            packageRow(package)
                        }
                    }
                    .padding(.top, 22)

                    Button {
                        guard let package = selected ?? packages.first else { return }
                        Task {
                            if await subscriptions.purchase(package) { onFinish() }
                        }
                    } label: {
                        Text(subscriptions.isPurchasing ? "…" : "Start free trial")
                    }
                    .buttonStyle(NaggPrimaryButton())
                    .disabled(subscriptions.isPurchasing)
                    .padding(.top, 20)
                }

                HStack(spacing: 18) {
                    Button("Restore") { Task { await subscriptions.restore() } }
                    // Real, reachable pages — App Review follows these and a dead legal
                    // link is a rejection on its own. No `.html`: the host strips the
                    // extension and would answer the long form with a redirect.
                    Link("Terms", destination: URL(string: "https://nagg.pro/terms")!)
                    Link("Privacy", destination: URL(string: "https://nagg.pro/privacy")!)
                }
                .font(Nagg.sans(12))
                .foregroundStyle(Nagg.ink3)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

                Button("Not now") { onFinish() }
                    .buttonStyle(NaggBailButton())
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 20)
        }
        .naggGround()
        .presentationDragIndicator(.visible)
        .task {
            await subscriptions.refresh()
            selected = packages.first
        }
    }

    private var packages: [Package] { subscriptions.offering?.availablePackages ?? [] }

    /// Shown when there is genuinely nothing to sell — no store products configured yet,
    /// or no network. A "Start free trial" button with no package behind it is worse than
    /// an empty screen: the user taps it, nothing happens, and they conclude the app is
    /// broken rather than unfinished.
    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing to sell yet").naggLabel()
            Text("Subscriptions aren't set up on this build. Everything else works — you just can't go past two commitments.")
                .font(Nagg.sans(14))
                .lineSpacing(4)
                .foregroundStyle(Nagg.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Nagg.surface)
        .clipShape(.rect(cornerRadius: Nagg.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Nagg.radius).stroke(Nagg.line, lineWidth: 1)
        }
    }

    /// What the user has already got out of the app, in their own numbers. Far more
    /// persuasive than any feature list, and it costs nothing to show.
    private var receipts: some View {
        let stats = store.weeklyStats
        return HStack(spacing: 1) {
            receipt("\(stats.bestStreak)", "best streak")
            receipt("\(stats.missed)", "excuses")
        }
        .background(Nagg.line)
        .clipShape(.rect(cornerRadius: Nagg.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Nagg.radius).stroke(Nagg.line, lineWidth: 1)
        }
    }

    private func receipt(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).naggFigure(24).foregroundStyle(Nagg.ink)
            Text(label).naggLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Nagg.surface)
    }

    /// " / month" for a monthly product, " / year" for an annual one. Read off the
    /// product's own subscription period so a mis-set product cannot print a lie.
    private static func periodSuffix(_ package: Package) -> String {
        guard let period = package.storeProduct.subscriptionPeriod else { return "" }
        let unit: String
        switch period.unit {
        case .day:   unit = period.value == 1 ? "day" : "\(period.value) days"
        case .week:  unit = period.value == 1 ? "week" : "\(period.value) weeks"
        case .month: unit = period.value == 1 ? "month" : "\(period.value) months"
        case .year:  unit = period.value == 1 ? "year" : "\(period.value) years"
        @unknown default: return ""
        }
        return " / " + unit
    }

    private func packageRow(_ package: Package) -> some View {
        let isSelected = selected?.identifier == package.identifier
        return Button {
            selected = package
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(package.storeProduct.localizedTitle)
                        .font(Nagg.sans(15, .medium))
                    // Guideline 3.1.2(c) wants the billing period spelled out next to the
                    // price, not implied by a product title. "Nagg Pro Monthly" reads as a
                    // duration to us and as a name to review -- this is what a rejection
                    // taught, so the period is printed from the product itself rather than
                    // hard-coded per row.
                    Text(package.storeProduct.localizedPriceString + Self.periodSuffix(package))
                        .font(Nagg.mono(13, .regular))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Nagg.ground.opacity(0.75) : Nagg.ink2)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark" : "circle")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Nagg.ground : Nagg.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Nagg.ink : Nagg.surface)
            .clipShape(.rect(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11).stroke(isSelected ? .clear : Nagg.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
