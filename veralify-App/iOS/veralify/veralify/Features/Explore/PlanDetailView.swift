import SwiftUI

struct PlanDetailView: View {
    let package: ESIMPackage
    let country: Country
    @State private var showCheckout = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    Text(country.flagEmoji)
                        .font(.system(size: 48))
                    Text(package.data)
                        .font(.system(size: 48, weight: .bold))
                    Text(package.validityText)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .premiumCard()

                VStack(spacing: 0) {
                    DetailRow(icon: "building.2.fill", label: "Operator", value: package.operatorName)
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "calendar", label: "Validity", value: package.validityText)
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "location.fill", label: "Coverage", value: coverageText)
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "bolt.fill", label: "Activation", value: "On first use")
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "phone.slash", label: "Calls & SMS", value: "Data only")
                }
                .premiumCard()

                if let info = package.shortInfo {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.tint)
                        Text(info)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .premiumCard()
                }

                Spacer(minLength: 24)
            }
            .padding()
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Plan Details")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                showCheckout = true
            } label: {
                HStack {
                    Text("Buy for")
                    Text(package.formattedPrice)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.premiumGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showCheckout) {
            CheckoutView(package: package, country: country)
        }
    }

    private var coverageText: String {
        if package.countries.count == 1 {
            return country.name
        }
        return "\(package.countries.count) countries"
    }
}

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.tint)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        PlanDetailView(
            package: ESIMPackage(
                packageID: "test-7days-1gb",
                slug: "france",
                type: "local",
                price: 6.50,
                netPrice: 5.0,
                amount: 1024,
                day: 7,
                isUnlimited: false,
                title: "1 GB - 7 Days",
                data: "1 GB",
                shortInfo: "Data-only eSIM. No phone number included.",
                planType: "data",
                activationPolicy: "first-usage",
                packageOperator: ESIMOperator(title: "Orange France", isRoaming: true, info: nil),
                countries: ["FR"]
            ),
            country: Country(code: "FR", name: "France")
        )
    }
}
