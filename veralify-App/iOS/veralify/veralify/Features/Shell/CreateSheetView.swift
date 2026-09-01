import SwiftUI

enum CreateDestination: String, Identifiable, CaseIterable {
    case logFood
    case scanFood
    case progressPhoto
    case post
    case goLive
    case sharedFilm

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .logFood: return "Log Food"
        case .scanFood: return "Scan Food"
        case .progressPhoto: return "Progress Photo"
        case .post: return "Post"
        case .goLive: return "Go Live"
        case .sharedFilm: return "Shared Film"
        }
    }

    var systemImage: String {
        switch self {
        case .logFood: return "fork.knife"
        case .scanFood: return "camera.viewfinder"
        case .progressPhoto: return "person.crop.rectangle.stack"
        case .post: return "square.and.pencil"
        case .goLive: return "dot.radiowaves.left.and.right"
        case .sharedFilm: return "camera.aperture"
        }
    }

    var phaseNote: LocalizedStringKey {
        switch self {
        case .sharedFilm: return "Preserved Film/Foto feature"
        case .logFood, .scanFood: return "Available now"
        default: return "Coming in a later phase"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .logFood:
            ManualFoodLogStandaloneView()
        case .scanFood:
            FoodCameraStandaloneView()
        case .sharedFilm:
            FilmsHomeView()
        default:
            CreatePlaceholderView(destination: self)
        }
    }
}

struct CreateSheetView: View {
    let openDestination: (CreateDestination) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(CreateDestination.allCases) { destination in
                        Button {
                            openDestination(destination)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(destination.title)
                                        .font(.headline)
                                        .foregroundStyle(VeraTokens.Colors.fg)
                                    Text(destination.phaseNote)
                                        .font(.caption)
                                        .foregroundStyle(VeraTokens.Colors.fgMuted)
                                }
                            } icon: {
                                Image(systemName: destination.systemImage)
                                    .foregroundStyle(destination == .sharedFilm ? VeraTokens.Colors.accent : VeraTokens.Colors.primary)
                            }
                        }
                    }
                } header: {
                    Text("Create")
                } footer: {
                    Text("Food logging and scan food are live. Social posting, progress photos, and live rooms remain typed placeholders for future iOS phases.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct CreatePlaceholderView: View {
    let destination: CreateDestination

    var body: some View {
        NavigationStack {
            ShellEmptyStateView(
                title: destination.title,
                message: "This destination is intentionally stubbed and will be implemented in a later build-order phase.",
                systemImage: destination.systemImage,
                ctaTitle: "Coming later",
                ctaSystemImage: "clock"
            )
            .navigationTitle(destination.title)
            .background(AppTheme.screenBackground.ignoresSafeArea())
        }
    }
}
