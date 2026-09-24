import { Banner } from '@components/generic/Banner';
import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { RowActions } from '@components/generic/RowActions';
import {
  Card,
  ErrorMessage,
  Field,
  inputClass,
  PageHeader,
  SubmitButton,
} from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { BudgetMeter } from '@components/money/BudgetMeter';
import { CategorySelect } from '@components/money/CategorySelect';
import { MonthPicker } from '@components/money/MonthPicker';
import { formatCurrency } from '@lib/money/format';
import {
  fetchAllTransactions,
  getBudgets,
  getCustomCategoryNames,
  getHomeCurrency,
} from '@lib/money/queries';
import {
  budgetProgress,
  categoryLabel,
  categoryOptions,
  currentMonth,
  monthBounds,
  monthLabel,
  parseMonth,
} from '@lib/money/spending';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { Target } from 'lucide-react';
import type { Metadata } from 'next';
import { addBudgetAction, deleteBudgetAction, updateBudgetAction } from '../actions/budgets';

export const metadata: Metadata = { title: 'Budgets · Money' };
type SearchParams = Promise<{ month?: string; error?: string; saved?: string; removed?: string }>;

const ERRORS: Record<string, string> = {
  invalid: 'Choose a category and enter a limit above zero with a three-letter currency code.',
  duplicate: 'That category already has a budget. Edit the existing one instead.',
  save: 'We couldn’t save that change. Please try again.',
};

export default async function BudgetsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const thisMonth = currentMonth();
  const requested = parseMonth(params.month, thisMonth);
  const month = requested > thisMonth ? thisMonth : requested;

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { start, end } = monthBounds(month);
  const [budgets, home, customNames, transactions] = await Promise.all([
    getBudgets(supabase, user.id),
    getHomeCurrency(supabase, user.id),
    getCustomCategoryNames(supabase, user.id),
    fetchAllTransactions(
      supabase,
      user.id,
      { from: start, to: end },
      { category: null, scope: null, direction: 'expense' },
    ),
  ]);

  const progress = budgetProgress(budgets, transactions.rows, home);
  const budgeted = new Set(budgets.map((b) => b.category_key));
  const options = categoryOptions(customNames);
  const available = options.filter((o) => !budgeted.has(o.key));
  const monthName = monthLabel(month);

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Budgets"
        body="A monthly limit per category. Budgets you set here sync to the Veralify app, and changes on your phone show up here."
        action={
          <MonthPicker basePath="/dashboard/money/budgets" month={month} maxMonth={thisMonth} />
        }
      />
      <div className="grid gap-3">
        <ErrorMessage message={params.error ? (ERRORS[params.error] ?? ERRORS.save) : undefined} />
        <Banner
          variant="success"
          message={params.saved ? 'Budget saved.' : params.removed ? 'Budget removed.' : undefined}
        />
        <Banner
          variant="warning"
          message={
            transactions.error || transactions.truncated
              ? 'Some of this month’s spending couldn’t be loaded, so progress may be understated.'
              : undefined
          }
        />
      </div>

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">Progress in {monthName}</h2>
            <p className="mt-1 text-sm text-vera-fg-muted">
              Expenses in each budget’s currency. Spending in other currencies counts once it has a{' '}
              {home} amount.
            </p>
            {progress.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {progress.map((p) => {
                  const label = categoryLabel(p.key, customNames);
                  return (
                    <StaggerItem key={p.id} as="div" className="flex items-start gap-3 py-4">
                      <div className="min-w-0 flex-1">
                        <BudgetMeter
                          label={label}
                          state={p.state}
                          ratio={p.ratio}
                          spentText={formatCurrency(p.spent, p.currency)}
                          limitText={formatCurrency(p.limit, p.currency)}
                          remainingText={
                            p.remaining >= 0
                              ? `${formatCurrency(p.remaining, p.currency)} left`
                              : `${formatCurrency(-p.remaining, p.currency)} over`
                          }
                        />
                      </div>
                      <RowActions
                        id={p.id}
                        itemLabel={`${label} budget`}
                        editTitle={`Edit ${label} budget`}
                        updateAction={updateBudgetAction}
                        deleteAction={deleteBudgetAction}
                      >
                        <input type="hidden" name="month" value={month} />
                        <Field label="Monthly limit">
                          <input
                            className={inputClass}
                            name="monthly_limit"
                            type="number"
                            min="0.01"
                            step="0.01"
                            required
                            defaultValue={p.limit}
                          />
                        </Field>
                        <Field label="Currency">
                          <input
                            className={`${inputClass} uppercase`}
                            name="currency"
                            required
                            maxLength={3}
                            pattern="[A-Za-z]{3}"
                            defaultValue={p.currency}
                          />
                        </Field>
                      </RowActions>
                    </StaggerItem>
                  );
                })}
              </StaggerGroup>
            ) : (
              <EmptyState
                icon={<Target className="h-6 w-6" strokeWidth={1.75} />}
                title="No budgets yet"
                body="Pick a category and a monthly limit to see how much is left as you spend."
              />
            )}
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.05}>
          {available.length ? (
            <form
              action={addBudgetAction}
              className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
            >
              <h2 className="text-xl font-bold">Add budget</h2>
              <input type="hidden" name="month" value={month} />
              <Field label="Category">
                <CategorySelect options={available} defaultValue={available[0].key} />
              </Field>
              <Field label="Monthly limit">
                <input
                  className={inputClass}
                  name="monthly_limit"
                  type="number"
                  min="0.01"
                  step="0.01"
                  required
                  placeholder="300"
                />
              </Field>
              <Field label="Currency">
                <input
                  className={`${inputClass} uppercase`}
                  name="currency"
                  required
                  maxLength={3}
                  pattern="[A-Za-z]{3}"
                  defaultValue={home}
                />
              </Field>
              <SubmitButton>Add budget</SubmitButton>
            </form>
          ) : (
            <Card>
              <h2 className="text-xl font-bold">Every category has a budget</h2>
              <p className="mt-2 text-sm text-vera-fg-muted">
                Edit a limit from the list, or remove a budget to set a new one.
              </p>
            </Card>
          )}
        </Reveal>
      </div>
    </main>
  );
}
