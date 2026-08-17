import SwiftUI

/// A row in the "Recently uploaded" food log list.
struct FoodLogRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(entry.servingDescription) · \(entry.formattedTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.calories) cal")
                    .font(.subheadline.weight(.semibold))
                Text("P\(Int(entry.proteinGrams)) C\(Int(entry.carbGrams)) F\(Int(entry.fatGrams))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = entry.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: entry.source == .barcode ? "barcode.viewfinder" : "fork.knife")
                        .foregroundStyle(.secondary)
                )
        }
    }
}
