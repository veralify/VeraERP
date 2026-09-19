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
import { daysUntil, formatMoney } from '@lib/money/format';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { Repeat } from 'lucide-react';
import type { Metadata } from 'next';
import {
  addSubscriptionAction,
  deleteSubscriptionAction,
  updateSubscriptionAction,
} from '../actions/subscriptions';

export const metadata: Metadata = { title: 'Subscriptions · Money' };
type SearchParams = Promise<{ error?: string; saved?: string }>;

function badgeFor(nextCharge: string | null, trialEnds: string | null) {
  const trialDays = daysUntil(trialEnds);
  if (trialDays !== null && trialDays <= 7) {
    return trialDays < 0
      ? { text: 'Trial ended', tone: 'text-vera-fg-muted' }
      : { text: `Trial ends in ${trialDays}d`, tone: 'text-vera-warning' };
  }
  const chargeDays = daysUntil(nextCharge);
  if (chargeDays !== null && chargeDays <= 7 && chargeDays >= 0) {
    return { text: `Renews in ${chargeDays}d`, tone: 'text-vera-primary' };
  }
  return null;
}

export default async function SubscriptionsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: rows } = await supabase
    .from('money_subscriptions')
    .select('id, name, amount, cadence, next_charge_date, trial_ends_on, category, active')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });
  const subscriptions = rows ?? [];

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Subscriptions"
        body="Recurring subscriptions and free trials — see what's renewing or converting soon."
      />
      <ErrorMessage message={params.error ? 'Enter a name and a valid amount.' : undefined} />

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">Your subscriptions</h2>
            {subscriptions.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {subscriptions.map((row) => {
                  const badge = badgeFor(row.next_charge_date, row.trial_ends_on);
                  return (
                    <StaggerItem
                      key={row.id}
                      as="div"
                      className="flex items-center justify-between gap-3 py-4"
                    >
                      <div>
                        <p className="font-semibold">
                          {row.name}
                          {row.active ? '' : ' · inactive'}
                        </p>
                        <p className="text-sm text-vera-fg-muted">
                          {row.category} · {row.cadence}
                          {badge ? (
                            <span className={`ml-2 font-semibold ${badge.tone}`}>{badge.text}</span>
                          ) : null}
                        </p>
                      </div>
                      <div className="flex items-center gap-3">
                        <p className="text-lg font-bold">{formatMoney(Number(row.amount))}</p>
                        <RowActions
                          id={row.id}
                          itemLabel={row.name}
                          editTitle="Edit subscription"
                          updateAction={updateSubscriptionAction}
                          deleteAction={deleteSubscriptionAction}
                        >
                          <Field label="Name">
                            <input
                              className={inputClass}
                              name="name"
                              required
                              defaultValue={row.name}
                            />
                          </Field>
                          <Field label="Amount">
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
                          <Field label="Cadence">
                            <select
                              className={inputClass}
                              name="cadence"
                              defaultValue={row.cadence}
                            >
                              <option value="monthly">Monthly</option>
                              <option value="yearly">Yearly</option>
                            </select>
                          </Field>
                          <Field label="Next charge date (optional)">
                            <input
                              className={inputClass}
                              name="next_charge_date"
                              type="date"
                              defaultValue={row.next_charge_date ?? ''}
                            />
                          </Field>
                          <Field label="Trial ends on (optional)">
                            <input
                              className={inputClass}
                              name="trial_ends_on"
                              type="date"
                              defaultValue={row.trial_ends_on ?? ''}
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
                    </StaggerItem>
                  );
                })}
              </StaggerGroup>
            ) : (
              <EmptyState
                icon={<Repeat className="h-6 w-6" strokeWidth={1.75} />}
                title="No subscriptions yet"
                body="Add a subscription to track renewals and free-trial endings before they charge you."
              />
            )}
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.05}>
          <form
            action={addSubscriptionAction}
            className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
          >
            <h2 className="text-xl font-bold">Add subscription</h2>
            <Field label="Name">
              <input className={inputClass} name="name" required placeholder="Streaming service" />
            </Field>
            <Field label="Amount">
              <input
                className={inputClass}
                name="amount"
                type="number"
                min="0"
                step="0.01"
                required
              />
            </Field>
            <Field label="Cadence">
              <select className={inputClass} name="cadence" defaultValue="monthly">
                <option value="monthly">Monthly</option>
                <option value="yearly">Yearly</option>
              </select>
            </Field>
            <Field label="Next charge date (optional)">
              <input className={inputClass} name="next_charge_date" type="date" />
            </Field>
            <Field label="Trial ends on (optional)">
              <input className={inputClass} name="trial_ends_on" type="date" />
            </Field>
            <Field label="Category">
              <input className={inputClass} name="category" defaultValue="Subscriptions" />
            </Field>
            <SubmitButton>Add subscription</SubmitButton>
          </form>
        </Reveal>
      </div>
    </main>
  );
}
