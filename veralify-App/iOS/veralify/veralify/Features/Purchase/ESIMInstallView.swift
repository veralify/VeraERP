import SwiftUI

struct ESIMInstallView: View {
    let order: LocalOrder
    @State private var showManualInstructions = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("eSIM Ready!")
                        .font(.largeTitle.bold())
                    Text("Your \(order.dataText) plan for \(order.flagEmoji) \(order.countryName) is ready to install.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // QR Code
                VStack(spacing: 12) {
                    Text("Scan with a second device")
                        .font(.subheadline.bold())

                    if let urlString = order.qrcodeURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure:
                                QRCodeFallback(qrcode: order.qrcode)
                            case .empty:
                                ProgressView().frame(width: 200, height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        QRCodeFallback(qrcode: order.qrcode)
                    }

                    Text("Go to **Settings → Cellular → Add Cellular Plan** and scan this QR code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Direct install button (iOS 17.4+)
                if let urlString = order.directAppleInstallURL, let url = URL(string: urlString) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Install on This iPhone", systemImage: "iphone.badge.play")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("Requires iOS 17.4+")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Manual instructions toggle
                DisclosureGroup("Manual Installation", isExpanded: $showManualInstructions) {
                    VStack(alignment: .leading, spacing: 12) {
                        ManualStep(number: 1, text: "Open **Settings → Cellular → Add Cellular Plan**")
                        ManualStep(number: 2, text: "Tap **Enter Details Manually**")
                        ManualStep(number: 3, text: "SM-DP+ Address: **\(order.lpa)**")
                        ManualStep(number: 4, text: "Activation Code: **\(order.matchingID)**")
                        ManualStep(number: 5, text: "Follow on-screen prompts to complete installation")
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // ICCID info
                VStack(alignment: .leading, spacing: 4) {
                    Label("ICCID (save this)", systemImage: "simcard.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(order.iccid)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                Button("Done") { dismiss() }
                    .padding(.bottom, 8)
            }
            .padding()
        }
        .navigationTitle("Install eSIM")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct QRCodeFallback: View {
    let qrcode: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text(qrcode)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 200, height: 200)
    }
}

private struct ManualStep: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(.tint.opacity(0.15), in: Circle())
                .foregroundStyle(.tint)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
