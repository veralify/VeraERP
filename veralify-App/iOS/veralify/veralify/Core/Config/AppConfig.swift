import Foundation

enum AppConfig {
    // MARK: - Veralify Backend Gateway
    // All LLM, purchase validation, and partner API calls route through the backend.
    #if DEBUG
    static let backendGatewayBaseURL = "http://127.0.0.1:3000/api/v1"
    #else
    static let backendGatewayBaseURL = "https://api.veralify.com/api/v1"
    #endif
    static let useMockGatewayResponses = true

    // MARK: - Supabase
    static let supabaseURL = "https://syehqhcexzgtxzavjpmw.supabase.co"
    static let supabaseAnonKey = "sb_publishable_pMSKTLquLKtd2VVWUYAI2Q_5iHOKn2b"
    static let appBundleID = "com.veralify.app"

    // MARK: - StoreKit Subscriptions
    // Configure matching auto-renewable subscriptions in App Store Connect before release.
    enum SubscriptionProductID {
        static let proWeekly = "veralify.pro.weekly"
        static let proMonthly = "veralify.pro.monthly"
        static let proAnnual = "veralify.pro.annual"
        static let coachMonthly = "veralify.coach.monthly"

        static let pro: [String] = [proWeekly, proMonthly, proAnnual]
        static let all: [String] = [proWeekly, proMonthly, proAnnual, coachMonthly]
    }

    // MARK: - Film StoreKit Product IDs
    enum FilmProductID {
        static let upTo5   = "com.veralify.app.film.5"
        static let upTo10  = "com.veralify.app.film.10"
        static let upTo25  = "com.veralify.app.film.25"
        static let upTo50  = "com.veralify.app.film.50"
        static let upTo100 = "com.veralify.app.film.100"
        static let upTo150 = "com.veralify.app.film.150"
        static let upTo200 = "com.veralify.app.film.200"

        static let all: [String] = [upTo5, upTo10, upTo25, upTo50, upTo100, upTo150, upTo200]

        static func productID(for memberLimit: Int) -> String {
            switch memberLimit {
            case ...5:   return upTo5
            case ...10:  return upTo10
            case ...25:  return upTo25
            case ...50:  return upTo50
            case ...100: return upTo100
            case ...150: return upTo150
            default:     return upTo200
            }
        }
    }

    // MARK: - App
    static let appName = "Veralify"
    static let appTagline = "Track. Connect. Transform."
}
