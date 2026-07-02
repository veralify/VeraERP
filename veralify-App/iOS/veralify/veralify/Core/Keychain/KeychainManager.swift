import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    private let service = AppConfig.appBundleID

    enum Key: String {
        case accessToken
        case refreshToken
        case airaloToken
        case airaloTokenExpiry
    }

    func save(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func load(for key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(for key: Key) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    func clearAll() {
        delete(for: .accessToken)
        delete(for: .refreshToken)
    }
}
