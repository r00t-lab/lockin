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
struct PaywallView: View {

    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Package?

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text("You've used your two free commitments")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Unlimited commitments, syllabus import, and the weekly report on every excuse you made.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                ForEach(subscriptions.offering?.availablePackages ?? [], id: \.identifier) { package in
                    packageRow(package)
                }
            }

            Button {
                guard let package = selected ?? subscriptions.offering?.availablePackages.first else { return }
                Task {
                    if await subscriptions.purchase(package) { dismiss() }
                }
            } label: {
                Text(subscriptions.isPurchasing ? "…" : "Start free trial")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(subscriptions.isPurchasing)

            HStack(spacing: 20) {
                Button("Restore") { Task { await subscriptions.restore() } }
                Link("Terms", destination: URL(string: "https://lockin.app/terms")!)
                Link("Privacy", destination: URL(string: "https://lockin.app/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .presentationDragIndicator(.visible)
        .task {
            await subscriptions.refresh()
            selected = subscriptions.offering?.availablePackages.first
        }
    }

    private func packageRow(_ package: Package) -> some View {
        let isSelected = selected?.identifier == package.identifier
        return Button {
            selected = package
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.headline)
                    Text(package.storeProduct.localizedPriceString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.08))
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
