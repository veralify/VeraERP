import SwiftUI

/// Pull-to-refresh that runs a sync. For any scrolling screen:
///
///     ScrollView { … }.syncOnRefresh()
///
/// The engine also syncs on its own — when the app comes to the foreground and
/// a moment after every save — so this is for a user who wants to see another
/// device's change *now*.
private struct SyncOnRefresh: ViewModifier {
    @Environment(SyncEngine.self) private var sync: SyncEngine?

    func body(content: Content) -> some View {
        content.refreshable {
            await sync?.sync()
        }
    }
}

extension View {
    func syncOnRefresh() -> some View { modifier(SyncOnRefresh()) }
}
