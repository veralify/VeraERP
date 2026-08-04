import SwiftUI

// MARK: - FilmInviteView

struct FilmInviteView: View {
    let invite: FilmInvite
    let filmName: String

    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                headerSection
                qrSection
                linkSection

                Spacer()
            }
            .padding(.horizontal, 28)
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Invite People")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Share this with your group")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            Text("Anyone with an iPhone can scan the QR code or tap the link to join **\(filmName)**.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var qrSection: some View {
        Group {
            if let qrImage = generateQRCode(from: invite.inviteURL.absoluteString) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            }
        }
    }

    private var linkSection: some View {
        VStack(spacing: 12) {
            Text(invite.webFallbackURL.absoluteString)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            Button {
                showShareSheet = true
            } label: {
                Label("Share Invite Link", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.premiumGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
                    .font(.headline)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [invite.webFallbackURL])
        }
    }

    // MARK: - QR Generation

    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = output.transformed(by: transform)
        return UIImage(ciImage: scaled)
    }
}

// MARK: - ShareSheet (UIActivityViewController wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
