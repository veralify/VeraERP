import Foundation

enum AppConfig {
    // MARK: - Supabase
    static let supabaseURL = "https://syehqhcexzgtxzavjpmw.supabase.co"
    static let supabaseAnonKey = "sb_publishable_pMSKTLquLKtd2VVWUYAI2Q_5iHOKn2b"
    static let appBundleID = "com.veralify.app"

    // MARK: - Airalo Partner API
    // Sign up at https://partners.airalo.com to get credentials
    static let airaloBaseURL = "https://partners-api.airalo.com"
    static let airaloClientID = "YOUR_AIRALO_CLIENT_ID"
    static let airaloClientSecret = "YOUR_AIRALO_CLIENT_SECRET"

    // MARK: - App
    static let appName = "Veralify"
    static let appTagline = "Stay Connected Everywhere"

    // MARK: - eSIM Branding
    // This name appears on the eSIM profile in iOS Settings after installation.
    // Set up your brand in the Airalo Partner Platform first:
    // https://app.partners.airalo.com → Brand Settings
    static let eSIMBrandName = "Veralify"
}
