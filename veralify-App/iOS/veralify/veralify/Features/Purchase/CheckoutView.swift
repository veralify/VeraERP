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
                VStack(spacing: 20) {
                    // Order summary card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Text(country.flagEmoji).font(.system(size: 36))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.name).font(.headline)
                                Text(package.operatorName).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        HStack {
                            Label(package.data, systemImage: "wifi")
                            Spacer()
                            Label(package.validityText, systemImage: "calendar")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Price breakdown
                    VStack(spacing: 0) {
                        PriceRow(label: "Plan", value: package.formattedPrice)
                        Divider().padding(.leading, 16)
                        PriceRow(label: "Tax & Fees", value: "Included")
                        Divider().padding(.leading, 16)
                        PriceRow(label: "Total", value: package.formattedPrice, isTotal: true)
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Info
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Instant delivery").fontWeight(.medium)
                            Text("Your eSIM will be ready to install immediately after purchase.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .padding()
            }
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
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                .padding()
                .background(.regularMaterial)
            }
            .navigationDestination(item: $viewModel.completedOrder) { order in
                ESIMInstallView(order: order)
            }
        }
    }
}

private struct PriceRow: View {
    let label: String
    let value: String
    var isTotal = false

    var body: some View {
        HStack {
            Text(label).fontWeight(isTotal ? .bold : .regular)
            Spacer()
            Text(value).fontWeight(isTotal ? .bold : .regular)
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
