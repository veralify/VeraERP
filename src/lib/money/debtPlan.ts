/**
 * Debt payoff planner — ported from money-manager-web-mvp-v1's server.js
 * (`simulate` / `debtPlan`), which uses an Avalanche strategy: minimums are
 * paid first, then any remaining monthly budget goes to the highest-APR debt
 * (explicit `priority` breaks ties). The required monthly budget is found by
 * binary search over the smallest budget that clears every debt within
 * `targetMonths`. Logic is preserved exactly from the original — only the
 * types and the SQL aggregation (now done by the caller) changed.
 */

export type DebtRow = {
  id: string;
  name: string;
  balance: number;
  apr: number;
  minimum_payment: number;
  priority: number;
};

export type MonthSimResult = {
  start: number[];
  paid: number[];
  interest: number;
  remainingDebt: number;
};

function money(x: number): number {
  return Math.max(0, Math.round(x * 100) / 100);
}

export function simulateAvalanche(debts: DebtRow[], budget: number, months: number) {
  let balances = debts.map((d) => Number(d.balance));
  const schedule: MonthSimResult[] = [];
  for (let m = 0; m < months && balances.some((b) => b > 0.005); m++) {
    const start = balances.slice();
    let interest = 0;
    balances = balances.map((b, i) => {
      const x = (b * (Number(debts[i].apr) / 100)) / 12;
      interest += x;
      return b + x;
    });
    let remaining = budget;
    const paid = Array(debts.length).fill(0);
    // Minimums first, capped by remaining balance.
    debts.forEach((d, i) => {
      const p = Math.min(balances[i], Number(d.minimum_payment), remaining);
      paid[i] += p;
      balances[i] -= p;
      remaining -= p;
    });
    // Avalanche: highest APR first, explicit priority breaks ties.
    const order = [...debts.keys()].sort(
      (a, b) =>
        Number(debts[b].apr) - Number(debts[a].apr) ||
        Number(debts[a].priority) - Number(debts[b].priority),
    );
    for (const i of order) {
      if (remaining <= 0) break;
      const p = Math.min(balances[i], remaining);
      paid[i] += p;
      balances[i] -= p;
      remaining -= p;
    }
    schedule.push({ start, paid, interest, remainingDebt: balances.reduce((a, b) => a + b, 0) });
  }
  return { schedule, remaining: balances.reduce((a, b) => a + b, 0) };
}

function monthsBetween(start: string, n: number): Date[] {
  const d = new Date(`${start}T00:00:00`);
  return Array.from({ length: n }, (_, i) => {
    const x = new Date(d);
    x.setMonth(d.getMonth() + i);
    return new Date(x.getFullYear(), x.getMonth(), 1);
  });
}

export type DebtPlanInput = {
  income: number;
  expenses: number;
  debts: DebtRow[];
  targetMonths: number;
  startDate: string;
};

export type DebtPlanMonth = {
  month: string;
  payments: Record<string, number>;
  totalPayment: number;
  remainingDebt: number;
};

export type DebtPlanResult = {
  income: number;
  expenses: number;
  available: number;
  totalDebt: number;
  targetMonths: number;
  startDate: string;
  requiredMonthly: number;
  feasible: boolean;
  usedMonthly: number;
  projectedRemaining: number;
  months: DebtPlanMonth[];
};

