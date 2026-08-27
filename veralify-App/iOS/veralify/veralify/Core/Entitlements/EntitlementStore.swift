import Foundation
import Observation

private struct UserEntitlementRow: Codable {
    let entitlementKey: EntitlementKey
    let expiresAt: String?
    let active: Bool?

    enum CodingKeys: String, CodingKey {
        case entitlementKey = "entitlement_key"
        case expiresAt = "expires_at"
        case active
    }
}

private struct CachedEntitlements: Codable {
    let keys: Set<EntitlementKey>
    let fetchedAt: Date
}

@MainActor
@Observable
final class EntitlementStore {
    static let shared = EntitlementStore()

    private(set) var activeKeys: Set<EntitlementKey> = []
    private(set) var lastRefresh: Date?
    private(set) var isRefreshing = false
    private(set) var warningMessage: String?

    private let supabase = SupabaseClient.shared
    private let cacheKey = "veralify.entitlements.cache.v1"
    private let cacheTTL: TimeInterval = 5 * 60

    private init() {
        loadCacheIfFresh()
    }

    func contains(_ key: EntitlementKey) -> Bool {
        activeKeys.contains(key)
    }

    func refreshIfNeeded() async {
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < cacheTTL { return }
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let authUser = try await supabase.getUser()
            let rows: [UserEntitlementRow] = try await supabase.select(
                from: "user_entitlements",
                columns: "entitlement_key,expires_at,active",
                filters: ["user_id": authUser.id]
            )
            let now = Date()
            let keys = Set(rows.compactMap { row -> EntitlementKey? in
                guard row.active ?? true else { return nil }
                if let expiresAt = row.expiresAt,
                   let expiry = Self.isoFormatter.date(from: expiresAt),
                   expiry <= now {
                    return nil
                }
                return row.entitlementKey
            })
            activeKeys = keys
            lastRefresh = now
            warningMessage = nil
            saveCache(keys: keys, fetchedAt: now)
        } catch {
            activeKeys = []
            lastRefresh = Date()
            warningMessage = "Entitlements unavailable; treating user as not entitled. \(error.localizedDescription)"
            print("[EntitlementStore] user_entitlements fetch failed; defaulting to no entitlements: \(error)")
        }
    }

    private func loadCacheIfFresh() {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let cached = try? JSONDecoder().decode(CachedEntitlements.self, from: data),
            Date().timeIntervalSince(cached.fetchedAt) < cacheTTL
        else { return }
        activeKeys = cached.keys
        lastRefresh = cached.fetchedAt
    }

    private func saveCache(keys: Set<EntitlementKey>, fetchedAt: Date) {
        let cached = CachedEntitlements(keys: keys, fetchedAt: fetchedAt)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private static let isoFormatter = ISO8601DateFormatter()
}
