// Generates payoff parity fixtures from the WEB implementation.
//
// `simulate()` and the bisection block below are copied VERBATIM from
// money-manager-web-mvp-v1/server.js (functions `simulate` and `debtPlan`),
// with only the SQLite reads replaced by function arguments. Do not "improve"
// them here — this file's whole value is that it is the web engine.
//
// ONE DELIBERATE DEVIATION, in the month label.
// server.js builds it with `d.toISOString().slice(0,7)` on a Date constructed
// at LOCAL midnight. East of UTC that rolls back a day, so `new Date(2026,8,1)`
// in Europe/Rome labels itself "2026-08" — every row in the web plan is tagged
// with the previous month. server.js already carries a `toLocalDateStr()`
// helper with a comment describing this exact trap; the plan mapping just does
// not use it.
// This file uses the local date parts instead, so the fixtures carry CORRECT
// labels and the Swift engine is pinned to correct behaviour rather than to the
// bug. Fix server.js, and the two agree with no change here.
//
// Refresh after any change to the web payoff logic:
//   node Tools/generate-parity-fixtures.mjs
//
// Output: MoneyManagerCore/Tests/MoneyManagerCoreTests/Fixtures/payoff-parity.json

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

// ---- verbatim from server.js ------------------------------------------------
function simulate(debts, budget, n) {
  let balances = debts.map(d => Number(d.balance));
  const schedule = [];
  for (let m = 0; m < n && balances.some(b => b > 0.005); m++) {
    const start = balances.slice();
    let interest = 0;
    balances = balances.map((b, i) => { const x = b * (Number(debts[i].apr) / 100 / 12); interest += x; return b + x; });
    let remaining = budget;
    const paid = Array(debts.length).fill(0);
    debts.forEach((d, i) => {
      const p = Math.min(balances[i], Number(d.minimum_payment), remaining);
      paid[i] += p; balances[i] -= p; remaining -= p;
    });
    const order = [...debts.keys()].sort((a, b) => (Number(debts[b].apr) - Number(debts[a].apr)) || (Number(debts[a].priority) - Number(debts[b].priority)));
    for (const i of order) {
      if (remaining <= 0) break;
      const p = Math.min(balances[i], remaining);
      paid[i] += p; balances[i] -= p; remaining -= p;
    }
    schedule.push({ start, paid, interest, remainingDebt: balances.reduce((a, b) => a + b, 0) });
  }
  return { schedule, remaining: balances.reduce((a, b) => a + b, 0) };
}

function money(x) { return Math.max(0, Math.round(x * 100) / 100) }

function monthsBetween(start, n) {
  const d = new Date(start + "T00:00:00");
  return Array.from({ length: n }, (_, i) => {
    const x = new Date(d); x.setMonth(d.getMonth() + i);
    return new Date(x.getFullYear(), x.getMonth(), 1);
  });
}

