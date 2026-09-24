import SwiftUI
import SwiftData
import VeralifyCore

/// Shared household costs: who paid, how it splits, and who owes whom.
///
/// Content only: the title, the nav bar and the Add button belong to
/// `MainTabView`, which presents the add sheets from the floating bar.
///
/// Kept apart from the payoff plan on purpose. These are one-off events between
/// people; `ExpenseItem` is the recurring commitment the plan is built on, and
/// mixing them would count the same money twice.
struct FamilyView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FamilyMember.createdAt) private var members: [FamilyMember]
    @Query(sort: \FamilyExpense.date, order: .reverse) private var expenses: [FamilyExpense]
    @Query private var settlements: [FamilySettlement]

    @State private var sheet: Sheet?

    private enum Sheet: Identifiable {
        case addMember
        /// Owned here rather than by the tab bar's Add button: the add for a
        /// list belongs on the list, and a button that means something
        /// different on every tab means nothing on any of them.
        case addExpense
        case settle(Settlement)

        var id: String {
            switch self {
            case .addMember:          "member"
            case .addExpense:         "expense"
            case .settle(let value):  "settle-\(value.id)"
            }
        }
    }

    private var me: FamilyMember? { members.first(where: \.isMe) ?? members.first }

    private var balances: [UUID: Decimal] {
        FamilySplit.balances(
            expenses: expenses.map(\.asSharedExpense),
            settlements: settlements.map(\.asSettlement)
        )
    }

    private var transfers: [Settlement] { FamilySplit.settleUp(balances) }

    /// What the household spent this month, and this user's share of it.
    private var thisMonth: (total: Decimal, mine: Decimal) {
        let start = MonthlySnapshot.monthStart(for: .now)
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? .distantFuture
        let current = expenses.filter { $0.date >= start && $0.date < end }
        let total = current.reduce(Decimal(0)) { $0 + $1.amount }
        let mine = me.map { person in
            current.reduce(Decimal(0)) { $0 + ($1.asSharedExpense.shares[person.id] ?? 0) }
        } ?? 0
        return (total, mine)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if members.isEmpty {
                setupPrompt
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        summaryCard
                        quickSplitLink
                        memberStrip
                        if !transfers.isEmpty { settleSection }
                        expenseSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    // Clear the floating bar.
                    .padding(.bottom, 108)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .addMember:
                FamilyMemberSheet(existingCount: members.count, isFirst: members.isEmpty)
                    .presentationBackground(Theme.background)
            case .addExpense:
                FamilyExpenseSheet(members: members, me: me)
                    .presentationBackground(Theme.background)
            case .settle(let transfer):
                SettleUpSheet(transfer: transfer, members: members)
                    .presentationBackground(Theme.background)
            }
        }
    }

    // MARK: - Empty state

    /// Centred when it fits, scrolling when it does not: at the largest text
    /// sizes on a small phone the message, button and link run past the screen,
    /// and a non-scrolling stack would push the link out of reach.
    private var setupPrompt: some View {
        ViewThatFits(in: .vertical) {
            setupPromptContent
            ScrollView {
                setupPromptContent
            }
            .scrollIndicators(.hidden)
        }
    }

    private var setupPromptContent: some View {
        VStack(spacing: 18) {
            EmptyStateView(
                icon: "person.2.fill",
                title: "Share costs with your family",
                message: "Add the people you split money with. Log what each of you pays and the app works out who owes whom."
            )
            PrimaryButton(title: "Add the first person", enabled: true) {
                sheet = .addMember
            }
            quickSplitLink
        }
        .padding(.horizontal, 24)
        // The floating bar covers the bottom of the screen, so the prompt is
        // centred in what is left above it rather than behind it.
        .padding(.bottom, 108)
    }

    /// A one-off bill split, for a table of people who are not household
    /// members and do not need to be added as any.
    private var quickSplitLink: some View {
        NavigationLink(value: SplitRoute()) {
            HStack(spacing: 12) {
                Image(systemName: "divide.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.lime)
                    .frame(width: 34, height: 34)
                    .background(Theme.lime.opacity(0.16), in: .rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Split a bill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    // Two lines rather than one shrunk line: the Arabic and
                    // larger text sizes cut it off mid-sentence.
                    Text("Work out the tip and who owes what, then send it")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let month = thisMonth
        return VStack(alignment: .leading, spacing: 10) {
            // The eyebrow belongs to the figure, as on `AccentCard`; the gap
            // then separates the figure from its caption.
            VStack(alignment: .leading, spacing: 2) {
                Text("This month")
                    .font(.caption.weight(.bold))
                    .kerning(0.5)
                    .foregroundStyle(Theme.onAccent.opacity(0.7))

                Text(CurrencyFormat.string(month.total))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(Theme.onAccent)
            }

            Text("\(CurrencyFormat.string(month.mine)) of it is your share")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.onAccent.opacity(0.78))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.blue, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private var memberStrip: some View {
        let net = balances
        return ScrollView(.horizontal) {
            // Top-aligned: the Add tile has one line of text under its circle
            // where a member has two, and centring it dropped its circle below
            // the row of avatars.
            HStack(alignment: .top, spacing: 10) {
                ForEach(members) { member in
                    let owed = net[member.id] ?? 0
                    VStack(spacing: 6) {
                        Text(member.emoji)
                            .font(.system(size: 22))
                            .frame(width: 46, height: 46)
                            .background(member.color.opacity(0.2), in: .circle)
                            .overlay(Circle().strokeBorder(member.color.opacity(0.7), lineWidth: 1.5))

                        Text(member.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        // The tile is a fixed 80pt; a four-figure balance
                        // shrinks to fit rather than losing its last digits.
                        Text(balanceLabel(owed))
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(
                                owed == 0 ? Theme.textTertiary : (owed > 0 ? Theme.green : Theme.red)
                            )
                    }
                    .frame(width: 80)
                    .accessibilityElement(children: .combine)
                }

                Button { sheet = .addMember } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 46, height: 46)
                            .background(Theme.surfaceElevated, in: .circle)
                            .overlay(
                                Circle().strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            )
                        Text("Add")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(width: 80)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Add someone")
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func balanceLabel(_ amount: Decimal) -> String {
        if amount == 0 { return String(localized: "settled") }
        let sign = amount > 0 ? "+" : "−"
        return sign + CurrencyFormat.string(abs(amount))
    }

    // MARK: - Settling up

    private var settleSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Settle up") {
                Text("\(transfers.count)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            GroupedCard {
                ForEach(Array(transfers.enumerated()), id: \.element.id) { index, transfer in
                    if index > 0 { RowDivider() }
                    Button {
                        sheet = .settle(transfer)
                    } label: {
                        HStack(spacing: 10) {
                            Text(name(of: transfer.from))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            // Mirrored under right-to-left, where the payer
                            // sits on the right: unflipped, the arrow pointed
                            // back at them.
                            Image(systemName: "arrow.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.textTertiary)
                                .flipsForRightToLeftLayoutDirection(true)
                            Text(name(of: transfer.to))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Spacer(minLength: 8)

                            // The amount is the point of the row, so long
                            // names give way before it does.
                            Text(CurrencyFormat.string(transfer.amount))
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .layoutPriority(1)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.textTertiary)
                                .flipsForRightToLeftLayoutDirection(true)
                        }
                        .padding(.vertical, 14)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: - Expenses

    private var expenseSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Shared expenses") {
                // Deliberately quiet, and named for what it adds. The lime
                // capsule in the tab bar is the app's one primary action; a
                // second lime "Add" on the same screen would put us straight
                // back to a button whose meaning depends on where you tapped.
                Button { sheet = .addExpense } label: {
                    Label("Add expense", systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceElevated, in: .capsule)
                        // The capsule is ~28pt tall. The hit area grows to
                        // 44pt without the header row growing with it.
                        .contentShape(Rectangle().inset(by: -8))
                }
                .buttonStyle(.pressable)
            }

            if expenses.isEmpty {
                Text("Nothing shared yet. Add an expense and it splits between whoever you pick.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else {
                GroupedCard {
                    ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                        if index > 0 { RowDivider() }
                        expenseRow(expense)
                    }
                }
            }
        }
    }

    private func expenseRow(_ expense: FamilyExpense) -> some View {
        let payer = members.first { $0.id == expense.paidByID }
        let myShare = me.flatMap { expense.asSharedExpense.shares[$0.id] }

        return HStack(spacing: 12) {
            Image(systemName: FamilyCategory.icon(for: expense.category))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(payer?.color ?? Theme.textSecondary)
                .frame(width: 34, height: 34)
                .background((payer?.color ?? Theme.textSecondary).opacity(0.16), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(payer?.name ?? String(localized: "Someone")) paid · \(expense.date.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // A long title truncates; the amounts never do.
            VStack(alignment: .trailing, spacing: 3) {
                Text(CurrencyFormat.string(expense.amount))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let myShare, myShare > 0 {
                    Text("you \(CurrencyFormat.string(myShare))")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)
        }
        .padding(.vertical, 12)
        .contextMenu {
            Button(role: .destructive) {
                context.delete(expense)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func name(of id: UUID) -> String {
        members.first { $0.id == id }?.name ?? String(localized: "Someone")
    }
}
