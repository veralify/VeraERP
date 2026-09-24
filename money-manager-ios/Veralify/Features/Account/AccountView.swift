import SwiftUI
import SwiftData
import UserNotifications

/// The account, preferences, what is stored, and the ways out.
///
/// Only preferences. The payoff plan's own controls sit on the Plan tab, where
/// the plan is, and the document wallet is a tab — neither was a setting, and
/// both were unfindable in here.
struct AccountView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]
    @Query private var transactions: [TransactionRecord]
    @Query private var questCompletions: [QuestCompletion]
    @Query private var payments: [DebtPayment]
    @Query private var snapshots: [MonthlySnapshot]
    @Query private var familyMembers: [FamilyMember]
    @Query private var familyExpenses: [FamilyExpense]
    @Query private var familySettlements: [FamilySettlement]
    @Query private var documents: [StoredDocument]
    @Query private var budgets: [CategoryBudget]
    @Query private var losses: [MoneyLoss]
    @Query private var incomeActuals: [IncomeActual]

    @State private var isConfirmingReset = false
    @State private var isShowingRestartNote = false
    @Environment(\.dismiss) private var dismiss

    @Environment(AuthModel.self) private var auth
    @Environment(SyncEngine.self) private var sync
    /// Unsynced changes found when the user asked to sign out; the dialog
    /// warns about them. Nil while no sign-out is being confirmed.
    @State private var signOutPending: Int?
    @State private var isConfirmingDeletion = false
    /// Signing out or deleting: the controls are disabled meanwhile.
    @State private var isLeaving = false
    @State private var leaveError: String?

    @AppStorage(AppSettings.Key.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    /// Mirrors `Language.current`, but as state so the picker updates the row
    /// straight away rather than only after a relaunch.
    @State private var language = Language.current
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Label and menu side by side; stacked at accessibility text sizes, where
    /// a currency name such as "€  Euro" beside its label was squeezed into a
    /// truncated sliver.
    private var pickerRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
    }

    private var appVersion: String {
        let bundle = Bundle.main.infoDictionary
        let version = bundle?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        accountCard
                        LevelPanel()
                        RemindersCard()
                        displayCard
                        dataCard
                        aboutCard
                        resetCard
                        deleteAccountCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .syncOnRefresh()
                .disabled(isLeaving)

                if isLeaving {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.lime)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.lime)
                }
            }
        }
        .confirmationDialog(
            "Delete all data?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) { resetEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your income, expenses, debts and recorded entries will be permanently deleted from this phone and your account, and setup will start again. This cannot be undone.")
        }
        .confirmationDialog(
            "Sign out?",
            isPresented: Binding(get: { signOutPending != nil }, set: { if !$0 { signOutPending = nil } }),
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let pending = signOutPending, pending > 0 {
                Text("\(pending) changes haven't reached your account yet and will be lost. Connect to the internet first to keep them.")
            } else {
                Text("Your money data stays in your account and is removed from this phone. ID documents and family splits stay on this phone.")
            }
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your Veralify account and everything in it — income, expenses, debts, entries and receipt photos — on every device and on the web. This cannot be undone.")
        }
        .alert(
            "That didn't work",
            isPresented: Binding(get: { leaveError != nil }, set: { if !$0 { leaveError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(leaveError ?? "")
        }
        .alert("Reopen to finish", isPresented: $isShowingRestartNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Close and reopen Veralify to see it in \(language.title).")
        }
    }

    /// Who is signed in, whether the phone is in step with the account, and
    /// signing out.
    private var accountCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Account") { EmptyView() }

            GroupedCard {
                HStack(alignment: .firstTextBaseline) {
                    Text("Signed in as")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    Text(auth.email ?? String(localized: "Apple ID"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(1)
                }
                .padding(.vertical, 14)
                .accessibilityElement(children: .combine)

                RowDivider()

                HStack(alignment: .center, spacing: 10) {
                    Circle()
                        .fill(syncColor)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if let detail = syncDetail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    Button {
                        Task { await sync.sync() }
                    } label: {
                        Text("Sync now")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.lime.readableForeground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.lime, in: .capsule)
                            // 44pt to tap without growing the row.
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                    .disabled(sync.status == .syncing)
                }
                .padding(.vertical, 6)
            }

            Button {
                prepareSignOut()
            } label: {
                Text("Sign out")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.surface, in: .capsule)
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(.pressable)
        }
    }

    private var syncColor: Color {
        switch sync.status {
        case .idle: Theme.green
        case .syncing: Theme.blue
        case .offline: Theme.yellow
        case .failed: Theme.red
        }
    }

    private var syncTitle: String {
        switch sync.status {
        case .syncing: String(localized: "Syncing…")
        case .offline: String(localized: "Offline")
        case .failed: String(localized: "Not synced")
        case .idle: sync.lastSyncedAt == nil ? String(localized: "Not synced yet") : String(localized: "Up to date")
        }
    }

    private var syncDetail: String? {
        if case .failed(let message) = sync.status { return message }
        if sync.status == .offline {
            return String(localized: "Changes are saved on this phone and sync when you're back online.")
        }
        guard let last = sync.lastSyncedAt else { return nil }
        let when = last.formatted(.relative(presentation: .named))
        return String(localized: "Last synced \(when)")
    }

    /// Currency and language. A language change needs a relaunch, so the row
    /// says so rather than looking broken until the user happens to restart.
    private var displayCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Display") { EmptyView() }

            GroupedCard {
                pickerRowLayout {
                    Text("Currency")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(SupportedCurrency.all) { currency in
                            Text("\(currency.symbol)  \(String(localized: currency.name))")
                                .tag(currency.code)
                        }
                    }
                    .labelsHidden()
                    .tint(Theme.textPrimary)
                }
                .padding(.vertical, 8)

                RowDivider()

                pickerRowLayout {
                    Text("Language")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    Picker("Language", selection: $language) {
                        ForEach(Language.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .tint(Theme.textPrimary)
                    .onChange(of: language) { _, newValue in
                        AppSettings.setLanguage(newValue)
                        isShowingRestartNote = true
                    }
                }
                .padding(.vertical, 8)
            }

            Text("Amounts change straight away. A new language applies when you reopen the app.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private var dataCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Your data") { EmptyView() }
            GroupedCard {
                infoRow("Income sources", "\(income.count)")
                RowDivider()
                infoRow("Expenses", "\(expenses.count)")
                RowDivider()
                infoRow("Debts", "\(debts.count)")
            }
        }
    }

    private var aboutCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "About") { EmptyView() }
            GroupedCard {
                infoRow("Version", appVersion)
                RowDivider()
                // Baseline-aligned: `.top` set the 14pt glyph visibly higher
                // than the first line of the footnote beside it.
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.lime)
                    Text("Your money data is kept in your Veralify account and synced over an encrypted connection. Scanned ID documents never leave this phone.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 14)
            }
        }
    }

    private var resetCard: some View {
        Button {
            isConfirmingReset = true
        } label: {
            Text("Delete all data and start over")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.red.opacity(0.13), in: .capsule)
        }
        .buttonStyle(.pressable)
        // Extra air above the one destructive control, so it reads as its own
        // area rather than as another row of About.
        .padding(.top, 8)
    }

    /// Removing the account itself: an App Store requirement for any app
    /// that lets people create one.
    private var deleteAccountCard: some View {
        Button {
            isConfirmingDeletion = true
        } label: {
            Text("Delete account")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .overlay(Capsule().strokeBorder(Theme.red.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }

    private func infoRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private func resetEverything() {
        // Every store the app owns. Leaving transactions or quest history
        // behind made "delete all data" a lie — the ledger and the day's
        // progress survived a reset that claimed to wipe everything.
        //
        // Synced records go with `deleteSynced`, so the deletions reach the
        // account too — otherwise the web, and the next phone, would still
        // show everything. The plan's settings are left on the server: setup
        // writes new ones over them.
        for item in income { context.deleteSynced(item) }
        for item in expenses { context.deleteSynced(item) }
        for item in debts { context.deleteSynced(item) }
        for item in settings { context.delete(item) }
        for item in transactions { context.deleteSynced(item) }
        for item in questCompletions { context.delete(item) }
        for item in payments { context.deleteSynced(item) }
        for item in snapshots { context.deleteSynced(item) }
        for item in familyMembers { context.delete(item) }
        for item in familyExpenses { context.delete(item) }
        for item in familySettlements { context.delete(item) }
        for item in documents { context.delete(item) }
        for item in budgets { context.deleteSynced(item) }
        for item in losses { context.deleteSynced(item) }
        for item in incomeActuals { context.deleteSynced(item) }
        try? context.save()
        Task { await sync.sync() }
        // Scheduled reminders outlive the rows they describe. Left queued, a
        // wiped vault still announced "your passport (number) expires" weeks
        // later, and bills for deleted debts kept arriving. Every notification
        // this app schedules is a money or document reminder, so all of them go.
        let notifications = UNUserNotificationCenter.current()
        notifications.removeAllPendingNotificationRequests()
        notifications.removeAllDeliveredNotifications()
        // Send the user back through setup so the app is never left in a state
        // with no income, no debts and no way to add the first one.
        hasCompletedOnboarding = false
        dismiss()
    }

    // MARK: - Leaving

    /// Syncs first, so as little as possible is left only on the phone, then
    /// asks — warning if anything still did not make it.
    private func prepareSignOut() {
        isLeaving = true
        Task {
            await sync.sync()
            isLeaving = false
            signOutPending = sync.pendingChangeCount()
        }
    }

    /// Signing out removes the synced data from the phone (it stays in the
    /// account) so the next person to sign in on it starts clean. Local-only
    /// data — the document vault, family splits, quests — has no other home,
    /// so it stays.
    private func signOut() {
        isLeaving = true
        Task {
            await sync.suspend()
            do {
                try sync.removeLocalCopy()
            } catch {
                sync.resume()
                isLeaving = false
                leaveError = String(localized: "The data on this phone could not be removed, so you're still signed in. Try again.")
                return
            }
            await LocalData.removeMoneyReminders()
            hasCompletedOnboarding = false
            await auth.signOut()
            isLeaving = false
            dismiss()
        }
    }

    /// Deletes the account on the server first; only once that has worked is
    /// the phone cleared. The other way round, a failed request would leave an
    /// empty phone and an account still full of data.
    private func deleteAccount() {
        isLeaving = true
        Task {
            await sync.suspend()
            do {
                try await auth.deleteAccountOnServer()
            } catch {
                sync.resume()
                isLeaving = false
                leaveError = error.localizedDescription
                return
            }
            try? LocalData.removeEverything(in: context)
            hasCompletedOnboarding = false
            await auth.forgetDeletedAccount()
            isLeaving = false
            dismiss()
        }
    }
}
