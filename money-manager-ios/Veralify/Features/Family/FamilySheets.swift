import SwiftUI
import SwiftData
import VeralifyCore

/// Adding somebody to share costs with.
struct FamilyMemberSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existingCount: Int
    /// The first person added is the account holder.
    let isFirst: Bool

    @State private var name = ""
    @State private var emoji = "🙂"

    private let emojis = ["🙂", "👩", "👨", "🧒", "👵", "👴", "🐱", "🐶", "⭐️", "🌙"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 14) {
                            FieldRow(
                                label: "Name",
                                placeholder: "Name",
                                text: $name
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Picture")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                                    ForEach(emojis, id: \.self) { option in
                                        Button { emoji = option } label: {
                                            Text(option)
                                                .font(.system(size: 22))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(
                                                    emoji == option ? Theme.lime.opacity(0.22) : Theme.surfaceElevated,
                                                    in: .rect(cornerRadius: 12)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .strokeBorder(
                                                            emoji == option ? Theme.lime : .clear,
                                                            lineWidth: 1.5
                                                        )
                                                )
                                        }
                                        .buttonStyle(.pressable)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                        if isFirst {
                            Text("This first person is you. Add the others afterwards.")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        PrimaryButton(
                            title: "Save",
                            enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                            action: save
                        )
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle(isFirst ? "About you" : "Add someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        context.insert(
            FamilyMember(
                name: trimmed,
                colorIndex: existingCount,
                emoji: emoji,
                isMe: isFirst
            )
        )
        try? context.save()
        dismiss()
    }
}

/// Logging a shared cost: what it was, who paid, and who it splits between.
struct FamilyExpenseSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let members: [FamilyMember]
    let me: FamilyMember?

    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date.now
    @State private var category = "General"
    @State private var paidByID: UUID?
    @State private var participantIDs: Set<UUID> = []

    private var parsedAmount: Decimal? { AmountParser.parse(amount) }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && (parsedAmount ?? 0) > 0
            && paidByID != nil
            && !participantIDs.isEmpty
    }

    /// The preview of what each person ends up owing, so an odd split is visible
    /// before it is committed rather than after.
    private var shares: [UUID: Decimal] {
        guard let value = parsedAmount, value > 0 else { return [:] }
        let ordered = members.filter { participantIDs.contains($0.id) }.map(\.id)
        return FamilySplit.equalShares(of: value, among: ordered)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        detailsCard
                        payerCard
                        splitCard
                        PrimaryButton(title: "Save", enabled: canSave, action: save)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle("Shared expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .onAppear {
                // Default to the common case: you paid, everyone shares.
                paidByID = paidByID ?? me?.id ?? members.first?.id
                if participantIDs.isEmpty { participantIDs = Set(members.map(\.id)) }
            }
        }
    }

    private var detailsCard: some View {
        VStack(spacing: 14) {
            FieldRow(label: "What was it?", placeholder: "Groceries", text: $title)
            FieldRow(
                label: "Amount",
                placeholder: "0.00",
                text: $amount,
                keyboard: .decimalPad
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(FamilyCategory.all, id: \.self) { option in
                        Button { category = option } label: {
                            Label {
                                Text(FamilyCategory.title(for: option))
                                    .font(.caption.weight(.bold))
                            } icon: {
                                Image(systemName: FamilyCategory.icon(for: option))
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(category == option ? Theme.onAccent : Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(category == option ? Theme.lime : Theme.surfaceElevated, in: .capsule)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()

            DateField(label: "Date", date: $date)
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private var payerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Who paid?")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(members) { member in
                        Button { paidByID = member.id } label: {
                            HStack(spacing: 6) {
                                Text(member.emoji).font(.caption)
                                Text(member.name)
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(paidByID == member.id ? Theme.onAccent : Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                paidByID == member.id ? member.color : Theme.surfaceElevated,
                                in: .capsule
                            )
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private var splitCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Split between")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                Button(participantIDs.count == members.count ? "None" : "Everyone") {
                    participantIDs = participantIDs.count == members.count ? [] : Set(members.map(\.id))
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.lime)
            }

            ForEach(members) { member in
                Button {
                    if participantIDs.contains(member.id) {
                        participantIDs.remove(member.id)
                    } else {
                        participantIDs.insert(member.id)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: participantIDs.contains(member.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(participantIDs.contains(member.id) ? Theme.lime : Theme.textTertiary)

                        Text(member.emoji).font(.subheadline)
                        Text(member.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)

                        Spacer(minLength: 8)

                        if let share = shares[member.id] {
                            Text(CurrencyFormat.string(share))
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 9)
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private func save() {
        guard let value = parsedAmount, value > 0, let payer = paidByID, !participantIDs.isEmpty
        else { return }

        context.insert(
            FamilyExpense(
                title: title.trimmingCharacters(in: .whitespaces),
                amount: value,
                date: date,
                category: category,
                paidByID: payer,
                participantIDs: members.filter { participantIDs.contains($0.id) }.map(\.id)
            )
        )
        try? context.save()
        dismiss()
    }
}

/// Recording that one person actually paid another back.
struct SettleUpSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let transfer: Settlement
    let members: [FamilyMember]

    @State private var amount: String

    init(transfer: Settlement, members: [FamilyMember]) {
        self.transfer = transfer
        self.members = members
        _amount = State(initialValue: transfer.amount.editableText)
    }

    private var parsedAmount: Decimal? { AmountParser.parse(amount) }

    private func name(of id: UUID) -> String {
        members.first { $0.id == id }?.name ?? String(localized: "Someone")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(name(of: transfer.from)) pays \(name(of: transfer.to))")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Theme.onAccent)
                            Text("Recording this clears what they owe.")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.onAccent.opacity(0.75))
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.green, in: .rect(cornerRadius: Theme.Radius.card))

                        VStack(spacing: 14) {
                            FieldRow(
                                label: "Amount",
                                placeholder: "0.00",
                                text: $amount,
                                keyboard: .decimalPad
                            )
                            Text("Change it if they paid back only part of it.")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                        PrimaryButton(title: "Record it", enabled: (parsedAmount ?? 0) > 0, action: save)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle("Settle up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func save() {
        guard let value = parsedAmount, value > 0 else { return }
        context.insert(
            FamilySettlement(fromID: transfer.from, toID: transfer.to, amount: value)
        )
        try? context.save()
        dismiss()
    }
}
