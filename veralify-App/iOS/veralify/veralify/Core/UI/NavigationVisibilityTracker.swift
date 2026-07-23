import SwiftUI
import Combine

/// Tracks how many pushed (non-root) screens are currently on screen across
/// *any* tab's navigation stack. `ContentView` hides the floating nav bar
/// whenever this is non-zero — i.e. whenever the system back button would
/// be showing — regardless of which tab the user is in.
@MainActor
final class NavigationVisibilityTracker: ObservableObject {
    static let shared = NavigationVisibilityTracker()
    private init() {}

    @Published private(set) var pushedScreenCount = 0

    func push() { pushedScreenCount += 1 }
    func pop() { pushedScreenCount = max(0, pushedScreenCount - 1) }
}

private struct HidesFloatingNavBarModifier: ViewModifier {
    @ObservedObject private var tracker = NavigationVisibilityTracker.shared

    func body(content: Content) -> some View {
        content
            .onAppear { tracker.push() }
            .onDisappear { tracker.pop() }
    }
}

extension View {
    /// Marks a pushed screen (one that shows a back button) so the floating
    /// tab bar hides itself while it's on screen. Apply this to destination
    /// views reached via `NavigationLink`/`navigationDestination` — never to
    /// a tab's own root view.
    func hidesFloatingNavBar() -> some View {
        modifier(HidesFloatingNavBarModifier())
    }
}
