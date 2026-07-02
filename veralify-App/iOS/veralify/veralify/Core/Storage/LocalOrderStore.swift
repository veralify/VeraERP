import Foundation

final class LocalOrderStore {
    static let shared = LocalOrderStore()
    private init() {}

    private func key(for userID: String) -> String { "com.veralify.orders.\(userID)" }

    func all(for userID: String) -> [LocalOrder] {
        guard let data = UserDefaults.standard.data(forKey: key(for: userID)) else { return [] }
        return (try? JSONDecoder().decode([LocalOrder].self, from: data)) ?? []
    }

    func save(_ order: LocalOrder, for userID: String) {
        var orders = all(for: userID)
        orders.insert(order, at: 0)
        if let data = try? JSONEncoder().encode(orders) {
            UserDefaults.standard.set(data, forKey: key(for: userID))
        }
    }
}
