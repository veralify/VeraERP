import Foundation

// MARK: - FilmInviteDeepLink

/// Parses `veralify://film/join?token=<token>` deep links produced by FilmInvite.
struct FilmInviteDeepLink {
    let token: String

    // MARK: - Init

    /// Returns nil when the URL is not a valid film invite deep link.
    init?(url: URL) {
        guard url.scheme == "veralify",
              url.host == "film",
              url.path == "/join",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let tokenItem = components.queryItems?.first(where: { $0.name == "token" }),
              let token = tokenItem.value,
              !token.isEmpty
        else { return nil }
        self.token = token
    }

    // MARK: - Web Fallback

    /// Also handles HTTPS web fallback links: `https://veralify.com/join?token=<token>`
    static func parse(url: URL) -> FilmInviteDeepLink? {
        if let deepLink = FilmInviteDeepLink(url: url) { return deepLink }

        // Web fallback
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host, host == "veralify.com",
              components.path == "/join",
              let tokenItem = components.queryItems?.first(where: { $0.name == "token" }),
              let token = tokenItem.value, !token.isEmpty
        else { return nil }

        return FilmInviteDeepLink(rawToken: token)
    }

    private init(rawToken: String) {
        self.token = rawToken
    }
}
