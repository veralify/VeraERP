import SwiftUI

struct ESIMInstallView: View {
    let order: LocalOrder
    @State private var showManualInstructions = false
    @State private var manualSectionID = UUID()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
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
                    .premiumCard()

                    // Native "1-Tap" install using CoreTelephony, mapped
                    // directly from eSIM Go's smdpAddress/matchingId for
                    // this order (see LocalOrder.lpa / .matchingID, which
                    // are populated from ESIMGoInstalledESIM at purchase
                    // time in CheckoutViewModel).
                    ESIMInstantSetupCard(
                        smdpAddress: order.lpa,
                        matchingId: order.matchingID,
                        onShowManualSetup: {
                            withAnimation {
                                showManualInstructions = true
                                proxy.scrollTo(manualSectionID, anchor: .top)
                            }
                        }
                    )

                        VStack(spacing: 12) {
                        Text("Scan with a second device")
                            .font(.headline)

                        if let urlString = order.qrcodeURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFit()
                                        .frame(width: 210, height: 210)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                case .failure:
                                    QRCodeFallback(qrcode: order.qrcode)
                                case .empty:
                                    ProgressView().frame(width: 210, height: 210)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            QRCodeFallback(qrcode: order.qrcode)
                        }

                        Text("Go to **Settings → Cellular → Add Cellular Plan** and scan this QR code.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .premiumCard()

                    if let urlString = order.directAppleInstallURL, let url = URL(string: urlString) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Install on This iPhone", systemImage: "iphone.badge.play")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.premiumGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(.white)
                        }

                        Text("Requires iOS 17.4+")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

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
                    .premiumCard()
                    .id(manualSectionID)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("ICCID", systemImage: "simcard.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(order.iccid)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .premiumCard()

                    Button("Done") { dismiss() }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
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
}

private struct QRCodeFallback: View {
    let qrcode: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode")
                .font(.system(size: 82))
                .foregroundStyle(.secondary)
            Text(qrcode)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(width: 210, height: 210)
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
