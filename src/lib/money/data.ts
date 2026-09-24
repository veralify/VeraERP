import type { createSupabaseServerClient } from '@lib/supabase/server';
import type { DebtPlanInput } from './debtPlan';

type SupabaseClient = Awaited<ReturnType<typeof createSupabaseServerClient>>;

/**
 * Shared base-data fetch for the Overview and Debts pages, which both need
 * income/expenses/debts/savings/settings — this is the single source for
 * those queries so the two pages can't drift on column lists or aggregation.
 */
export async function getMoneySnapshot(supabase: SupabaseClient, userId: string) {
  // Synced tables are soft-deleted (a phone delete must reach the web and vice
  // versa), so every read skips tombstones. money_savings has no sync columns.
  const [
    { data: incomeRows },
    { data: expenseRows },
    { data: debtRows },
    { data: savingsRows },
    { data: settingsRows },
  ] = await Promise.all([
    supabase
      .from('money_income')
      .select('id, name, amount, type, payday, active')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false }),
    supabase
      .from('money_expenses')
      .select('id, name, amount, category, due_day, active')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false }),
    supabase
      .from('money_debts')
      .select('id, name, balance, apr, minimum_payment, due_day, priority')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('priority', { ascending: true }),
    supabase
      .from('money_savings')
      .select('id, name, amount, target_amount, monthly_contribution, category, active')
      .eq('user_id', userId)
      .order('created_at', { ascending: false }),
    supabase
      .from('money_settings')
      .select('key, value')
      .eq('user_id', userId)
      .is('deleted_at', null),
  ]);

  const income = incomeRows ?? [];
  const expenses = expenseRows ?? [];
  const debts = debtRows ?? [];
  const savings = savingsRows ?? [];
  const settings = Object.fromEntries((settingsRows ?? []).map((r) => [r.key, r.value]));

  const activeIncome = income.filter((r) => r.active);
  const activeExpenses = expenses.filter((r) => r.active);
  const activeSavings = savings.filter((r) => r.active);

  const monthlyIncome = activeIncome.reduce((s, r) => s + Number(r.amount), 0);
  const monthlyExpenses = activeExpenses.reduce((s, r) => s + Number(r.amount), 0);
  const totalDebt = debts.reduce((s, r) => s + Number(r.balance), 0);
  const debtMinPayments = debts.reduce((s, r) => s + Number(r.minimum_payment), 0);
  const savingsContribution = activeSavings.reduce((s, r) => s + Number(r.monthly_contribution), 0);
  const netCashFlow = monthlyIncome - monthlyExpenses - debtMinPayments - savingsContribution;

  // Guard against settings rows saved before validation existed: an invalid date would
  // make the payoff table throw, and an unbounded horizon renders thousands of rows.
  const storedMonths = Math.trunc(Number(settings.targetMonths));
  const targetMonths = storedMonths >= 1 ? Math.min(storedMonths, 120) : 12;
  const startDate = /^\d{4}-\d{2}-\d{2}$/.test(settings.startDate ?? '')
    ? settings.startDate
    : new Date().toISOString().slice(0, 10);

  return {
    income,
    expenses,
    debts,
    savings,
    activeIncome,
    activeExpenses,
    activeSavings,
    monthlyIncome,
    monthlyExpenses,
    totalDebt,
    debtMinPayments,
    savingsContribution,
    netCashFlow,
    targetMonths,
    startDate,
  };
}

export type MoneySnapshot = Awaited<ReturnType<typeof getMoneySnapshot>>;

export function getDebtPlanInput(snapshot: MoneySnapshot): DebtPlanInput {
  return {
    income: snapshot.monthlyIncome,
    expenses: snapshot.monthlyExpenses,
    debts: snapshot.debts,
    targetMonths: snapshot.targetMonths,
    startDate: snapshot.startDate,
  };
}
