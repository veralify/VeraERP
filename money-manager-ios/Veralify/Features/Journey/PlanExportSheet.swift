import SwiftUI
import SwiftData
import PDFKit
import VeralifyCore

/// Pick how the exported plan looks, then take it out of the app.
///
/// The preview is the document itself, rendered and shown — not a drawing of
/// what it might look like. Choosing a layout from a name and a description is
/// guessing; this way the thing you approve is the thing you get.
///
/// Everything is made on the device and handed to the share sheet. Nothing is
/// uploaded, and the file goes where you send it and nowhere else.
struct PlanExportSheet: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    @Environment(\.dismiss) private var dismiss

    @AppStorage("planPDFStyle") private var styleRaw = PlanPDFStyle.tracker.rawValue
    @AppStorage("planPDFAccent") private var accentRaw = PlanPDFAccent.forest.rawValue

    @State private var preview: UIImage?
    /// Rendered page-one images, one per layout, keyed by layout and colour.
    /// Ten documents is too much to redraw on every tap, and a thumbnail that
    /// appears a beat late is better than a strip that stutters.
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var exported: URL?
    @State private var failure: String?

    private var style: PlanPDFStyle { PlanPDFStyle(rawValue: styleRaw) ?? .tracker }
    private var accent: PlanPDFAccent { PlanPDFAccent(rawValue: accentRaw) ?? .forest }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        page
                        styles
                        colours
                        actions
                        footnote
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Export plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .task(id: "\(styleRaw)-\(accentRaw)") { await refreshPreview() }
            .task(id: accentRaw) { await refreshThumbnails() }
            .sheet(item: $exported) { ShareSheet(url: $0) }
            .alert(
                "Could not export",
                isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    // MARK: - The live page

    @ViewBuilder
    private var page: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white)
                .aspectRatio(595 / 842, contentMode: .fit)

            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 10))
            } else {
                ProgressView().tint(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.stroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
        .animation(.smooth(duration: 0.25), value: preview)
    }

    // MARK: - Choices

    private var styles: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Layout")
                    .font(.caption.weight(.bold))
                    .kerning(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 8)
                // Two lines before it shrinks: the longer descriptions did
                // not fit one line on a small phone and were cut off.
                Text(style.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(PlanPDFStyle.allCases) { option in
                        Button { styleRaw = option.rawValue } label: {
                            thumbnail(option)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    /// A real page, small. A drawn approximation of a layout would be a
    /// different document from the one the button produces.
    private func thumbnail(_ option: PlanPDFStyle) -> some View {
        let isSelected = style == option

        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(.white)
                if let image = thumbnails[key(option)] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 6))
                }
            }
            .frame(width: 66, height: 93)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Theme.lime : Theme.stroke, lineWidth: isSelected ? 2 : 1)
            )

            // Held to the page's width, so a long name cannot push the
            // thumbnails in the strip apart unevenly.
            Text(option.title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? Theme.lime : Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 66)
        }
    }

    private func key(_ option: PlanPDFStyle) -> String { "\(option.rawValue)-\(accentRaw)" }

    private var colours: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Colour")
                .font(.caption.weight(.bold))
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textTertiary)

            // Each 34pt swatch sits in a 44pt target with no gap between
            // them, which puts the circles exactly as far apart as they were.
            // The negative padding lets the targets overhang so the circles
            // still line up with the label above.
            HStack(spacing: 0) {
                ForEach(PlanPDFAccent.allCases) { option in
                    Button { accentRaw = option.rawValue } label: {
                        Circle()
                            .fill(option.swatch)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(.white)
                                    .opacity(accent == option ? 1 : 0)
                            )
                            .overlay(
                                Circle().strokeBorder(
                                    accent == option ? Theme.textPrimary : Theme.stroke,
                                    lineWidth: accent == option ? 2 : 1
                                )
                            )
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(String(describing: option))
                }
                Spacer(minLength: 0)
            }
            .padding(-5)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button { export(.pdf) } label: {
                exportLabel("PDF", icon: "doc.richtext", isPrimary: true)
            }
            .buttonStyle(.pressable)

            Button { export(.csv) } label: {
                exportLabel("Spreadsheet", icon: "tablecells", isPrimary: false)
            }
            .buttonStyle(.pressable)
        }
    }

    private func exportLabel(
        _ title: LocalizedStringKey,
        icon: String,
        isPrimary: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            Text(title).font(.subheadline.weight(.bold))
        }
        .foregroundStyle(isPrimary ? Theme.onAccent : Theme.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(isPrimary ? Theme.lime : Theme.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(isPrimary ? .clear : Theme.stroke, lineWidth: 1))
    }

    private var footnote: some View {
        Text("The file is made on this device and shared only where you send it. A spreadsheet always exports the same columns, whichever layout you pick.")
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: - Building the document

    private enum Format { case pdf, csv }

    @MainActor
    private func parts() -> (plan: PayoffPlan, steps: [JourneyStep], summary: JourneySummary) {
        let dashboard = DashboardSummary(
            income: income, expenses: expenses, debts: debts, settings: settings.first
        )
        let values = debts.map(\.asDebt)
        return (
            dashboard.plan,
            JourneyBuilder.steps(plan: dashboard.plan, debts: values),
            JourneyBuilder.summary(plan: dashboard.plan, debts: values)
        )
    }

    private func document() -> PlanPDF {
        let parts = parts()
        return PlanPDF(
            plan: parts.plan, steps: parts.steps, summary: parts.summary,
            style: style, accent: accent
        )
    }

    /// Renders page one at screen scale. Off the main actor because a long plan
    /// is several pages of drawing and the picker has to stay responsive while
    /// the user flicks between layouts.
    private func refreshPreview() async {
        let data = document().data()

        let image: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let page = PDFDocument(data: data)?.page(at: 0) else { return nil }
            let box = page.bounds(for: .mediaBox)
            return page.thumbnail(of: CGSize(width: box.width * 2, height: box.height * 2), for: .mediaBox)
        }.value

        preview = image
    }

    /// One small page per layout, rendered one at a time so the strip fills in
    /// rather than blocking on all ten.
    private func refreshThumbnails() async {
        thumbnails = [:]
        for option in PlanPDFStyle.allCases {
            guard !Task.isCancelled else { return }
            let parts = parts()
            let document = PlanPDF(
                plan: parts.plan, steps: parts.steps, summary: parts.summary,
                style: option, accent: accent
            )
            let data = document.data()

            let image: UIImage? = await Task.detached(priority: .utility) {
                guard let page = PDFDocument(data: data)?.page(at: 0) else { return nil }
                return page.thumbnail(of: CGSize(width: 132, height: 186), for: .mediaBox)
            }.value

            if let image { thumbnails[key(option)] = image }
        }
    }

    /// ISO date, deliberately. A localised one formats as `09/22/2026`, and
    /// `appendingPathComponent` reads those slashes as folders — the export
    /// failed with "the folder 2026.csv doesn't exist".
    private var filename: String {
        let day = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "Veralify plan \(day)"
    }

    private func export(_ format: Format) {
        let parts = parts()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).\(format == .pdf ? "pdf" : "csv")")

        do {
            switch format {
            case .pdf:
                try document().data().write(to: url, options: .atomic)
            case .csv:
                try PlanExport.csv(plan: parts.plan, steps: parts.steps)
                    .write(to: url, atomically: true, encoding: .utf8)
            }
            exported = url
        } catch {
            failure = error.localizedDescription
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// The system share sheet, which SwiftUI has no native equivalent of for a file
/// URL produced on demand.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
