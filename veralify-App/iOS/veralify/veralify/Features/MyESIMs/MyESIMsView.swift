import Foundation
import SwiftUI
import Combine

struct MyESIMsView: View {
    @StateObject private var viewModel = MyESIMsViewModel()
    @ObservedObject private var supabase = SupabaseClient.shared

    private var userID: String {
        supabase.currentSession?.user.id ?? "anonymous"
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.orders.isEmpty {
                    ContentUnavailableView(
                        "No eSIMs Yet",
                        systemImage: "simcard.2.fill",
                        description: Text("Buy your first eSIM in Explore.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.orders) { order in
                                NavigationLink(destination: ESIMDetailView(order: order)) {
                                    ESIMCard(order: order, usage: viewModel.usageMap[order.iccid])
                                }
                                .buttonStyle(.plain)
                                .task { await viewModel.fetchUsage(for: order) }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My eSIM")
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .onAppear { viewModel.load(userID: userID) }
        }
    }
}

struct ESIMCard: View {
    let order: LocalOrder
    let usage: SIMUsage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(order.flagEmoji) \(order.countryName)")
                        .font(.headline)
                    Text(order.packageTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(status: usage?.displayStatus ?? "Active")
            }

            if let usage {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: usage.usageFraction)
                        .tint(progressColor(fraction: usage.usageFraction))
                    HStack {
                        Text(usage.formattedRemaining)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(order.dataText)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                ProgressView().scaleEffect(0.7)
            }

            Text("Purchased \(order.formattedDate)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .premiumCard()
    }

    private func progressColor(fraction: Double) -> Color {
        if fraction < 0.6 { return .green }
        if fraction < 0.85 { return .orange }
        return .red
    }
}

private struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status.uppercased() {
        case "ACTIVE": return .green
        case "EXPIRED": return .red
        case "FINISHED", "DEPLETED": return .orange
        default: return .secondary
        }
    }
}

#Preview {
    MyESIMsView()
}
