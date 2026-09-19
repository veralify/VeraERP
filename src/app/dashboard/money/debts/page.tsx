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
import { getDebtPlanInput, getMoneySnapshot } from '@lib/money/data';
import { computeDebtPlan } from '@lib/money/debtPlan';
import { formatMoney } from '@lib/money/format';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { CreditCard } from 'lucide-react';
import type { Metadata } from 'next';
import {
  addDebtAction,
  deleteDebtAction,
  updateDebtAction,
  updatePlanSettingsAction,
} from '../actions/debts';

export const metadata: Metadata = { title: 'Debts · Money' };
type SearchParams = Promise<{ error?: string; saved?: string }>;

export default async function DebtsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const snapshot = await getMoneySnapshot(supabase, user.id);
  const { debts, targetMonths, startDate } = snapshot;
  const plan = computeDebtPlan(getDebtPlanInput(snapshot));

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Debts & payoff plan"
        body="Avalanche strategy: minimums are covered first, then every extra unit goes to the highest-APR debt."
      />
      <ErrorMessage message={params.error ? 'Enter a name and a valid balance.' : undefined} />

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="space-y-6">
          <Reveal variants={fadeUp}>
            <Card>
              <h2 className="text-xl font-bold">Your debts</h2>
              {debts.length ? (
                <StaggerGroup className="mt-4 divide-y divide-vera-border">
                  {debts.map((row) => (
                    <StaggerItem
                      key={row.id}
                      as="div"
                      className="flex items-center justify-between gap-3 py-4"
                    >
                      <div>
                        <p className="font-semibold">{row.name}</p>
                        <p className="text-sm text-vera-fg-muted">
                          {row.apr}% APR · min {formatMoney(Number(row.minimum_payment))}
                          {row.due_day ? ` · due day ${row.due_day}` : ''}
                        </p>
                      </div>
                      <div className="flex items-center gap-3">
                        <p className="text-lg font-bold">{formatMoney(Number(row.balance))}</p>
                        <RowActions
                          id={row.id}
                          itemLabel={row.name}
                          editTitle="Edit debt"
                          updateAction={updateDebtAction}
                          deleteAction={deleteDebtAction}
                        >
                          <Field label="Name">
                            <input
                              className={inputClass}
                              name="name"
                              required
                              defaultValue={row.name}
                            />
                          </Field>
                          <Field label="Balance">
                            <input
                              className={inputClass}
                              name="balance"
                              type="number"
                              min="0"
                              step="0.01"
                              required
                              defaultValue={row.balance}
                            />
                          </Field>
                          <Field label="APR %">
                            <input
                              className={inputClass}
                              name="apr"
                              type="number"
                              min="0"
                              step="0.01"
                              defaultValue={row.apr}
                            />
                          </Field>
                          <Field label="Minimum monthly payment">
                            <input
                              className={inputClass}
                              name="minimum_payment"
                              type="number"
                              min="0"
                              step="0.01"
                              defaultValue={row.minimum_payment}
                            />
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
                          <Field label="Priority (tie-breaker, lower = first)">
                            <input
                              className={inputClass}
                              name="priority"
                              type="number"
                              min="1"
                              defaultValue={row.priority}
                            />
                          </Field>
                        </RowActions>
                      </div>
                    </StaggerItem>
                  ))}
                </StaggerGroup>
              ) : (
                <EmptyState
                  icon={<CreditCard className="h-6 w-6" strokeWidth={1.75} />}
                  title="No debts logged"
                  body="Add a debt to generate an automatic Avalanche payoff plan."
                />
              )}
            </Card>
          </Reveal>

          {debts.length ? (
            <Reveal variants={fadeUp} delay={0.05}>
              <Card>
                <h2 className="text-xl font-bold">Payoff schedule</h2>
                <dl className="mt-4 grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
                  <div>
                    <dt className="text-vera-fg-muted">Status</dt>
                    <dd
                      className={`mt-1 font-semibold ${plan.feasible ? 'text-vera-success' : 'text-vera-danger'}`}
                    >
                      {plan.feasible ? 'Feasible' : 'Not feasible with current budget'}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-vera-fg-muted">Required / month</dt>
                    <dd className="mt-1 font-semibold">{formatMoney(plan.requiredMonthly)}</dd>
                  </div>
                  <div>
                    <dt className="text-vera-fg-muted">Available</dt>
                    <dd className="mt-1 font-semibold">{formatMoney(plan.available)}</dd>
                  </div>
                  <div>
                    <dt className="text-vera-fg-muted">Projected remaining</dt>
                    <dd className="mt-1 font-semibold">{formatMoney(plan.projectedRemaining)}</dd>
                  </div>
                </dl>
                <div className="mt-6 max-h-[480px] overflow-y-auto overflow-x-auto rounded-vera-lg border border-vera-border">
                  <table className="w-full min-w-[420px] text-left text-sm">
                    <thead>
                      <tr className="sticky top-0 border-b border-vera-border bg-vera-surface text-vera-fg-muted">
                        <th className="px-3 py-2 font-medium">Month</th>
                        <th className="px-3 py-2 font-medium">Payment</th>
                        <th className="px-3 py-2 font-medium">Remaining</th>
                      </tr>
                    </thead>
                    <tbody>
                      {plan.months.map((m) => (
                        <tr key={m.month} className="border-b border-vera-border/60">
                          <td className="px-3 py-2">{m.month}</td>
                          <td className="px-3 py-2">{formatMoney(m.totalPayment)}</td>
                          <td className="px-3 py-2">{formatMoney(m.remainingDebt)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </Card>
            </Reveal>
          ) : null}
        </div>

        <div className="space-y-6">
          <Reveal variants={fadeUp}>
            <form
              action={addDebtAction}
              className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
            >
              <h2 className="text-xl font-bold">Add debt</h2>
              <Field label="Name">
                <input className={inputClass} name="name" required placeholder="Credit card" />
              </Field>
              <Field label="Balance">
                <input
                  className={inputClass}
                  name="balance"
                  type="number"
                  min="0"
                  step="0.01"
                  required
                />
              </Field>
              <Field label="APR %">
                <input
                  className={inputClass}
                  name="apr"
                  type="number"
                  min="0"
                  step="0.01"
                  defaultValue={0}
                />
              </Field>
              <Field label="Minimum monthly payment">
                <input
                  className={inputClass}
                  name="minimum_payment"
                  type="number"
                  min="0"
                  step="0.01"
                  defaultValue={0}
                />
              </Field>
              <Field label="Due day (1-31, optional)">
                <input className={inputClass} name="due_day" type="number" min="1" max="31" />
              </Field>
              <Field label="Priority (tie-breaker, lower = first)">
                <input
                  className={inputClass}
                  name="priority"
                  type="number"
                  min="1"
                  defaultValue={1}
                />
              </Field>
              <SubmitButton>Add debt</SubmitButton>
            </form>
          </Reveal>

          <Reveal variants={fadeUp} delay={0.05}>
            <form
              action={updatePlanSettingsAction}
              className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
            >
              <h2 className="text-xl font-bold">Plan settings</h2>
              <Field label="Target months to be debt-free">
                <input
                  className={inputClass}
                  name="targetMonths"
                  type="number"
                  min="1"
                  max="120"
                  defaultValue={targetMonths}
                />
              </Field>
              <Field label="Plan start date">
                <input
                  className={inputClass}
                  name="startDate"
                  type="date"
                  defaultValue={startDate}
                />
              </Field>
              <SubmitButton>Save plan settings</SubmitButton>
            </form>
          </Reveal>
        </div>
      </div>
    </main>
  );
}
