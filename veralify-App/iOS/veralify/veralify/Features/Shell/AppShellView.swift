import SwiftUI

struct AppShellView: View {
    @State private var selectedTab: AppTab = .home
    @State private var isShowingCreateSheet = false
    @State private var createDestination: CreateDestination?
    @ObservedObject private var navVisibility = NavigationVisibilityTracker.shared
    @EnvironmentObject private var localization: LocalizationManager

    private var isNavBarHidden: Bool { navVisibility.pushedScreenCount > 0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack { HomeRootView() }
                case .track:
                    NavigationStack { TrackRootView() }
                case .connect:
                    NavigationStack { ConnectRootView() }
                case .profile:
                    ProfileView()
                }
            }
            .ignoresSafeArea(.keyboard)
            .id(localization.language)

            if !isNavBarHidden {
                FloatingNavBar(selection: $selectedTab) { isShowingCreateSheet = true }
                    .padding(.bottom, VeraTokens.Spacing._2)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(Double(VeraTokens.ZIndex.nav))
            }
        }
        .animation(.easeInOut(duration: VeraTokens.Motion.Duration.base), value: isNavBarHidden)
        .sheet(isPresented: $isShowingCreateSheet) {
            CreateSheetView { destination in
                isShowingCreateSheet = false
                createDestination = destination
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $createDestination) { destination in
            destination.view
        }
    }
}

#Preview { AppShellView().environmentObject(LocalizationManager.shared).environmentObject(FilmViewModel()) }
