import Foundation
import UserNotifications
import VeralifyCore

/// When the user wants to be told about money that is about to leave.
///
/// Held in `UserDefaults` rather than SwiftData for the same reason as
/// `AppSettings`: the scheduler runs from the app's lifecycle, not from a view,
/// and has no model context to read from.
enum ReminderSettings {
    enum Key {
        static let leadDays = "reminderLeadDays"
        static let hour = "reminderHour"
        static let dailyCheckIn = "reminderDailyCheckIn"
        static let hasChosen = "reminderHasChosen"
    }

    /// How far ahead a warning can be set. Bills are monthly, so anything
    /// further out than a week is noise rather than notice.
    static let offeredLeadDays = [7, 3, 1, 0]

    static func label(forLead days: Int) -> String {
        switch days {
        case 0:  String(localized: "On the day")
        case 1:  String(localized: "The day before")
        default: String(localized: "\(days) days before")
        }
    }

    /// Defaults to three days and the day itself — enough warning to move money,
    /// and a nudge when it actually matters.
    static var leadDays: Set<Int> {
        get {
            guard UserDefaults.standard.bool(forKey: Key.hasChosen) else { return [3, 0] }
            let stored = UserDefaults.standard.array(forKey: Key.leadDays) as? [Int] ?? []
            return Set(stored)
        }
        set {
            UserDefaults.standard.set(true, forKey: Key.hasChosen)
            UserDefaults.standard.set(newValue.sorted(by: >), forKey: Key.leadDays)
        }
    }

    /// 24-hour clock. Nine in the morning: late enough not to wake anyone, early
    /// enough to do something about it before the bank closes.
    static var hour: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: Key.hour) as? Int
            return stored.map { min(max($0, 0), 23) } ?? 9
        }
        set { UserDefaults.standard.set(min(max(newValue, 0), 23), forKey: Key.hour) }
    }

    /// One nudge a day to log what was spent, for the streak.
    static var dailyCheckIn: Bool {
        get { UserDefaults.standard.bool(forKey: Key.dailyCheckIn) }
        set { UserDefaults.standard.set(newValue, forKey: Key.dailyCheckIn) }
    }

    static var isAnythingOn: Bool { !leadDays.isEmpty || dailyCheckIn }
}

/// Schedules the local reminders for payments that are about to fall due.
///
/// Local, like every other notification in this app: a
/// `UNCalendarNotificationTrigger` fires from the device's own clock. There is
/// no server, nothing is registered with APNs, and no amount, debt name or due
/// date leaves the phone — which is also why they keep working on a plane.
///
/// The cost of that is a queue: iOS holds at most 64 pending local
/// notifications per app and silently drops the rest, so this schedules a
/// bounded window of the soonest ones and tops it up whenever the app comes
/// back to the foreground.
@MainActor
enum PaymentReminders {
    /// Ceiling for money reminders, leaving headroom under the system's 64 for
    /// the document vault's expiry warnings.
    static let maxPending = 40
    /// How many future occurrences of a monthly bill to queue. Three months is
    /// far longer than anyone leaves an app unopened, and well inside the cap.
    static let monthsAhead = 3

    private static let prefix = "money."
    private static let dailyIdentifier = "money.daily"

