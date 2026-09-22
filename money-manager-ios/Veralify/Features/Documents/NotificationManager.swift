import Foundation
import UserNotifications
import Observation

/// Schedules the local reminders that warn before a document expires.
///
/// Every notification is local — `UNCalendarNotificationTrigger` fires from the
/// device's own clock. Nothing is registered with a push server, so no document
/// detail ever leaves the phone.
@Observable
@MainActor
final class NotificationManager {
    enum Permission: Equatable {
        case unknown, granted, denied
    }

    private(set) var permission: Permission = .unknown

    /// The intervals offered. Renewing a passport takes weeks in most countries,
    /// so the useful warnings are months out, not days.
    static let offeredDays = [180, 90, 60, 30, 7]

    static func label(forDays days: Int) -> String {
        switch days {
        case 180: String(localized: "6 months before")
        case 90:  String(localized: "3 months before")
        case 60:  String(localized: "2 months before")
        case 30:  String(localized: "1 month before")
        default:  String(localized: "\(days) days before")
        }
    }

    private let center = UNUserNotificationCenter.current()

    func refreshPermission() async {
        let settings = await center.notificationSettings()
        permission = switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        default: .unknown
        }
    }

    /// Asks once. A second call after a denial does nothing — iOS only ever
    /// shows the system prompt once, and the UI has to send the user to
    /// Settings instead.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            permission = granted ? .granted : .denied
            return granted
        } catch {
            permission = .denied
            return false
        }
    }

    /// Replaces every reminder for one document.
    ///
    /// Cancelling first is what makes this safe to call on every edit: without
    /// it, changing an expiry date leaves the old reminders scheduled and the
    /// user gets warned about a date that no longer exists.
    func reschedule(for document: StoredDocument) async {
        cancel(for: document.id)

        guard permission == .granted,
              let expiry = document.expirationDate,
              !document.reminderDays.isEmpty
        else { return }

        let calendar = Calendar.current

        for days in document.reminderDays {
            guard let fireDate = calendar.date(byAdding: .day, value: -days, to: expiry) else { continue }

            // A reminder for a date already past would never fire, and
            // scheduling it silently is how a user ends up believing they are
            // covered when they are not.
            guard fireDate > Date() else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: fireDate)
            components.hour = 10   // A civilised hour, not whenever the scan happened.
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = document.documentType.title
            content.body = String(
                localized: "Your \(document.documentType.title.lowercased()) (\(document.documentNumber)) expires in \(days) days. Open Veralify to check the details."
            )
            content.sound = .default
            content.userInfo = ["documentID": document.id.uuidString]

            let request = UNNotificationRequest(
                identifier: identifier(document.id, days: days),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            try? await center.add(request)
        }
    }

    func cancel(for documentID: UUID) {
        let identifiers = Self.offeredDays.map { identifier(documentID, days: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// How many reminders are actually scheduled, so the UI can report the
    /// truth rather than what it intended.
    func pendingCount(for documentID: UUID) async -> Int {
        let prefix = "document.\(documentID.uuidString)."
        return await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(prefix) }
            .count
    }

    private func identifier(_ documentID: UUID, days: Int) -> String {
        "document.\(documentID.uuidString).\(days)"
    }
}
