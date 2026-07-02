import Foundation
import SwiftUI
import Combine

struct ESIMDetailView: View {
    let order: LocalOrder
    @State private var usage: SIMUsage?
    @State private var isLoadingUsage = true
    @State private var showQR = false

    private let airalo = AiraloClient.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero
                VStack(spacing: 6) {
                    Text(order.flagEmoji).font(.system(size: 52))
                    Text(order.countryName).font(.title2.bold())
                    Text(order.packageTitle).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))

                // Data usage
                VStack(alignment: .leading, spacing: 12) {
                    Label("Data Usage", systemImage: "chart.bar.fill")
                        .font(.headline)

                    if isLoadingUsage {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let u = usage {
                        VStack(spacing: 6) {
                            ProgressView(value: u.usageFraction)
                                .tint(u.usageFraction < 0.8 ? .green : .orange)
                                .scaleEffect(x: 1, y: 1.6)
                            HStack {
                                Text(u.formattedRemaining).font(.subheadline.bold())
                                Spacer()
                                Text("of \(order.dataText)").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        StatusBadge(status: u.displayStatus)
                    } else {
                        Text("Usage data unavailable").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                // eSIM details
                VStack(spacing: 0) {
                    InfoRow(label: "ICCID", value: order.iccid, mono: true)
                    Divider().padding(.leading, 16)
                    InfoRow(label: "Purchased", value: order.formattedDate)
                    Divider().padding(.leading, 16)
                    InfoRow(label: "Price Paid", value: order.formattedPrice)
                    Divider().padding(.leading, 16)
                    InfoRow(label: "Validity", value: "\(order.validityDays) days")
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                // Actions
                VStack(spacing: 12) {
                    if let urlStr = order.directAppleInstallURL, let url = URL(string: urlStr) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Reinstall eSIM", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button {
                        showQR = true
                    } label: {
                        Label("Show QR Code", systemImage: "qrcode")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("eSIM Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let u = try? await airalo.getSimUsage(iccid: order.iccid) {
                usage = u
            }
            isLoadingUsage = false
        }
        .sheet(isPresented: $showQR) {
            NavigationStack {
                ESIMInstallView(order: order)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showQR = false }
                        }
                    }
            }
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var mono = false

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .font(mono ? .system(.caption, design: .monospaced) : .body)
                .textSelection(.enabled)
        }
        .padding()
    }
}

private struct StatusBadge: View {
    let status: String
    var body: some View {
        Text(status)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor)
    }
    private var statusColor: Color {
        switch status.uppercased() {
        case "ACTIVE": return .green
        case "EXPIRED": return .red
        default: return .orange
        }
    }
}
