import AuthenticationServices
import SwiftUI

/// Accounting integrations: which ledgers the user's business expenses are
/// sent to, and a way to connect another.
///
/// Read-only on purpose. Connections are rows in `accounting_connections`
/// (read through PostgREST with the user's token; column grants hide the
/// token reference), and everything that needs a provider — account mapping,
/// pausing, disconnecting — lives on the web page, where the chart of
/// accounts has room. Connecting works here because it is only a browser
/// round trip: `accounting-connect` returns the provider's consent URL, and
/// `accounting-callback` finishes on the server and sends the browser back
/// to `veralify://integrations`, which the authentication session catches.
///
/// Not wired in yet: push it from a list (it sets its own title) or wrap it in
/// a NavigationStack for a sheet. See docs/RECEIPTS_CONTRACTS.md §6.
struct IntegrationsView: View {
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    @State private var state: LoadState = .loading
    @State private var connectingProvider: AccountingProviderKind?
    @State private var isChoosingProvider = false
    @State private var notice: String?

    private enum LoadState {
        case loading
        case loaded([AccountingConnection])
        case failed
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    if let notice {
                        noticeBanner(notice)
                    }
                    connectionsSection
                    connectButton
                    footnote
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable { await load() }
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await load() }
        .confirmationDialog(
            "Connect accounting software",
            isPresented: $isChoosingProvider,
            titleVisibility: .visible
        ) {
            ForEach(AccountingProviderKind.allCases) { provider in
                Button(provider.title) {
                    Task { await connect(provider) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll sign in with the provider and choose what Veralify may access.")
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var connectionsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Connections") { EmptyView() }
            switch state {
            case .loading:
                GroupedCard {
                    HStack {
                        Spacer()
                        ProgressView().tint(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            case .failed:
                GroupedCard {
                    VStack(spacing: 10) {
                        Text("Couldn't load your integrations.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Button("Try again") { Task { await load() } }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.lime)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            case .loaded(let connections) where connections.isEmpty:
                GroupedCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No integrations yet")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Connect QuickBooks, Xero, FreeAgent or Fatture in Cloud and your business expenses are sent there with their receipts.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                }
            case .loaded(let connections):
                GroupedCard {
                    ForEach(Array(connections.enumerated()), id: \.element.id) { index, connection in
                        if index > 0 { RowDivider() }
                        ConnectionRow(connection: connection)
                    }
                }
            }
        }
    }

    private var connectButton: some View {
        Button {
            isChoosingProvider = true
        } label: {
            HStack(spacing: 8) {
                if connectingProvider != nil {
                    ProgressView().tint(Theme.onAccent)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(connectingProvider == nil ? "Connect" : "Connecting…")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.lime, in: .capsule)
        }
        .buttonStyle(.pressable)
        .disabled(connectingProvider != nil)
    }

    private var footnote: some View {
        Text("Account mapping, pausing and disconnecting are on the web, under Money → Integrations.")
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func noticeBanner(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.lime)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    // MARK: Actions

    private func load() async {
        do {
            let client = try IntegrationsClient(session: Backend.require())
            state = .loaded(try await client.connections())
        } catch {
            // Keep what is on screen during a pull-to-refresh that fails.
            if case .loaded = state { return }
            state = .failed
        }
    }

    private func connect(_ provider: AccountingProviderKind) async {
        connectingProvider = provider
        defer { connectingProvider = nil }
        do {
            let client = try IntegrationsClient(session: Backend.require())
            let url = try await client.authorizeURL(for: provider)
            // A shared (non-ephemeral) session lets the provider reuse a login
            // the user already has in Safari.
            let callback = try await webAuthenticationSession.authenticate(
                using: url,
                callbackURLScheme: IntegrationsClient.callbackScheme,
                preferredBrowserSession: .shared
            )
            notice = IntegrationsClient.message(for: callback, provider: provider)
            await load()
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // The user closed the sheet: nothing to report.
        } catch {
            notice = String(localized: "Couldn't start the connection. Please try again.")
        }
    }
}

// MARK: - Row

private struct ConnectionRow: View {
    let connection: AccountingConnection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(connection.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Pill(text: statusText, style: .muted(dot: statusColor))
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)

            if let error = connection.lastError, connection.status != .revoked {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.red)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let provider = connection.providerKind?.title ?? connection.provider
        let synced: String
        if let date = connection.lastSyncedAt {
            let when = date.formatted(.relative(presentation: .named))
            synced = String(localized: "Last sync \(when)")
        } else {
            synced = String(localized: "Not synced yet")
        }
        return "\(provider) · \(synced)"
    }

    private var isPaused: Bool { connection.status == .active && !connection.autoSync }

    private var statusText: String {
        if isPaused { return String(localized: "Paused") }
        switch connection.status {
        case .active: return String(localized: "Connected")
        case .needsReauth: return String(localized: "Reconnect needed")
        case .revoked: return String(localized: "Disconnected")
        case .error: return String(localized: "Error")
        }
    }

    private var statusColor: Color {
        if isPaused { return Theme.textTertiary }
        switch connection.status {
        case .active: return Theme.green
        case .needsReauth: return Theme.yellow
        case .revoked: return Theme.textTertiary
        case .error: return Theme.red
        }
    }
}

// MARK: - Model

enum AccountingProviderKind: String, CaseIterable, Identifiable, Sendable {
    case quickbooks
    case xero
    case freeagent
    case fattureInCloud = "fatture_in_cloud"

    var id: String { rawValue }

    /// Product names; not translated.
    var title: String {
        switch self {
        case .quickbooks: "QuickBooks Online"
        case .xero: "Xero"
        case .freeagent: "FreeAgent"
        case .fattureInCloud: "Fatture in Cloud"
        }
    }
}

struct AccountingConnection: Decodable, Identifiable, Sendable {
    enum Status: String, Decodable, Sendable {
        case active
        case needsReauth = "needs_reauth"
        case revoked
        case error
    }

    let id: UUID
    let provider: String
    let companyName: String
    let status: Status
    let syncScope: String
    let autoSync: Bool
    let lastSyncedAt: Date?
    let lastError: String?

    var providerKind: AccountingProviderKind? { AccountingProviderKind(rawValue: provider) }

    var displayName: String {
        companyName.isEmpty ? (providerKind?.title ?? provider) : companyName
    }

    private enum CodingKeys: String, CodingKey {
        case id, provider, status
        case companyName = "company_name"
        case syncScope = "sync_scope"
        case autoSync = "auto_sync"
        case lastSyncedAt = "last_synced_at"
        case lastError = "last_error"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        provider = try container.decode(String.self, forKey: .provider)
        companyName = try container.decodeIfPresent(String.self, forKey: .companyName) ?? ""
        status = (try? container.decode(Status.self, forKey: .status)) ?? .error
        syncScope = try container.decodeIfPresent(String.self, forKey: .syncScope) ?? "business"
        autoSync = try container.decodeIfPresent(Bool.self, forKey: .autoSync) ?? false
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        let synced = try container.decodeIfPresent(String.self, forKey: .lastSyncedAt)
        lastSyncedAt = synced.flatMap(IntegrationsClient.parseTimestamp)
    }
}

// MARK: - Backend

/// The two backend calls this screen makes. Tokens never reach the phone:
/// the list is status only, and connecting is a browser round trip.
struct IntegrationsClient: Sendable {
    static let callbackScheme = "veralify"

    let session: any BackendSession

    /// Columns the client may read (the token reference is not granted).
    private static let columns =
        "id,provider,company_name,status,sync_scope,auto_sync,last_synced_at,last_error"

    func connections() async throws -> [AccountingConnection] {
        var components = URLComponents(
            url: session.supabaseURL.appending(path: "rest/v1/accounting_connections"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "select", value: Self.columns),
            URLQueryItem(name: "order", value: "created_at.asc"),
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        try await authorize(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response)
        return try JSONDecoder().decode([AccountingConnection].self, from: data)
    }

    func authorizeURL(for provider: AccountingProviderKind) async throws -> URL {
        var request = URLRequest(url: session.supabaseURL.appending(path: "functions/v1/accounting-connect"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["provider": provider.rawValue, "return_to": "app"])
        try await authorize(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response)
        struct Body: Decodable { let url: URL }
        let url = try JSONDecoder().decode(Body.self, from: data).url
        // Only ever hand the authentication session an https consent page.
        guard url.scheme == "https" else { throw URLError(.badURL) }
        return url
    }

    private func authorize(_ request: inout URLRequest) async throws {
        request.setValue("Bearer \(try await session.accessToken())", forHTTPHeaderField: "Authorization")
        request.setValue(session.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    /// What to tell the user once the browser comes back, from
    /// `veralify://integrations?status=connected&companies=2` and friends.
    static func message(for callback: URL, provider: AccountingProviderKind) -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }
        switch value("status") {
        case "connected":
            let count = Int(value("companies") ?? "") ?? 1
            if count > 1 {
                return String(localized: "Connected \(count) companies from \(provider.title). They start paused — choose which one to sync on the web.")
            }
            return String(localized: "Connected to \(provider.title). Map your accounts on the web to start syncing.")
        default:
            if value("error") == "denied" {
                return String(localized: "Connection cancelled. Nothing was changed.")
            }
            return String(localized: "Couldn't connect to \(provider.title). Please try again.")
        }
    }

    /// Postgres `timestamptz` as PostgREST sends it, with or without fractional seconds.
    static func parseTimestamp(_ text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) { return date }
        // Microsecond precision the formatter will not take: drop the
        // fraction, a sub-second difference is invisible in "Last sync".
        let trimmed = text.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return plain.date(from: trimmed)
    }
}
