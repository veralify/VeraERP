import UIKit
import VeralifyCore

/// The seven layouts added alongside the original three.
///
/// Each one answers a different question, which is why they are not one layout
/// with switches in it: a tracker is for ticking, a report is for reading, a
/// statement is for a lender, and a ledger is for a filing cabinet.
extension PlanPDF {

    private var remainingSeries: [Decimal] { steps.map(\.remainingDebt) }
    private var keptSeries: [Decimal] { steps.map(\.cumulativeBalance) }

    // MARK: - Dashboard

    /// Everything on one page: the four figures, both curves, and a compact
    /// schedule underneath. The one to send when someone asks "so what's the
    /// plan" and will not read a second page.
    func drawDashboard(from top: CGFloat, context: UIGraphicsPDFRendererContext) {
        var y = drawStats(at: top)

        let chartHeight: CGFloat = 96
        areaChart(
            in: CGRect(x: margin, y: y, width: usable, height: chartHeight),
            values: remainingSeries,
            colour: ink,
            title: String(localized: "WHAT YOU STILL OWE"),
            caption: CurrencyFormat.string(plan.totalDebt)
        )
        y += chartHeight + 16

        areaChart(
            in: CGRect(x: margin, y: y, width: usable, height: chartHeight),
            values: keptSeries,
            colour: accent.secondary,
            title: String(localized: "WHAT YOU KEEP"),
            caption: CurrencyFormat.string(steps.last?.cumulativeBalance ?? 0)
        )
        y += chartHeight + 22

        text(String(localized: "MILESTONES"), at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 8.5, weight: .bold))
        y += 16

