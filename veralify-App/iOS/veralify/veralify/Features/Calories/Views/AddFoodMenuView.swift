import SwiftUI

/// The three ways to log a meal, presented from the "+" button — matches
/// Cal AI's "Scan Food / Barcode / Food Label" bottom bar.
struct AddFoodMenuView: View {
    let onSelect: (AddFoodOption) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("Log a Meal")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(AddFoodOption.allCases) { option in
                Button {
                    dismiss()
                    onSelect(option)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.premiumGradient, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title).font(.subheadline.weight(.semibold))
                            Text(option.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .presentationDetents([.medium])
    }
}

enum AddFoodOption: CaseIterable, Identifiable {
    case photo
    case barcode
    case text

    var id: Self { self }

    var title: String {
        switch self {
        case .photo:   return "Scan Food"
        case .barcode: return "Scan Barcode"
        case .text:    return "Describe Meal"
        }
    }

    var subtitle: String {
        switch self {
        case .photo:   return "Snap a photo for instant calorie estimates"
        case .barcode: return "Look up packaged food nutrition facts"
        case .text:    return "Type what you ate and let AI estimate it"
        }
    }

    var systemImage: String {
        switch self {
        case .photo:   return "camera.fill"
        case .barcode: return "barcode.viewfinder"
        case .text:    return "text.cursor"
        }
    }
}
