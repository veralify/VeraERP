import Foundation

/// One shared cost, with each participant's share already resolved.
public struct SharedExpense: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let amount: Decimal
    /// Who actually paid the whole thing.
    public let paidBy: UUID
    /// What each participant owes for it. Sums to `amount`.
    public let shares: [UUID: Decimal]

    public init(id: UUID, amount: Decimal, paidBy: UUID, shares: [UUID: Decimal]) {
        self.id = id
        self.amount = amount
        self.paidBy = paidBy
        self.shares = shares
    }
}

/// One person paying another to square up.
public struct Settlement: Hashable, Sendable, Identifiable {
    public let from: UUID
    public let to: UUID
    public let amount: Decimal

    public var id: String { "\(from)-\(to)" }

    public init(from: UUID, to: UUID, amount: Decimal) {
        self.from = from
        self.to = to
        self.amount = amount
    }
}

/// Splitting shared costs and working out who owes whom.
public enum FamilySplit {

    /// Divides `amount` evenly, to the cent, with the remainder spread one cent
    /// at a time over the first participants.
    ///
    /// The shares must add back up to the total exactly. Rounding each to
    /// `amount / count` leaves €10 split three ways at €9.99, and that missing
    /// cent turns into a balance nobody can ever settle.
    public static func equalShares(of amount: Decimal, among participants: [UUID]) -> [UUID: Decimal] {
        let shares = equalShares(of: amount, ways: participants.count)
        return Dictionary(uniqueKeysWithValues: zip(participants, shares))
    }

    /// Divides `amount` `count` ways, to the cent, in the order the shares are
    /// returned — the first few carry the extra cent.
    ///
    /// Splitting a bill between people who are only a number, not a named
    /// member, goes through here. Both callers share one implementation so a
    /// plain N-way split and a family split can never round differently.
    public static func equalShares(of amount: Decimal, ways count: Int) -> [Decimal] {
        guard count > 0 else { return [] }

        let cents = NSDecimalNumber(decimal: Money.rounded(amount) * 100).intValue
        let base = cents / count
        let remainder = abs(cents % count)

        return (0..<count).map { index in
            let extra = index < remainder ? (cents < 0 ? -1 : 1) : 0
            return Decimal(base + extra) / 100
        }
    }

    /// Net position per member: positive means the family owes them, negative
    /// means they owe the family.
    ///
    /// Paying for something lends that money to everyone else; owing a share
    /// borrows it. Someone's own share of what they paid cancels out.
    public static func balances(
        expenses: [SharedExpense],
        settlements: [Settlement] = []
    ) -> [UUID: Decimal] {
        var net: [UUID: Decimal] = [:]

        for expense in expenses {
            net[expense.paidBy, default: 0] += expense.amount
            for (member, share) in expense.shares {
                net[member, default: 0] -= share
            }
        }

        // A settlement is money that has already changed hands, so it cancels
        // the debt it was paying off.
        for settlement in settlements {
            net[settlement.from, default: 0] += settlement.amount
            net[settlement.to, default: 0] -= settlement.amount
        }

        return net.mapValues(Money.roundedAllowingNegative)
    }

    /// The payments that clear every balance, fewest transfers first.
    ///
    /// Greedy: the largest debtor pays the largest creditor as much as it takes
    /// to zero one of them, and repeat. That is not provably the minimum number
    /// of transfers — that problem is NP-hard — but it never needs more than
    /// one transfer per person, which is what matters at family scale.
    public static func settleUp(_ balances: [UUID: Decimal]) -> [Settlement] {
        let penny = Decimal(string: "0.01")!

        var creditors = balances.filter { $0.value > 0 }
            .map { (id: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
        var debtors = balances.filter { $0.value < 0 }
            .map { (id: $0.key, amount: -$0.value) }
            .sorted { $0.amount > $1.amount }

        var transfers: [Settlement] = []
        var creditorIndex = 0
        var debtorIndex = 0

        while creditorIndex < creditors.count && debtorIndex < debtors.count {
            let amount = min(creditors[creditorIndex].amount, debtors[debtorIndex].amount)

            if amount >= penny {
                transfers.append(
                    Settlement(
                        from: debtors[debtorIndex].id,
                        to: creditors[creditorIndex].id,
                        amount: Money.rounded(amount)
                    )
                )
            }

            creditors[creditorIndex].amount -= amount
            debtors[debtorIndex].amount -= amount

            if creditors[creditorIndex].amount < penny { creditorIndex += 1 }
            if debtors[debtorIndex].amount < penny { debtorIndex += 1 }
        }

        return transfers
    }
}

public extension Money {
    /// Two decimal places, keeping the sign. `Money.rounded` clamps negatives to
    /// zero to match the web app; a balance that can be owed either way cannot
    /// use that.
    static func roundedAllowingNegative(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }
}
