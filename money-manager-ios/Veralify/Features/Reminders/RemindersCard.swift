import SwiftUI
import SwiftData

/// Reminder settings, in Account.
///
/// Deliberately says what these are — notifications from this phone's own clock,
/// with nothing sent anywhere — because "reminders" in a finance app reasonably
/// makes people wonder who is being told what.
struct RemindersCard: View {
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query private var payments: [DebtPayment]

    @State private var notifications = NotificationManager()
    @State private var leadDays = ReminderSettings.leadDays
    @State private var hour = ReminderSettings.hour
    @State private var dailyCheckIn = ReminderSettings.dailyCheckIn
    @State private var pending = 0

    private var undated: Int {
        debts.filter { $0.dueDay == nil }.count
            + expenses.filter { $0.isActive && $0.dueDay == nil }.count
    }

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Reminders") {
                if pending > 0 {
                    Text("\(pending) scheduled")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            if notifications.permission == .denied {
                AlertBanner(
                    icon: "bell.slash.fill",
                    title: "Notifications are off",
                    message: "Turn them on for Veralify in Settings and these reminders start arriving.",
                    accent: Theme.yellow
                )
            }

            GroupedCard {
                ForEach(Array(ReminderSettings.offeredLeadDays.enumerated()), id: \.element) { index, lead in
                    if index > 0 { RowDivider() }
                    leadRow(lead)
                }

                RowDivider()

                HStack {
                    Text("Time of day")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    Picker("Time of day", selection: $hour) {
                        ForEach(0..<24, id: \.self) { value in
                            Text(Self.hourLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.textPrimary)
                }
                .padding(.vertical, 6)
                .frame(minHeight: 44)

                RowDivider()

                Toggle(isOn: $dailyCheckIn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily nudge")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("One reminder a day to log what you spent")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .tint(Theme.lime)
                .padding(.vertical, 8)
            }

            footnote
        }
        .task {
            await notifications.refreshPermission()
            await refresh()
        }
        .onChange(of: leadDays) { _, value in
            ReminderSettings.leadDays = value
            Task { await permissionThenRefresh() }
        }
        .onChange(of: hour) { _, value in
            ReminderSettings.hour = value
            Task { await refresh() }
        }
        .onChange(of: dailyCheckIn) { _, value in
            ReminderSettings.dailyCheckIn = value
            Task { await permissionThenRefresh() }
        }
    }

    private func leadRow(_ lead: Int) -> some View {
        Button {
            if leadDays.contains(lead) { leadDays.remove(lead) } else { leadDays.insert(lead) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: leadDays.contains(lead) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(leadDays.contains(lead) ? Theme.lime : Theme.textTertiary)
                Text(ReminderSettings.label(forLead: lead))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
            // Matches the time and nudge rows, and keeps the tap target at
            // 44pt however small the label renders.
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pressableRow)
    }

    @ViewBuilder
    private var footnote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reminders come from this phone's own clock. Nothing is sent to a server, so no amount or due date ever leaves the device.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)

            if undated > 0, !leadDays.isEmpty {
                Text("\(undated) items have no due date, so nothing can be scheduled for them.")
                    .font(.caption)
                    .foregroundStyle(Theme.yellow)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// Asked at the moment the user switches something on, not on first launch:
    /// the prompt makes sense when it is obvious what it is for.
    private func permissionThenRefresh() async {
        if ReminderSettings.isAnythingOn, notifications.permission == .unknown {
            await notifications.requestPermission()
        }
        await refresh()
    }

    private func refresh() async {
        await PaymentReminders.reschedule(
            debts: debts,
            expenses: expenses,
            payments: payments,
            permission: notifications.permission
        )
        pending = await PaymentReminders.pendingCount()
    }

    static func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }
}
