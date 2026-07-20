import SwiftUI

struct eSIMCardView: View {
    let plan: ESIMCatalogItem
    var onSelect: (() -> Void)?

    init(plan: ESIMCatalogItem, onSelect: (() -> Void)? = nil) {
        self.plan = plan
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(plan.countryCode.toFlagEmoji()) \(plan.countryName)")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(plan.packageName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Text(plan.formattedPrice)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.mint)
            }

            HStack(spacing: 10) {
                statPill(title: "Data", value: plan.dataAllowance)
                statPill(title: "Validity", value: "\(plan.validityDays)d")
            }

            if let onSelect {
                Button(action: onSelect) {
                    Text("Select Plan")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.premiumGradient)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.countryName) eSIM plan, \(plan.dataAllowance), valid for \(plan.validityDays) days, \(plan.formattedPrice)")
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