/** Binary-searches the smallest monthly budget that clears all debts within `targetMonths`, then simulates the resulting schedule. */
export function computeDebtPlan({
  income,
  expenses,
  debts,
  targetMonths,
  startDate,
}: DebtPlanInput): DebtPlanResult {
  const min = debts.reduce((s, d) => s + Number(d.minimum_payment), 0);
  const available = Math.max(0, income - expenses);
  const total = debts.reduce((s, d) => s + Number(d.balance), 0);

  if (!debts.length) {
    return {
      income,
      expenses,
      available,
      totalDebt: 0,
      targetMonths,
      startDate,
      requiredMonthly: 0,
      feasible: true,
      usedMonthly: 0,
      projectedRemaining: 0,
      months: [],
    };
  }

  let lo = min;
  let hi = Math.max(
    min,
    available,
    total +
      debts.reduce(
        (s, d) => s + ((Number(d.balance) * Number(d.apr)) / 100 / 12) * targetMonths,
        0,
      ),
  );
  for (let i = 0; i < 50; i++) {
    const mid = (lo + hi) / 2;
    const sim = simulateAvalanche(debts, mid, targetMonths);
    if (sim.remaining <= 0.01) hi = mid;
    else lo = mid;
  }
  const budget = hi;
  const feasible = budget <= available + 0.01;
  const sim = simulateAvalanche(debts, feasible ? budget : available, targetMonths);
  const dates = monthsBetween(startDate, targetMonths);

  return {
    income,
    expenses,
    available,
    totalDebt: total,
    targetMonths,
    startDate,
    requiredMonthly: money(budget),
    feasible,
    usedMonthly: money(feasible ? budget : available),
    projectedRemaining: money(sim.remaining),
    months: dates.map((d, i) => ({
      month: d.toISOString().slice(0, 7),
      payments: Object.fromEntries(
        debts.map((x, j) => [x.name, money(sim.schedule[i]?.paid[j] || 0)]),
      ),
      totalPayment: money((sim.schedule[i]?.paid || []).reduce((a, b) => a + b, 0)),
      remainingDebt: money(sim.schedule[i]?.remainingDebt || 0),
    })),
  };
}

/** Local y/m/d formatting — avoids the UTC-shift bug `toISOString()` introduces east of UTC. */
function toLocalDateStr(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/** Next real calendar date a day-of-month bill falls on, clamped to the last day of short months (e.g. due_day=31 in February). */
export function nextOccurrence(dueDay: number | null, from: Date): Date | null {
  if (!dueDay) return null;
  const clampToMonth = (y: number, m: number, d: number) => {
    const lastDay = new Date(y, m + 1, 0).getDate();
    return new Date(y, m, Math.min(d, lastDay));
  };
  const y = from.getFullYear();
  const m = from.getMonth();
  let candidate = clampToMonth(y, m, dueDay);
  if (candidate < from) {
    const ny = m === 11 ? y + 1 : y;
    const nm = (m + 1) % 12;
    candidate = clampToMonth(ny, nm, dueDay);
  }
  return candidate;
}

export type UpcomingBill = {
  type: 'expense' | 'debt';
  id: string;
  name: string;
  amount: number;
  dueDate: string;
  daysUntil: number;
};

export function computeUpcomingBills(
  expenseRows: { id: string; name: string; amount: number; due_day: number | null }[],
  debtRows: { id: string; name: string; minimum_payment: number; due_day: number | null }[],
  days: number,
): { days: number; count: number; total: number; bills: UpcomingBill[] } {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const horizon = new Date(today);
  horizon.setDate(horizon.getDate() + days);
  const bills: UpcomingBill[] = [];
  for (const r of expenseRows) {
    const d = nextOccurrence(r.due_day, today);
    if (d && d <= horizon) {
      bills.push({
        type: 'expense',
        id: r.id,
        name: r.name,
        amount: money(Number(r.amount) || 0),
        dueDate: toLocalDateStr(d),
        daysUntil: Math.round((d.getTime() - today.getTime()) / 86400000),
      });
    }
  }
  for (const r of debtRows) {
    const d = nextOccurrence(r.due_day, today);
    if (d && d <= horizon && Number(r.minimum_payment) > 0) {
      bills.push({
        type: 'debt',
        id: r.id,
        name: r.name,
        amount: money(Number(r.minimum_payment) || 0),
        dueDate: toLocalDateStr(d),
        daysUntil: Math.round((d.getTime() - today.getTime()) / 86400000),
      });
    }
  }
  bills.sort((a, b) => a.daysUntil - b.daysUntil);
  return {
    days,
    count: bills.length,
    total: money(bills.reduce((s, b) => s + b.amount, 0)),
    bills,
  };
}
