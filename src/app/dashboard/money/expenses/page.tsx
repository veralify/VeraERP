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
import { formatMoney } from '@lib/money/format';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { Receipt } from 'lucide-react';
import type { Metadata } from 'next';
import { addExpenseAction, deleteExpenseAction, updateExpenseAction } from '../actions/expenses';

export const metadata: Metadata = { title: 'Expenses · Money' };
type SearchParams = Promise<{ error?: string; saved?: string }>;

const CATEGORY_OPTIONS = ['Fixed', 'Living', 'Family', 'Debt / installment', 'Other'];

export default async function ExpensesPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: rows } = await supabase
    .from('money_expenses')
    .select('id, name, amount, category, due_day, active')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });
  const expenses = rows ?? [];

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Expenses"
        body="Recurring monthly costs — rent, subscriptions, family transfers, anything fixed."
      />
      <ErrorMessage message={params.error ? 'Enter a name and a valid amount.' : undefined} />

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">Your expenses</h2>
            {expenses.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {expenses.map((row) => (
                  <StaggerItem
                    key={row.id}
                    as="div"
                    className="flex items-center justify-between gap-3 py-4"
                  >
                    <div>
                      <p className="font-semibold">{row.name}</p>
                      <p className="text-sm text-vera-fg-muted">
                        {row.category}
                        {row.due_day ? ` · due day ${row.due_day}` : ''}
                        {row.active ? '' : ' · inactive'}
                      </p>
                    </div>
                    <div className="flex items-center gap-3">
                      <p className="text-lg font-bold">{formatMoney(Number(row.amount))}</p>
                      <RowActions
                        id={row.id}
                        itemLabel={row.name}
                        editTitle="Edit expense"
                        updateAction={updateExpenseAction}
                        deleteAction={deleteExpenseAction}
                      >
                        <Field label="Name">
                          <input
                            className={inputClass}
                            name="name"
                            required
                            defaultValue={row.name}
                          />
                        </Field>
                        <Field label="Monthly amount">
                          <input
                            className={inputClass}
                            name="amount"
                            type="number"
                            min="0"
                            step="0.01"
                            required
                            defaultValue={row.amount}
                          />
                        </Field>
                        <Field label="Category">
                          <select
                            className={inputClass}
                            name="category"
                            defaultValue={row.category}
                          >
                            {CATEGORY_OPTIONS.map((c) => (
                              <option key={c} value={c}>
                                {c}
                              </option>
                            ))}
                          </select>
                        </Field>
                        <Field label="Due day (1-31, optional)">
                          <input
                            className={inputClass}
                            name="due_day"
                            type="number"
                            min="1"
                            max="31"
                            defaultValue={row.due_day ?? ''}
                          />
                        </Field>
                        <label className="flex items-center gap-2 text-sm font-medium">
                          <input
                            type="checkbox"
                            name="active"
                            value="true"
                            defaultChecked={row.active}
                            className="h-4 w-4 rounded border-vera-border"
                          />
                          Active
                        </label>
                      </RowActions>
                    </div>
                  </StaggerItem>
                ))}
              </StaggerGroup>
            ) : (
              <EmptyState
                icon={<Receipt className="h-6 w-6" strokeWidth={1.75} />}
                title="No expenses yet"
                body="Add your recurring monthly costs to see an accurate available budget."
              />
            )}
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.05}>
          <form
            action={addExpenseAction}
            className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
          >
            <h2 className="text-xl font-bold">Add expense</h2>
            <Field label="Name">
              <input className={inputClass} name="name" required placeholder="Rent" />
            </Field>
            <Field label="Monthly amount">
              <input
                className={inputClass}
                name="amount"
                type="number"
                min="0"
                step="0.01"
                required
              />
            </Field>
            <Field label="Category">
              <select className={inputClass} name="category" defaultValue="Fixed">
                {CATEGORY_OPTIONS.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Due day (1-31, optional)">
              <input className={inputClass} name="due_day" type="number" min="1" max="31" />
            </Field>
            <SubmitButton>Add expense</SubmitButton>
          </form>
        </Reveal>
      </div>
    </main>
  );
}
