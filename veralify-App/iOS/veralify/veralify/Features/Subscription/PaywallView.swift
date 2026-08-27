import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(StoreKitManager.self) private var storeKitManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VeraTokens.Spacing._6) {
                    header

                    if storeKitManager.isLoadingProducts {
                        ProgressView("Loading StoreKit products…")
                            .padding(VeraTokens.Spacing._8)
                    } else if storeKitManager.proProducts.isEmpty {
                        developerState
                    } else {
                        VStack(spacing: VeraTokens.Spacing._3) {
                            ForEach(storeKitManager.proProducts, id: \.id) { product in
                                productRow(product)
                            }
                        }
                    }

                    if let message = storeKitManager.purchaseMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(VeraTokens.Colors.fgMuted)
                            .multilineTextAlignment(.center)
                            .premiumCard()
                    }

                    Button("Restore Purchases") {
                        Task { await storeKitManager.restorePurchases() }
                    }
                    .font(.headline)

                    policyLinks
                }
                .padding(VeraTokens.Spacing._5)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Veralify Pro")
            .navigationBarTitleDisplayMode(.inline)
            .task { await storeKitManager.loadProducts() }
        }
    }

    private var header: some View {
        VStack(spacing: VeraTokens.Spacing._3) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(AppTheme.premiumGradient)
            Text("3 days free, then your selected Pro plan")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Pro unlocks AI food logging, advanced nutrition, progress photos, groups, live rooms, trends, and coach discovery after backend validation.")
                .font(.subheadline)
                .foregroundStyle(VeraTokens.Colors.fgMuted)
                .multilineTextAlignment(.center)
        }
        .premiumCard()
    }

    private var developerState: some View {
        VStack(spacing: VeraTokens.Spacing._3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(VeraTokens.Colors.warning)
            Text("Store not configured")
                .font(.headline)
            Text(storeKitManager.productLoadError ?? "Create App Store Connect or StoreKit testing products for veralify.pro.weekly, veralify.pro.monthly, and veralify.pro.annual.")
                .font(.subheadline)
                .foregroundStyle(VeraTokens.Colors.fgMuted)
                .multilineTextAlignment(.center)
        }
        .premiumCard()
    }

    private func productRow(_ product: Product) -> some View {
        Button {
            Task { await storeKitManager.purchase(product) }
        } label: {
            HStack(spacing: VeraTokens.Spacing._3) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label(for: product))
                        .font(.headline)
                        .foregroundStyle(VeraTokens.Colors.fg)
                    Text("3-day intro trial when configured in App Store Connect")
                        .font(.caption)
                        .foregroundStyle(VeraTokens.Colors.fgMuted)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(VeraTokens.Colors.primary)
            }
            .premiumCard()
        }
        .buttonStyle(.plain)
    }

    private func label(for product: Product) -> String {
        switch product.id {
        case AppConfig.SubscriptionProductID.proWeekly: return "Weekly Pro"
        case AppConfig.SubscriptionProductID.proMonthly: return "Monthly Pro"
        case AppConfig.SubscriptionProductID.proAnnual: return "Annual Pro"
        default: return product.displayName
        }
    }

    private var policyLinks: some View {
        Text("Subscription pricing and trials are configured in App Store Connect. Purchases require a signed-in Veralify account and are unlocked only after server validation.")
            .font(.caption)
            .foregroundStyle(VeraTokens.Colors.fgSubtle)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    PaywallView()
        .environment(StoreKitManager.shared)
}
