import SwiftUI
import SwiftData
import VeralifyCore

/// Navigation value for the full plan, pushed from the board.
struct WholePlanRoute: Hashable {}

/// The month's money as circles you can move.
///
/// A table of debts tells you the numbers; it does not tell you the shape of
/// the month. Here the biggest circle is the biggest commitment, and the lime
/// one is what is still yours — so "most of my money goes to UniCredit" is
/// something you see rather than something you work out.
///
/// It is also the one screen where the plan is editable by hand. Dragging the
/// leftover onto a debt commits more of the month to it; dragging a debt onto
/// the leftover takes it back. Everything else about the plan is a consequence
/// of those two moves.
struct BubbleBoardView: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Which bubble is under the finger, and how far it has come.
    @State private var drag: Drag?
    /// The bubble the dragged one is currently over.
    @State private var target: Bubble.ID?
    /// The move waiting to be confirmed.
    @State private var transfer: Transfer?
    /// The bubble that was tapped, which the stack pushes for.
    @State private var opened: Bubble?
    @State private var isAdding = false
    @State private var bumped = 0
    /// Bubbles the user has placed by hand, as fractions of the board so the
    /// arrangement survives a rotation or a different screen.
    @AppStorage("boardPositions") private var storedPositions = "{}"
    /// Drives the idle float. Flipped once, then the repeating animation on
    /// each bubble carries it.
    @State private var isFloating = false

    private struct Drag {
        let id: Bubble.ID
        var translation: CGSize
    }

    /// A move the user has asked for but not yet committed.
    struct Transfer: Identifiable {
        let debt: DebtRecord
        /// Money going to the debt. Negative takes it back.
        let toward: Bool
        let ceiling: Decimal
        var id: Int { debt.remoteID }
    }

    // MARK: - Arrangement

    private var customPositions: [Int: CGPoint] {
        guard let data = storedPositions.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String: [Double]].self, from: data)
        else { return [:] }

        return raw.reduce(into: [:]) { result, pair in
            guard let id = Int(pair.key), pair.value.count == 2 else { return }
            result[id] = CGPoint(x: pair.value[0], y: pair.value[1])
        }
    }

    private func remember(_ id: Int, at point: CGPoint) {
        var all = customPositions
        all[id] = point

        let raw = all.reduce(into: [String: [Double]]()) { result, pair in
            result["\(pair.key)"] = [pair.value.x, pair.value.y]
        }
        guard let data = try? JSONEncoder().encode(raw),
              let text = String(data: data, encoding: .utf8)
        else { return }
        storedPositions = text
    }

    // MARK: - Contents

    /// What the board draws. One case per kind because they behave differently
    /// under a finger, not because they look different.
    enum Bubble: Identifiable, Hashable {
        case leftover(Decimal)
        case expenses(Decimal)
        case debt(id: Int, name: String, amount: Decimal, colourIndex: Int)
        /// The empty circle that makes another one. It carries a weight only so
        /// the packing can place it; the figure is never drawn.
        case add(weight: Decimal)

        static let addID = -3

        var id: Int {
            switch self {
            case .leftover: -1
            case .expenses: -2
            case .add:      Self.addID
            case .debt(let id, _, _, _): id
            }
        }

        var amount: Decimal {
            switch self {
            case .leftover(let value), .expenses(let value), .add(let value): value
            case .debt(_, _, let amount, _): amount
            }
        }

        var isDebt: Bool { if case .debt = self { true } else { false } }
        var isAdd: Bool { if case .add = self { true } else { false } }
    }

    @MainActor
    private func bubbles() -> (list: [Bubble], summary: DashboardSummary) {
        let summary = DashboardSummary(
            income: income, expenses: expenses, debts: debts, settings: settings.first
        )

        var list: [Bubble] = debts.enumerated().map { index, debt in
            .debt(
                id: debt.remoteID,
                name: debt.name,
                amount: debt.monthlyPayment,
                colourIndex: index
            )
        }
        if summary.totalExpenses > 0 { list.append(.expenses(summary.totalExpenses)) }
        if summary.netCashFlow > 0 { list.append(.leftover(summary.netCashFlow)) }

        // Sized off the middle of the set, not the smallest of it. Tied to the
        // smallest it came out as a speck beside a €500 debt and read as a
        // stray dot; at the median it is plainly one of the circles, and still
        // never the biggest thing on a board that is supposed to be about the
        // money. On an empty board there is no median, so it takes the canvas.
        let amounts = list.map(\.amount).sorted()
        let median = amounts.isEmpty
            ? 1
            : amounts[amounts.count / 2]
        list.append(.add(weight: median))
        return (list, summary)
    }

    var body: some View {
        let content = bubbles()

        return ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header(content.summary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                GeometryReader { geometry in
                    board(content.list, in: geometry.size)
                }

                hint(content.summary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 96)
            }
            .padding(.top, 4)
        }
        .navigationDestination(item: $opened) { bubble in
            switch bubble {
            case .debt(let id, _, _, _): DebtDetailView(remoteID: id)
            case .expenses:              EntryListView(kind: .expense)
            case .leftover:              CashFlowView(scope: .month)
            case .add:                   EmptyView()
            }
        }
        .sheet(isPresented: $isAdding) {
            EntryFormSheet(mode: .add(nil))
                .presentationDetents([.fraction(0.92)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Theme.background)
        }
        .sheet(item: $transfer) { move in
            AllocateSheet(debt: move.debt, toward: move.toward, ceiling: move.ceiling)
                .presentationDetents([.height(540)])
                .presentationBackground(Theme.background)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: target)
        .sensoryFeedback(.success, trigger: bumped)
    }

    // MARK: - Header

    private func header(_ summary: DashboardSummary) -> some View {
        NavigationLink(value: WholePlanRoute()) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Left to pay")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                    Text(CurrencyFormat.string(summary.plan.totalDebt))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text("Whole plan")
                        .font(.footnote.weight(.bold))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(Theme.lime)
            }
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.pressableRow)
    }

    private func hint(_ summary: DashboardSummary) -> some View {
        Text(
            summary.netCashFlow > 0
                ? "Drag the leftover circle onto a debt to pay more of it each month. Drag a debt back onto it to take the extra off again."
                : "Nothing is left over this month, so there is nothing to move. Tap a circle to open it, or + to add one."
        )
        .font(.caption)
        .foregroundStyle(Theme.textTertiary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    // MARK: - The board

    @ViewBuilder
    private func board(_ list: [Bubble], in size: CGSize) -> some View {
        if list.isEmpty {
            EmptyStateView(
                icon: "circle.grid.2x2",
                title: "Nothing to show yet",
                message: "Add what comes in and what you owe, and the month appears here as circles."
            )
            .padding(.horizontal, 24)
        } else {
            let placements = BubblePacking.layout(
                items: list.map { .init(id: $0.id, weight: $0.amount) },
                size: (width: size.width, height: size.height),
                // The one circle that is not money sits where a floating
                // action sits, out of the way of the circles that are.
                anchored: anchors()
            )
            let byID = Dictionary(
                placements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
            )

            ZStack {
                ForEach(list) { bubble in
                    if let spot = byID[bubble.id] {
                        circle(bubble, spot: spot, all: placements, list: list)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    /// Where bubbles must go rather than where the packing would put them:
    /// anything the user has dragged, and the add button's corner until they
    /// move it themselves.
    private func anchors() -> [Int: (x: Double, y: Double)] {
        var result = customPositions.reduce(into: [Int: (x: Double, y: Double)]()) {
            $0[$1.key] = (x: $1.value.x, y: $1.value.y)
        }
        if result[Bubble.addID] == nil {
            result[Bubble.addID] = (x: 0.84, y: 0.86)
        }
        return result
    }

    private func circle(
        _ bubble: Bubble,
        spot: BubblePacking.Placement,
        all: [BubblePacking.Placement],
        list: [Bubble]
    ) -> some View {
        let isDragging = drag?.id == bubble.id
        let offset = isDragging ? (drag?.translation ?? .zero) : .zero
        let isTarget = target == bubble.id

        // The target swells and the circle in flight shrinks, so the drop
        // reads as one bubble being taken into the other rather than as two
        // circles bumping. The pair is animated together for that to hold.
        let isSwallowing = drag != nil && isTarget

        return BubbleCircle(
            bubble: bubble,
            diameter: spot.radius * 2,
            isLifted: isDragging,
            isTarget: isTarget
        )
        .scaleEffect(isSwallowing ? 1.22 : isDragging && target != nil ? 0.74 : 1)
        .position(x: spot.x, y: spot.y)
        .offset(offset)
        .zIndex(isDragging ? 2 : isTarget ? 1 : 0)
        .animation(
            reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.35),
            value: isSwallowing
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: target != nil)
        .gesture(gesture(for: bubble, spot: spot, all: all, list: list))
        .onTapGesture {
            if bubble.isAdd { isAdding = true } else { opened = bubble }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Moving money

    private func gesture(
        for bubble: Bubble,
        spot: BubblePacking.Placement,
        all: [BubblePacking.Placement],
        list: [Bubble]
    ) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard canDrag(bubble) else { return }
                drag = Drag(id: bubble.id, translation: value.translation)
                target = partner(
                    for: bubble,
                    at: CGPoint(
                        x: spot.x + value.translation.width,
                        y: spot.y + value.translation.height
                    ),
                    all: all,
                    list: list
                )
            }
            .onEnded { _ in
                defer {
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.25)) {
                        drag = nil
                    }
                    target = nil
                }
                guard canDrag(bubble), let landed = target else { return }
                propose(from: bubble, to: landed, list: list)
            }
    }

    /// Only money that is actually movable moves: the leftover, and a debt
    /// giving some back.
    private func canDrag(_ bubble: Bubble) -> Bool {
        switch bubble {
        case .leftover(let spare): spare > 0
        case .expenses, .add:      false
        case .debt:                true
        }
    }

    /// The bubble whose circle the dragged one now sits inside.
    private func partner(
        for bubble: Bubble,
        at point: CGPoint,
        all: [BubblePacking.Placement],
        list: [Bubble]
    ) -> Bubble.ID? {
        let candidates = all.filter { placement in
            guard placement.id != bubble.id,
                  let other = list.first(where: { $0.id == placement.id })
            else { return false }
            // Leftover pairs with debts and debts pair with the leftover.
            // Nothing pairs with the expenses, which are not the plan's to move.
            guard !other.isAdd else { return false }
            return bubble.isDebt ? other.id == -1 : other.isDebt
        }

        return candidates
            .map { ($0.id, hypot($0.x - point.x, $0.y - point.y) - $0.radius) }
            .filter { $0.1 < 24 }
            .min { $0.1 < $1.1 }?.0
    }

    private func propose(from bubble: Bubble, to landed: Bubble.ID, list: [Bubble]) {
        let debtID = bubble.isDebt ? bubble.id : landed
        guard let record = debts.first(where: { $0.remoteID == debtID }) else { return }

        let summary = DashboardSummary(
            income: income, expenses: expenses, debts: debts, settings: settings.first
        )

        if bubble.isDebt {
            // Only the part you chose to add can be taken back. The minimum is
            // what the lender requires, and a slider is not the place to stop
            // meeting it.
            transfer = Transfer(
                debt: record,
                toward: false,
                ceiling: max(record.extraPayment, 0)
            )
        } else {
            transfer = Transfer(debt: record, toward: true, ceiling: max(summary.netCashFlow, 0))
        }
        bumped += 1
    }

}