    /// FNV-1a. `hashValue` is seeded per process, so an identifier built from it
    /// is different on every launch — every reminder would look new, and the
    /// whole queue would be torn down and rebuilt each time the app opened.
    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return hash
    }

    /// Identifies a reminder by what it says as well as what it is about, so
    /// editing an amount replaces the queued text rather than leaving it stale.
    private static func key(_ parts: String...) -> String {
        "\(stableHash(parts.joined(separator: "|")) % 1_000_000_000)"
    }

    /// One thing worth a notification, at one moment.
    private struct Reminder {
        let identifier: String
        let fireDate: Date
        let name: String
        let amount: Decimal
        let leadDays: Int
    }

    /// Replaces every money reminder with a fresh set.
    ///
    /// Cancelling first is what makes this safe to call on every launch: without
    /// it, editing a due date leaves the old reminder queued and the user is
    /// warned about a date that no longer exists.
    static func reschedule(
        debts: [DebtRecord],
        expenses: [ExpenseItem],
        payments: [DebtPayment],
        permission: NotificationManager.Permission,
        now: Date = .now
    ) async {
        let center = UNUserNotificationCenter.current()

        guard permission == .granted else {
            await removeAll(in: center)
            return
        }

        let leads = ReminderSettings.leadDays
        let calendar = Calendar.current
        let hour = ReminderSettings.hour
        var candidates: [Reminder] = []

        // A payment the user deliberately planned outranks the debt's generic
        // due day in the month it falls in: they have already decided what and
        // when. Other months keep their usual reminder — a single planned
        // payment used to silence the debt's reminders for every month ahead.
        func monthKey(_ date: Date) -> Int {
            let parts = calendar.dateComponents([.year, .month], from: date)
            return (parts.year ?? 0) * 12 + (parts.month ?? 0)
        }
        var plannedMonths: [Int: Set<Int>] = [:]
        for payment in payments where !payment.isPaid {
            plannedMonths[payment.debtRemoteID, default: []].insert(monthKey(payment.date))
        }
        for payment in payments where !payment.isPaid {
            guard let debt = debts.first(where: { $0.remoteID == payment.debtRemoteID }) else { continue }
            for lead in leads {
                candidates.append(
                    contentsOf: reminders(
                        identifier: "planned.\(key(String(debt.remoteID), "\(payment.date.timeIntervalSince1970)", "\(payment.amount)", debt.name)).\(lead)",
                        name: debt.name,
                        amount: payment.amount,
                        dates: [payment.date],
                        lead: lead,
                        hour: hour,
                        calendar: calendar,
                        now: now
                    )
                )
            }
        }

        for debt in debts where !debt.isPaidOff {
            guard let dueDay = debt.dueDay else { continue }
            let skipped = plannedMonths[debt.remoteID] ?? []
            let dates = BillSchedule.occurrences(
                dueDay: dueDay, from: now, count: monthsAhead, calendar: calendar
            ).filter { !skipped.contains(monthKey($0)) }
            for lead in leads {
                candidates.append(
                    contentsOf: reminders(
                        identifier: "debt.\(debt.remoteID).\(key("\(dueDay)", "\(debt.monthlyPayment)", debt.name)).\(lead)",
                        name: debt.name,
                        amount: debt.monthlyPayment,
                        dates: dates,
                        lead: lead,
                        hour: hour,
                        calendar: calendar,
                        now: now
                    )
                )
            }
        }

        for expense in expenses where expense.isActive {
            guard let dueDay = expense.dueDay else { continue }
            let dates = BillSchedule.occurrences(
                dueDay: dueDay, from: now, count: monthsAhead, calendar: calendar
            )
            for lead in leads {
                candidates.append(
                    contentsOf: reminders(
                        identifier: "expense.\(key(expense.name, "\(dueDay)", "\(expense.amount)")).\(lead)",
                        name: expense.name,
                        amount: expense.amount,
                        dates: dates,
                        lead: lead,
                        hour: hour,
                        calendar: calendar,
                        now: now
                    )
                )
            }
        }

        // Soonest first, then truncate: if something has to be dropped it should
        // be the reminder three months out, not tomorrow's.
        let wanted = Array(candidates.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))

        // Reconciled against what is already queued rather than cancelled and
        // rebuilt. `removePendingNotificationRequests` is processed on its own
        // queue, so a removal issued immediately before a batch of adds can land
        // *after* some of them and quietly delete what was just scheduled —
        // which is exactly what happened: forty were queued and fourteen
        // survived.
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        let existingIDs = Set(existing)

        var wantedIDs = Set(wanted.map(\.identifier))
        if ReminderSettings.dailyCheckIn { wantedIDs.insert(dailyIdentifier) }

        let stale = existingIDs.subtracting(wantedIDs)
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(stale))
        }

        if ReminderSettings.dailyCheckIn, !existingIDs.contains(dailyIdentifier) {
            await addDailyCheckIn(to: center)
        }

        for reminder in wanted where !existingIDs.contains(reminder.identifier) {
            await add(reminder, to: center)
        }
    }

    /// Turns one due date into a reminder at `lead` days before it, if that
    /// moment is still ahead of us.
    private static func reminders(
        identifier: String,
        name: String,
        amount: Decimal,
        dates: [Date],
        lead: Int,
        hour: Int,
        calendar: Calendar,
        now: Date
    ) -> [Reminder] {
        dates.enumerated().compactMap { index, due in
            guard let fire = calendar.date(byAdding: .day, value: -lead, to: calendar.startOfDay(for: due)),
                  let atHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: fire),
                  // A reminder for a moment already past never fires, and
                  // queueing it silently is how someone ends up believing they
                  // are covered when they are not.
                  atHour > now
            else { return nil }

            return Reminder(
                identifier: "\(prefix)\(identifier).\(index)",
                fireDate: atHour,
                name: name,
                amount: amount,
                leadDays: lead
            )
        }
    }

    private static func add(_ reminder: Reminder, to center: UNUserNotificationCenter) async {
        let content = UNMutableNotificationContent()
        content.title = reminder.name
        content.body = body(for: reminder)
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: reminder.fireDate
        )
        let request = UNNotificationRequest(
            identifier: reminder.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    private static func body(for reminder: Reminder) -> String {
        let amount = CurrencyFormat.string(reminder.amount)
        switch reminder.leadDays {
        case 0:  return String(localized: "\(amount) is due today.")
        case 1:  return String(localized: "\(amount) is due tomorrow.")
        default: return String(localized: "\(amount) is due in \(reminder.leadDays) days.")
        }
    }

    /// One repeating trigger rather than a queue of dailies: it costs a single
    /// slot and never needs topping up.
    private static func addDailyCheckIn(to center: UNUserNotificationCenter) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Today's quests")
        content.body = String(localized: "Log what you spent or received to keep your streak going.")
        content.sound = .default

        var components = DateComponents()
        components.hour = ReminderSettings.hour
        components.minute = 0

        let request = UNNotificationRequest(
            identifier: dailyIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    private static func removeAll(in center: UNUserNotificationCenter) async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// What is actually queued, so the UI can report the truth rather than what
    /// it intended.
    static func pendingCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(prefix) }
            .count
    }
}
