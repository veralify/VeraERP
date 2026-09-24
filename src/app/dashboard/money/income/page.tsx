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
import { Wallet } from 'lucide-react';
import type { Metadata } from 'next';
import { addIncomeAction, deleteIncomeAction, updateIncomeAction } from '../actions/income';

export const metadata: Metadata = { title: 'Income · Money' };
type SearchParams = Promise<{ error?: string; saved?: string }>;

export default async function IncomePage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: rows } = await supabase
    .from('money_income')
    .select('id, name, amount, type, payday, active')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });
  const income = rows ?? [];

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Income sources"
        body="Recurring income used to calculate your available budget and debt payoff plan."
      />
      <ErrorMessage
        message={
          params.error === 'save'
            ? 'We couldn’t save that change. Please try again.'
            : params.error
              ? 'Enter a name and a valid amount.'
              : undefined
        }
      />

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">Your income</h2>
            {income.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {income.map((row) => (
                  <StaggerItem
                    key={row.id}
                    as="div"
                    className="flex items-center justify-between gap-3 py-4"
                  >
                    <div>
                      <p className="font-semibold">{row.name}</p>
                      <p className="text-sm text-vera-fg-muted">
                        {row.type}
                        {row.payday ? ` · payday ${row.payday}` : ''}
                        {row.active ? '' : ' · inactive'}
                      </p>
                    </div>
                    <div className="flex items-center gap-3">
                      <p className="text-lg font-bold">{formatMoney(Number(row.amount))}</p>
                      <RowActions
                        id={row.id}
                        itemLabel={row.name}
                        editTitle="Edit income"
                        updateAction={updateIncomeAction}
                        deleteAction={deleteIncomeAction}
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
                        <Field label="Type">
                          <select className={inputClass} name="type" defaultValue={row.type}>
                            <option value="fixed">Fixed</option>
                            <option value="variable">Variable</option>
                          </select>
                        </Field>
                        <Field label="Payday (1-31, optional)">
                          <input
                            className={inputClass}
                            name="payday"
                            type="number"
                            min="1"
                            max="31"
                            defaultValue={row.payday ?? ''}
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
                icon={<Wallet className="h-6 w-6" strokeWidth={1.75} />}
                title="No income sources yet"
                body="Add your salary or other recurring income to start building your budget."
              />
            )}
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.05}>
          <form
            action={addIncomeAction}
            className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
          >
            <h2 className="text-xl font-bold">Add income</h2>
            <Field label="Name">
              <input className={inputClass} name="name" required placeholder="Salary" />
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
            <Field label="Type">
              <select className={inputClass} name="type" defaultValue="fixed">
                <option value="fixed">Fixed</option>
                <option value="variable">Variable</option>
              </select>
            </Field>
            <Field label="Payday (1-31, optional)">
              <input className={inputClass} name="payday" type="number" min="1" max="31" />
            </Field>
            <SubmitButton>Add income</SubmitButton>
          </form>
        </Reveal>
      </div>
    </main>
  );
}
