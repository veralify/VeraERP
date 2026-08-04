import Foundation

enum AppConfig {
    // MARK: - Veralify Backend Gateway
    // All LLM and partner API calls are routed through this backend.
    // Never place raw OpenAI, Duffel, or eSIM provider API keys in iOS code.
    #if DEBUG
    // Local Next.js gateway for simulator testing (pnpm dev on port 3000).
    static let backendGatewayBaseURL = "http://127.0.0.1:3000/api/v1"
    #else
    static let backendGatewayBaseURL = "https://api.veralify.com/v1"
    #endif
    static let useMockGatewayResponses = true

    // MARK: - Supabase
    static let supabaseURL = "https://syehqhcexzgtxzavjpmw.supabase.co"
    static let supabaseAnonKey = "sb_publishable_pMSKTLquLKtd2VVWUYAI2Q_5iHOKn2b"
    static let appBundleID = "com.veralify.app"

    // MARK: - eSIM Go API
    // Docs: https://docs.esim-go.com
    // Create your account and API key in https://portal.esim-go.com
    static let esimGoBaseURL = "https://api.esim-go.com/v2.4"
    static let esimGoAPIKey = "YOUR_ESIMGO_API_KEY"
    // Optional: set if you manage multiple branding profiles in eSIM Go
    static let esimGoBrandingProfileID = ""

    // MARK: - Film StoreKit Product IDs
    // One-time purchase per film. Tiers are based on maximum group size.
    // Configure matching products in App Store Connect before shipping.
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
    static let appTagline = "Stay Connected Everywhere"

    // MARK: - eSIM Branding
    // This name appears on the eSIM profile in iOS Settings after installation.
    static let eSIMBrandName = "Veralify"
}