        for step in steps where step.isMilestone {
            guard y + 18 < page.height - footerSpace else { break }
            let name = step.isFinish
                ? String(localized: "Debt free")
                : step.clearedDebts.joined(separator: ", ")
            text(JourneyStep.title(for: step.month), at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 8, weight: .semibold))
            // Bounded so several debts cleared in one month stop short of the
            // figure at the end of the line rather than printing over it.
            text(name, in: CGRect(x: margin + 110, y: y, width: usable - 110 - 96, height: 12),
                 font: .systemFont(ofSize: 8), colour: ink)
            text(CurrencyFormat.string(step.cumulativeBalance),
                 in: CGRect(x: page.width - margin - 90, y: y, width: 90, height: 12),
                 font: .monospacedDigitSystemFont(ofSize: 8, weight: .semibold), alignment: .right)
            y += 18
        }

        // A dashboard that stops two-thirds up the page reads as unfinished,
        // and "which debts" is the question the curves above leave open.
        y += 18
        let barsHeight = min(CGFloat(24 + summary.perDebt.count * 26), page.height - footerSpace - y)
        if barsHeight > 60 {
            debtBars(
                in: CGRect(x: margin, y: y, width: usable, height: barsHeight),
                title: String(localized: "WHAT EACH DEBT COSTS")
            )
        }
    }

    // MARK: - Report

    /// The plan written out, with the charts that support each claim. For
    /// sending to someone who needs the reasoning, not the rows.
    func drawReport(from top: CGFloat, context: UIGraphicsPDFRendererContext) {
        var y = top

        let finish = summary.finishMonth.map { JourneyStep.title(for: $0) }
            ?? String(localized: "beyond this plan")
        let opening = String(
            localized: "Clearing \(CurrencyFormat.string(plan.totalDebt)) takes \(steps.count) months at \(CurrencyFormat.string(plan.requiredMonthly)) a month, finishing in \(finish). The borrowing itself costs \(CurrencyFormat.string(summary.totalInterest)), which is \(Int((summary.interestShare * 100).rounded()))% of everything handed over."
        )
        y = paragraph(opening, at: y, width: usable)
        y += 14

        let ringSize: CGFloat = 110
        interestRing(in: CGRect(x: margin, y: y, width: ringSize, height: ringSize))

        let facts: [(String, String)] = [
            (String(localized: "Principal"), CurrencyFormat.string(summary.principalPaid)),
            (String(localized: "Interest"), CurrencyFormat.string(summary.totalInterest)),
            (String(localized: "Total paid"), CurrencyFormat.string(summary.totalPaid)),
            (String(localized: "Kept by the end"), CurrencyFormat.string(steps.last?.cumulativeBalance ?? 0))
        ]
        for (index, fact) in facts.enumerated() {
            let row = y + 14 + CGFloat(index) * 22
            text(fact.0, at: CGPoint(x: margin + ringSize + 20, y: row),
                 font: .systemFont(ofSize: 8), colour: secondaryInk)
            text(fact.1, in: CGRect(x: page.width - margin - 110, y: row, width: 110, height: 12),
                 font: .monospacedDigitSystemFont(ofSize: 9, weight: .bold), alignment: .right)
        }
        y += ringSize + 18

        debtBars(
            in: CGRect(x: margin, y: y, width: usable, height: 0),
            title: String(localized: "WHAT EACH DEBT COSTS")
        )
        y += 18 + CGFloat(summary.perDebt.count) * 26 + 6
        legendRow(at: CGPoint(x: margin, y: y), items: [
            (String(localized: "Borrowed"), ink),
            (String(localized: "Interest"), accent.secondary)
        ])
        y += 24

        if y + 110 > page.height - footerSpace {
            startPage(context)
            y = margin
        }

        areaChart(
            in: CGRect(x: margin, y: y, width: usable, height: 100),
            values: remainingSeries,
            colour: ink,
            title: String(localized: "THE BALANCE, MONTH BY MONTH")
        )
    }

    // MARK: - Timeline

    /// The route drawn as a road, the way the app shows it.
    func drawTimeline(from top: CGFloat, context: UIGraphicsPDFRendererContext) {
        var y = top
        let rail = margin + 9

        for step in steps {
            if y + 34 > page.height - footerSpace {
                startPage(context)
                y = margin
            }

            // The rail is drawn per row rather than once per page, so it stops
            // exactly where the last stop of that page does.
            if step.index > 0 {
                let line = UIBezierPath()
                line.move(to: CGPoint(x: rail, y: y - 10))
                line.addLine(to: CGPoint(x: rail, y: y + 6))
                UIColor(white: 0.82, alpha: 1).setStroke()
                line.lineWidth = 1
                line.stroke()
            }

            let node = UIBezierPath(ovalIn: CGRect(x: rail - 4, y: y + 3, width: 8, height: 8))
            (step.isMilestone ? ink : UIColor(white: 0.78, alpha: 1)).setFill()
            node.fill()

            text(JourneyStep.title(for: step.month), at: CGPoint(x: rail + 16, y: y),
                 font: .systemFont(ofSize: 9, weight: step.isMilestone ? .bold : .semibold))
            text(
                String(localized: "\(CurrencyFormat.string(step.payment)) paid · \(CurrencyFormat.string(step.isFinish ? 0 : step.remainingDebt)) left · \(CurrencyFormat.string(step.cumulativeBalance)) in hand"),
                at: CGPoint(x: rail + 16, y: y + 12),
                font: .systemFont(ofSize: 7.5), colour: secondaryInk
            )

            if !step.clearedDebts.isEmpty || step.isFinish {
                let name = step.isFinish
                    ? String(localized: "Debt free")
                    : step.clearedDebts.joined(separator: ", ")
                badge(name, at: CGPoint(x: page.width - margin - 92, y: y + 1), width: 92)
            }

            y += 34
        }
    }

    // MARK: - Charts

    /// Nothing but the analytics, each given the full width it needs.
    func drawCharts(from top: CGFloat, context: UIGraphicsPDFRendererContext) {
        var y = top

        areaChart(
            in: CGRect(x: margin, y: y, width: usable, height: 150),
            values: remainingSeries,
            colour: ink,
            title: String(localized: "WHAT YOU STILL OWE"),
            caption: CurrencyFormat.string(plan.totalDebt)
        )
        y += 168

        areaChart(
            in: CGRect(x: margin, y: y, width: usable, height: 150),
            values: keptSeries,
            colour: accent.secondary,
            title: String(localized: "WHAT YOU KEEP"),
            caption: CurrencyFormat.string(steps.last?.cumulativeBalance ?? 0)
        )
        y += 168

        interestRing(in: CGRect(x: margin, y: y, width: 120, height: 120))
        debtBars(
            in: CGRect(x: margin + 140, y: y, width: usable - 140, height: 0),
            title: String(localized: "WHAT EACH DEBT COSTS")
        )
        y += max(120, 18 + CGFloat(summary.perDebt.count) * 26) + 8
        legendRow(at: CGPoint(x: margin + 140, y: y), items: [
            (String(localized: "Borrowed"), ink),
            (String(localized: "Interest"), accent.secondary)
        ])
    }

    // MARK: - Ledger

    /// Small type, tight rows, as many months to a page as will fit legibly.
    func drawLedger(from top: CGFloat, context: UIGraphicsPDFRendererContext) {
        let columns: [(String, CGFloat)] = [
            (String(localized: "Month"), 52), (String(localized: "Payment"), 58),
            (String(localized: "Interest"), 48), (String(localized: "Principal"), 56),
            (String(localized: "Balance"), 62), (String(localized: "In hand"), 58),
            (String(localized: "Cleared"), 130)
        ]

        func header(at y: CGFloat) -> CGFloat {
            var x = margin
            for column in columns {
                text(column.0, in: CGRect(x: x, y: y, width: column.1 - 3, height: 10),
                     font: .systemFont(ofSize: 6.5, weight: .bold), colour: secondaryInk)
                x += column.1
            }
            rule(y: y + 11)
            return y + 16
        }

        var y = header(at: top)
        var previous = plan.totalDebt

        for step in steps {
            if y + 14 > page.height - footerSpace {
                startPage(context)
                y = header(at: margin)
            }

            var x = margin
            let values = [
                step.month,
                CurrencyFormat.string(step.payment),
                CurrencyFormat.string(step.interest),
                CurrencyFormat.string(previous - step.remainingDebt),
                CurrencyFormat.string(step.isFinish ? 0 : step.remainingDebt),
                CurrencyFormat.string(step.cumulativeBalance),
                step.isFinish
                    ? String(localized: "Debt free")
                    : step.clearedDebts.joined(separator: ", ")
            ]
            for (value, column) in zip(values, columns) {
                text(value, in: CGRect(x: x, y: y, width: column.1 - 3, height: 11),
                     font: .monospacedDigitSystemFont(ofSize: 7, weight: step.isMilestone ? .semibold : .regular),
                     colour: step.isMilestone ? ink : primaryInk)
                x += column.1
            }
            previous = step.remainingDebt
            y += 14
        }
    }

    // MARK: - Calendar

    /// The plan as a wall calendar: one cell per month, four to a row.
    func drawCalendar(from top: CGFloat, context: UIGraphicsPDFRendererContext) {
        let perRow = 4
        let gap: CGFloat = 8
        let width = (usable - gap * CGFloat(perRow - 1)) / CGFloat(perRow)
        let height: CGFloat = 78

        var y = top
        var column = 0

        for step in steps {
            if y + height > page.height - footerSpace {
                startPage(context)
                y = margin
                column = 0
            }

            let box = CGRect(x: margin + (width + gap) * CGFloat(column), y: y, width: width, height: height)
            panel(box, fill: step.isMilestone ? accent.wash : nil)

            text(shortMonthLabel(step.month), at: CGPoint(x: box.minX + 8, y: box.minY + 8),
                 font: .systemFont(ofSize: 9, weight: .bold))
            text(CurrencyFormat.string(step.payment), at: CGPoint(x: box.minX + 8, y: box.minY + 24),
                 font: .monospacedDigitSystemFont(ofSize: 11, weight: .heavy), colour: ink)
            text(String(localized: "paid"), at: CGPoint(x: box.minX + 8, y: box.minY + 38),
                 font: .systemFont(ofSize: 6.5), colour: tertiaryInk)

            progressBar(
                at: CGRect(x: box.minX + 8, y: box.minY + 52, width: box.width - 16, height: 4),
                fraction: step.progress
            )
            text(
                String(localized: "\(CurrencyFormat.string(step.isFinish ? 0 : step.remainingDebt)) left"),
                at: CGPoint(x: box.minX + 8, y: box.minY + 60),
                font: .systemFont(ofSize: 6.5), colour: secondaryInk
            )

            column += 1
            if column == perRow {
                column = 0
                y += height + gap
            }
        }
    }

    // MARK: - Statement

    /// One section per debt, each with its own schedule. The layout a lender
    /// asks for, because a lender only cares about their own loan.
    func drawStatement(from top: CGFloat, context: UIGraphicsPDFRendererContext) {
        var y = top

        for debt in summary.perDebt {
            if y + 90 > page.height - footerSpace {
                startPage(context)
                y = margin
            }

            let head = CGRect(x: margin, y: y, width: usable, height: 46)
            panel(head, fill: accent.wash)
            text(debt.name, at: CGPoint(x: head.minX + 12, y: head.minY + 10),
                 font: .systemFont(ofSize: 12, weight: .bold))

            let cleared = debt.clearedMonth.map { JourneyStep.title(for: $0) }
                ?? String(localized: "Not cleared in this plan")
            text(String(localized: "Settled \(cleared)"),
                 at: CGPoint(x: head.minX + 12, y: head.minY + 27),
                 font: .systemFont(ofSize: 7.5), colour: secondaryInk)

            let facts: [(String, String)] = [
                (String(localized: "Total paid"), CurrencyFormat.string(debt.paid)),
                (String(localized: "Of which interest"), CurrencyFormat.string(debt.interest))
            ]
            for (index, fact) in facts.enumerated() {
                let x = head.maxX - 210 + CGFloat(index) * 105
                text(fact.0, at: CGPoint(x: x, y: head.minY + 10),
                     font: .systemFont(ofSize: 6.5), colour: secondaryInk)
                text(fact.1, at: CGPoint(x: x, y: head.minY + 22),
                     font: .monospacedDigitSystemFont(ofSize: 10, weight: .bold),
                     colour: index == 1 ? ink : primaryInk)
            }
            y += 54

            // Three unlabelled money columns is a puzzle, not a statement.
            text(String(localized: "PERIOD"), at: CGPoint(x: margin + 12, y: y),
                 font: .systemFont(ofSize: 6, weight: .bold), colour: tertiaryInk)
            text(String(localized: "PAID"),
                 in: CGRect(x: margin + 90, y: y, width: 80, height: 9),
                 font: .systemFont(ofSize: 6, weight: .bold), colour: tertiaryInk,
                 alignment: .right)
            text(String(localized: "REMAINING"),
                 in: CGRect(x: page.width - margin - 90, y: y, width: 90, height: 9),
                 font: .systemFont(ofSize: 6, weight: .bold), colour: tertiaryInk,
                 alignment: .right)
            y += 11
            rule(y: y - 2)
            y += 4

            // Per-debt figures live on the engine's own months, not on the
            // roadmap steps, which only carry the totals.
            let byMonth = Dictionary(
                plan.months.map { ($0.month, $0) }, uniquingKeysWith: { first, _ in first }
            )

            for step in steps {
                guard let month = byMonth[step.month] else { continue }
                let paid = month.payments[debt.id] ?? 0
                guard paid > 0 else { continue }

                if y + 13 > page.height - footerSpace {
                    startPage(context)
                    y = margin
                }

                text(step.month, at: CGPoint(x: margin + 12, y: y), font: .systemFont(ofSize: 7.5))
                text(CurrencyFormat.string(paid),
                     in: CGRect(x: margin + 90, y: y, width: 80, height: 11),
                     font: .monospacedDigitSystemFont(ofSize: 7.5, weight: .regular), alignment: .right)
                text(CurrencyFormat.string(month.remainingByDebt[debt.id] ?? 0),
                     in: CGRect(x: page.width - margin - 90, y: y, width: 90, height: 11),
                     font: .monospacedDigitSystemFont(ofSize: 7.5, weight: .regular),
                     colour: secondaryInk, alignment: .right)
                y += 13
            }
            y += 18
        }
    }

    // MARK: - Helpers

    /// Wraps a block of text and reports where it ended.
    private func paragraph(_ value: String, at y: CGFloat, width: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2.5
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: primaryInk,
            .paragraphStyle: style
        ]
        let bounds = (value as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        (value as NSString).draw(
            with: CGRect(x: margin, y: y, width: width, height: bounds.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return y + bounds.height
    }

    private func shortMonthLabel(_ month: String) -> String {
        let pieces = month.split(separator: "-")
        guard pieces.count == 2, let year = Int(pieces[0]), let number = Int(pieces[1]),
              let date = Calendar.current.date(from: DateComponents(year: year, month: number))
        else { return month }
        return date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
    }
}
