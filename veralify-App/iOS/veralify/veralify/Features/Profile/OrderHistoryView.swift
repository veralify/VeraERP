import SwiftUI

struct OrderHistoryView: View {
    @ObservedObject private var supabase = SupabaseClient.shared
    @State private var orders: [LocalOrder] = []

    private var userID: String { supabase.currentSession?.user.id ?? "anonymous" }

    var body: some View {
        Group {
            if orders.isEmpty {
                ContentUnavailableView(
                    "No Orders Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Your purchase history will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(orders) { order in
                            NavigationLink(destination: ESIMDetailView(order: order)) {
                                HStack(spacing: 12) {
                                    Text(order.flagEmoji).font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(order.countryName).font(.subheadline.bold())
                                        Text(order.dataText + " · " + order.formattedDate)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(order.formattedPrice)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.tint)
                                }
                                .padding(.vertical, 4)
                                .premiumCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Order History")
        .onAppear { orders = LocalOrderStore.shared.all(for: userID) }
        .hidesFloatingNavBar()
    }
}

#Preview {
    NavigationStack { OrderHistoryView() }
}
