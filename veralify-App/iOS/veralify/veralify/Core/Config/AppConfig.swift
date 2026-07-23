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

    // MARK: - App
    static let appName = "Veralify"
    static let appTagline = "Stay Connected Everywhere"

    // MARK: - eSIM Branding
    // This name appears on the eSIM profile in iOS Settings after installation.
    static let eSIMBrandName = "Veralify"
}
