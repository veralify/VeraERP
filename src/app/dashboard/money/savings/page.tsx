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
import { PiggyBank } from 'lucide-react';
import type { Metadata } from 'next';
import { addSavingAction, deleteSavingAction, updateSavingAction } from '../actions/savings';

export const metadata: Metadata = { title: 'Savings · Money' };
type SearchParams = Promise<{ error?: string; saved?: string }>;

export default async function SavingsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: rows } = await supabase
    .from('money_savings')
    .select('id, name, amount, target_amount, monthly_contribution, category, active')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });
  const savings = rows ?? [];

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Savings goals"
        body="Track progress toward a target and how much of your monthly budget it takes."
      />
      <ErrorMessage message={params.error ? 'Enter a name for the savings goal.' : undefined} />

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">Your savings goals</h2>
            {savings.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {savings.map((row) => {
                  const progress = row.target_amount
                    ? Math.min(100, (Number(row.amount) / Number(row.target_amount)) * 100)
                    : 0;
                  return (
                    <StaggerItem key={row.id} as="div" className="py-4">
                      <div className="flex items-center justify-between gap-3">
                        <div>
                          <p className="font-semibold">
                            {row.name}
                            {row.active ? '' : ' · inactive'}
                          </p>
                          <p className="text-sm text-vera-fg-muted">
                            {row.category} · {formatMoney(Number(row.monthly_contribution))}/mo
                          </p>
                        </div>
                        <div className="flex items-center gap-3">
                          <p className="text-sm font-semibold">
                            {formatMoney(Number(row.amount))} /{' '}
                            {formatMoney(Number(row.target_amount))}
                          </p>
                          <RowActions
                            id={row.id}
                            itemLabel={row.name}
                            editTitle="Edit savings goal"
                            updateAction={updateSavingAction}
                            deleteAction={deleteSavingAction}
                          >
                            <Field label="Name">
                              <input
                                className={inputClass}
                                name="name"
                                required
                                defaultValue={row.name}
                              />
                            </Field>
                            <Field label="Current amount">
                              <input
                                className={inputClass}
                                name="amount"
                                type="number"
                                min="0"
                                step="0.01"
                                defaultValue={row.amount}
                              />
                            </Field>
                            <Field label="Target amount">
                              <input
                                className={inputClass}
                                name="target_amount"
                                type="number"
                                min="0"
                                step="0.01"
                                defaultValue={row.target_amount}
                              />
                            </Field>
                            <Field label="Monthly contribution">
                              <input
                                className={inputClass}
                                name="monthly_contribution"
                                type="number"
                                min="0"
                                step="0.01"
                                defaultValue={row.monthly_contribution}
                              />
                            </Field>
                            <Field label="Category">
                              <input
                                className={inputClass}
                                name="category"
                                defaultValue={row.category}
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
                      </div>
                      {row.target_amount ? (
                        <div className="mt-3 h-2 overflow-hidden rounded-full bg-vera-bg-subtle">
                          <div
                            className="h-full rounded-full bg-vera-primary transition-[width] duration-500"
                            style={{ width: `${progress}%` }}
                          />
                        </div>
                      ) : null}
                    </StaggerItem>
                  );
                })}
              </StaggerGroup>
            ) : (
              <EmptyState
                icon={<PiggyBank className="h-6 w-6" strokeWidth={1.75} />}
                title="No savings goals yet"
                body="Add a goal to track progress and factor it into your monthly cash flow."
              />
            )}
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.05}>
          <form
            action={addSavingAction}
            className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
          >
            <h2 className="text-xl font-bold">Add savings goal</h2>
            <Field label="Name">
              <input className={inputClass} name="name" required placeholder="Emergency fund" />
            </Field>
            <Field label="Current amount">
              <input
                className={inputClass}
                name="amount"
                type="number"
                min="0"
                step="0.01"
                defaultValue={0}
              />
            </Field>
            <Field label="Target amount">
              <input
                className={inputClass}
                name="target_amount"
                type="number"
                min="0"
                step="0.01"
                defaultValue={0}
              />
            </Field>
            <Field label="Monthly contribution">
              <input
                className={inputClass}
                name="monthly_contribution"
                type="number"
                min="0"
                step="0.01"
                defaultValue={0}
              />
            </Field>
            <Field label="Category">
              <input className={inputClass} name="category" defaultValue="General" />
            </Field>
            <SubmitButton>Add savings goal</SubmitButton>
          </form>
        </Reveal>
      </div>
    </main>
  );
}
