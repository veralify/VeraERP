import Foundation
import SwiftUI
import Combine

struct CheckoutView: View {
    let package: ESIMPackage
    let country: Country
    @StateObject private var viewModel = CheckoutViewModel()
    @ObservedObject private var supabase = SupabaseClient.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Text(country.flagEmoji).font(.system(size: 36))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.name).font(.headline)
                                Text(package.operatorName).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        HStack {
                            Label(package.data, systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            Label(package.validityText, systemImage: "calendar")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .premiumCard()

                    VStack(spacing: 0) {
                        PriceRow(label: "Plan", value: package.formattedPrice)
                        Divider().padding(.leading, 16)
                        PriceRow(label: "Tax & Fees", value: "Included")
                        Divider().padding(.leading, 16)
                        PriceRow(label: "Total", value: package.formattedPrice, isTotal: true)
                    }
                    .premiumCard()

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Instant delivery")
                                .font(.subheadline.weight(.semibold))
                            Text("Your eSIM will be ready to install immediately after purchase.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .premiumCard()

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .premiumCard()
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let userID = supabase.currentSession?.user.id ?? "anonymous"
                    Task { await viewModel.purchase(package: package, country: country, userID: userID) }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Confirm Purchase · \(package.formattedPrice)")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(AppTheme.accent)
                .controlSize(.large)
                .disabled(viewModel.isLoading)
                .padding()
            }
            .navigationDestination(item: $viewModel.completedOrder) { order in
                ESIMInstallView(order: order)
            }
        }
    }
}

private struct PriceRow: View {
    let label: LocalizedStringKey
    let value: String
    var isTotal = false

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(isTotal ? .bold : .regular)
            Spacer()
            Text(LocalizedStringKey(value))
                .fontWeight(isTotal ? .bold : .regular)
                .foregroundStyle(isTotal ? .primary : .secondary)
        }
        .padding()
    }
}

#Preview {
    CheckoutView(
        package: ESIMPackage(
            packageID: "test-7days-1gb", slug: nil, type: "local",
            price: 6.50, netPrice: 5.0, amount: 1024, day: 7,
            isUnlimited: false, title: "1 GB - 7 Days", data: "1 GB",
            shortInfo: nil, planType: "data", activationPolicy: "first-usage",
            packageOperator: ESIMOperator(title: "Orange France", isRoaming: true, info: nil),
            countries: ["FR"]
        ),
        country: Country(code: "FR", name: "France")
    )
}
