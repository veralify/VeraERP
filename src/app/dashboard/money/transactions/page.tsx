import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { RowActions } from '@components/generic/RowActions';
import {
  Card,
  ErrorMessage,
  Field,
  inputClass,
  PageHeader,
  Pager,
  SubmitButton,
} from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { formatMoney } from '@lib/money/format';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { ArrowLeftRight } from 'lucide-react';
import type { Metadata } from 'next';
import {
  addTransactionAction,
  deleteTransactionAction,
  updateTransactionAction,
} from '../actions/transactions';

export const metadata: Metadata = { title: 'Transactions · Money' };
type SearchParams = Promise<{ error?: string; saved?: string; page?: string }>;
const pageSize = 20;

export default async function TransactionsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const page = Math.max(1, Number(params.page) || 1);
  const from = (page - 1) * pageSize;
  const to = from + pageSize;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: rows } = await supabase
    .from('money_transactions')
    .select('id, transaction_date, merchant, amount, direction, category, account, notes')
    .eq('user_id', user.id)
    .order('transaction_date', { ascending: false })
    .range(from, to)
    .limit(pageSize + 1);
  const transactions = (rows ?? []).slice(0, pageSize);
  const hasNext = (rows?.length ?? 0) > pageSize;

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Transactions"
        body="A log of individual income and expense transactions, separate from your recurring budget."
      />
      <ErrorMessage
        message={
          params.error === 'save'
            ? 'We couldn’t save that change. Please try again.'
            : params.error
              ? 'Enter a merchant, amount, and date.'
              : undefined
        }
      />

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">Your transactions</h2>
            {transactions.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {transactions.map((row) => (
                  <StaggerItem
                    key={row.id}
                    as="div"
                    className="flex items-center justify-between gap-3 py-4"
                  >
                    <div>
                      <p className="font-semibold">{row.merchant}</p>
                      <p className="text-sm text-vera-fg-muted">
                        {row.transaction_date} · {row.category} · {row.account}
                      </p>
                    </div>
                    <div className="flex items-center gap-3">
                      <p
                        className={`text-lg font-bold ${row.direction === 'income' ? 'text-vera-success' : 'text-vera-fg'}`}
                      >
                        {row.direction === 'income' ? '+' : '−'}
                        {formatMoney(Number(row.amount))}
                      </p>
                      <RowActions
                        id={row.id}
                        itemLabel={row.merchant}
                        editTitle="Edit transaction"
                        updateAction={updateTransactionAction}
                        deleteAction={deleteTransactionAction}
                      >
                        <Field label="Merchant">
                          <input
                            className={inputClass}
                            name="merchant"
                            required
                            defaultValue={row.merchant}
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
                        <Field label="Direction">
                          <select
                            className={inputClass}
                            name="direction"
                            defaultValue={row.direction}
                          >
                            <option value="expense">Expense</option>
                            <option value="income">Income</option>
                          </select>
                        </Field>
                        <Field label="Date">
                          <input
                            className={inputClass}
                            name="transaction_date"
                            type="date"
                            required
                            defaultValue={row.transaction_date}
                          />
                        </Field>
                        <Field label="Category">
                          <input
                            className={inputClass}
                            name="category"
                            defaultValue={row.category}
                          />
                        </Field>
                        <Field label="Account">
                          <input className={inputClass} name="account" defaultValue={row.account} />
                        </Field>
                        <Field label="Notes">
                          <textarea
                            className={inputClass}
                            name="notes"
                            rows={2}
                            defaultValue={row.notes}
                          />
                        </Field>
                      </RowActions>
                    </div>
                  </StaggerItem>
                ))}
              </StaggerGroup>
            ) : (
              <EmptyState
                icon={<ArrowLeftRight className="h-6 w-6" strokeWidth={1.75} />}
                title="No transactions yet"
                body="Log individual purchases or income to keep a searchable transaction history."
              />
            )}
            <Pager page={page} hasNext={hasNext} basePath="/dashboard/money/transactions" />
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.05}>
          <form
            action={addTransactionAction}
            className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
          >
            <h2 className="text-xl font-bold">Add transaction</h2>
            <Field label="Merchant">
              <input className={inputClass} name="merchant" required placeholder="Grocery store" />
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
            <Field label="Direction">
              <select className={inputClass} name="direction" defaultValue="expense">
                <option value="expense">Expense</option>
                <option value="income">Income</option>
              </select>
            </Field>
            <Field label="Date">
              <input
                className={inputClass}
                name="transaction_date"
                type="date"
                required
                defaultValue={new Date().toISOString().slice(0, 10)}
              />
            </Field>
            <Field label="Category">
              <input className={inputClass} name="category" defaultValue="Uncategorized" />
            </Field>
            <Field label="Account">
              <input className={inputClass} name="account" defaultValue="Main account" />
            </Field>
            <Field label="Notes">
              <textarea className={inputClass} name="notes" rows={2} />
            </Field>
            <SubmitButton>Add transaction</SubmitButton>
          </form>
        </Reveal>
      </div>
    </main>
  );
}