function debtPlan({ income, expenses, debts, target, start }) {
  const min = debts.reduce((s, d) => s + Number(d.minimum_payment), 0);
  const available = Math.max(0, income - expenses);
  const total = debts.reduce((s, d) => s + Number(d.balance), 0);
  let lo = min, hi = Math.max(min, available, total + debts.reduce((s, d) => s + Number(d.balance) * Number(d.apr) / 100 / 12 * target, 0));
  if (!debts.length) return { income, expenses, available, totalDebt: 0, targetMonths: target, startDate: start, budget: 0, feasible: true, schedule: [] };
  for (let i = 0; i < 50; i++) { const mid = (lo + hi) / 2; const sim = simulate(debts, mid, target); if (sim.remaining <= 0.01) hi = mid; else lo = mid; }
  const budget = hi;
  const feasible = budget <= available + 0.01;
  const sim = simulate(debts, feasible ? budget : available, target);
  const dates = monthsBetween(start, target);
  return {
    income, expenses, available, totalDebt: total, targetMonths: target, startDate: start,
    requiredMonthly: money(budget), feasible, usedMonthly: money(feasible ? budget : available),
    projectedRemaining: money(sim.remaining),
    months: dates.map((d, i) => ({
      month: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`,
      payments: Object.fromEntries(debts.map((x, j) => [String(x.id), money(sim.schedule[i]?.paid[j] || 0)])),
      totalPayment: money((sim.schedule[i]?.paid || []).reduce((a, b) => a + b, 0)),
      interestAccrued: money(sim.schedule[i]?.interest || 0),
      remainingDebt: money(sim.schedule[i]?.remainingDebt || 0)
    }))
  };
}
// ---- end verbatim -----------------------------------------------------------

const scenarios = [
  {
    name: "seeded",
    note: "The data the web app ships with: a 0% court debt, an 11.49% loan, a 0% loan.",
    income: 1600, expenses: 1194, target: 16, start: "2026-09-01",
    debts: [
      { id: 1, name: "Court", balance: 3000, apr: 0, minimum_payment: 500, priority: 1 },
      { id: 2, name: "Intesa", balance: 6491.72, apr: 11.49, minimum_payment: 177.98, priority: 2 },
      { id: 3, name: "UniCredit", balance: 5851.53, apr: 0, minimum_payment: 315.75, priority: 3 }
    ]
  },
  {
    name: "single-zero-apr",
    note: "Simplest possible plan: one interest-free debt, comfortably affordable.",
    income: 2000, expenses: 500, target: 12, start: "2026-01-01",
    debts: [{ id: 1, name: "Loan", balance: 1200, apr: 0, minimum_payment: 100, priority: 1 }]
  },
  {
    name: "apr-tie-priority-breaks",
    note: "Two debts at an identical APR — `priority` must decide who gets the surplus.",
    income: 3000, expenses: 1000, target: 10, start: "2026-03-01",
    debts: [
      { id: 1, name: "CardA", balance: 2000, apr: 19.9, minimum_payment: 50, priority: 5 },
      { id: 2, name: "CardB", balance: 2000, apr: 19.9, minimum_payment: 50, priority: 1 }
    ]
  },
  {
    name: "infeasible",
    note: "Required budget exceeds available income; plan runs at `available` and leaves a residue.",
    income: 1200, expenses: 1100, target: 6, start: "2026-05-01",
    debts: [
      { id: 1, name: "BigLoan", balance: 20000, apr: 15, minimum_payment: 400, priority: 1 },
      { id: 2, name: "Card", balance: 5000, apr: 24.99, minimum_payment: 150, priority: 2 }
    ]
  },
  {
    name: "high-apr-long-term",
    note: "Compounding-sensitive: high rates over a long term, where float drift would show.",
    income: 5000, expenses: 1500, target: 36, start: "2026-02-01",
    debts: [
      { id: 1, name: "Card1", balance: 8500.33, apr: 24.99, minimum_payment: 210.5, priority: 1 },
      { id: 2, name: "Card2", balance: 3200.67, apr: 18.25, minimum_payment: 95.25, priority: 2 },
      { id: 3, name: "Car", balance: 14750.1, apr: 6.75, minimum_payment: 320, priority: 3 }
    ]
  },
  {
    name: "minimums-exceed-budget",
    note: "Minimums alone outrun what is available, so later debts get nothing that month.",
    income: 1000, expenses: 900, target: 8, start: "2026-07-01",
    debts: [
      { id: 1, name: "One", balance: 4000, apr: 12, minimum_payment: 300, priority: 1 },
      { id: 2, name: "Two", balance: 4000, apr: 22, minimum_payment: 300, priority: 2 }
    ]
  }
];

const fixtures = scenarios.map(s => ({
  name: s.name,
  note: s.note,
  input: { income: s.income, expenses: s.expenses, targetMonths: s.target, startDate: s.start, debts: s.debts },
  expected: debtPlan({ income: s.income, expenses: s.expenses, debts: s.debts, target: s.target, start: s.start })
}));

const out = join(here, "..", "MoneyManagerCore", "Tests", "MoneyManagerCoreTests", "Fixtures", "payoff-parity.json");
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify({ generatedBy: "Tools/generate-parity-fixtures.mjs", source: "money-manager-web-mvp-v1/server.js", scenarios: fixtures }, null, 2));
console.log(`wrote ${fixtures.length} scenarios to ${out}`);
for (const f of fixtures) {
  console.log(`  ${f.name.padEnd(26)} required=${f.expected.requiredMonthly} feasible=${f.expected.feasible} remaining=${f.expected.projectedRemaining}`);
}
