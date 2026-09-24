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
import { CategorySelect } from '@components/money/CategorySelect';
import { formatCurrency } from '@lib/money/format';
import { getCustomCategoryNames, getHomeCurrency, transactionQuery } from '@lib/money/queries';
import {
  categoryLabel,
  categoryOptions,
  currentMonth,
  filtersToQuery,
  monthBounds,
  monthLabel,
  normalizeCategoryKey,
  parseTransactionFilters,
} from '@lib/money/spending';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { ArrowLeftRight, Download, ReceiptText } from 'lucide-react';
import type { Metadata } from 'next';
import {
  addTransactionAction,
  deleteTransactionAction,
  updateTransactionAction,
} from '../actions/transactions';

export const metadata: Metadata = { title: 'Transactions · Money' };
type SearchParams = Promise<Record<string, string | string[] | undefined>>;
const pageSize = 20;

export default async function TransactionsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const error = typeof params.error === 'string' ? params.error : undefined;
  const page = Math.max(1, Number(params.page) || 1);
  const filters = parseTransactionFilters(params);
  const query = filtersToQuery(filters);
  const from = (page - 1) * pageSize;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const range = filters.month ? monthBounds(filters.month) : null;
  const [{ data: rows }, home, customNames] = await Promise.all([
    transactionQuery(
      supabase,
      user.id,
      { from: range?.start, to: range?.end },
      filters,
      // One extra row tells us whether there is a next page.
    ).range(from, from + pageSize),
    getHomeCurrency(supabase, user.id),
    getCustomCategoryNames(supabase, user.id),
  ]);
  const transactions = (rows ?? []).slice(0, pageSize);
  const hasNext = (rows?.length ?? 0) > pageSize;
  const options = categoryOptions(customNames);
  const filtered = Object.keys(query).length > 0;
  const exportQuery = new URLSearchParams(query).toString();

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Transactions"
        body="A log of individual income and expense transactions, separate from your recurring budget. Receipts you confirm on your phone land here too."
        action={
          <a
            className="btn-apple-secondary"
            href={`/dashboard/money/transactions/export${exportQuery ? `?${exportQuery}` : ''}`}
            download
          >
            <Download className="h-4 w-4" strokeWidth={1.75} aria-hidden="true" />
            Export CSV
          </a>
        }
      />
      <ErrorMessage
        message={
          error === 'save'
            ? 'We couldn’t save that change. Please try again.'
            : error
              ? 'Enter a merchant, amount, date and a three-letter currency code.'
              : undefined
        }
      />

      <form
        method="get"
        action="/dashboard/money/transactions"
        className="mt-4 flex flex-wrap items-end gap-3"
        aria-label="Filter transactions"
      >
        <label className="grid gap-1 text-sm font-medium">
          <span>Month</span>
          <input
            className={`${inputClass} w-44`}
            type="month"
            name="month"
            defaultValue={filters.month ?? ''}
            max={currentMonth()}
          />
        </label>
        <div className="grid gap-1 text-sm font-medium">
          <label htmlFor="transaction-category">Category</label>
          <CategorySelect
            id="transaction-category"
            options={options}
            defaultValue={filters.category ?? ''}
            allLabel="All categories"
          />
        </div>
        <label className="grid gap-1 text-sm font-medium">
          <span>Scope</span>
          <select className={inputClass} name="scope" defaultValue={filters.scope ?? ''}>
            <option value="">Personal and business</option>
            <option value="personal">Personal</option>
            <option value="business">Business</option>
          </select>
        </label>
        <label className="grid gap-1 text-sm font-medium">
          <span>Type</span>
          <select className={inputClass} name="direction" defaultValue={filters.direction ?? ''}>
            <option value="">Income and expenses</option>
            <option value="expense">Expenses</option>
            <option value="income">Income</option>
          </select>
        </label>
        <button type="submit" className="btn-apple-secondary">
          Apply
        </button>
        {filtered ? (
          <a
            className="min-h-11 px-2 py-3 text-sm font-semibold text-vera-primary hover:underline"
            href="/dashboard/money/transactions"
          >
            Clear filters
          </a>
        ) : null}
      </form>

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">
              {filters.month ? `Transactions in ${monthLabel(filters.month)}` : 'Your transactions'}
            </h2>
            {transactions.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {transactions.map((row) => (
                  <StaggerItem
                    key={row.id}
                    as="div"
                    className="flex items-center justify-between gap-3 py-4"
                  >
                    <div className="min-w-0">
                      <p className="flex items-center gap-2 font-semibold">
                        <span className="truncate">{row.merchant}</span>
                        {row.receipt_id ? (
                          <a
                            href={`/dashboard/money/receipts?month=${row.transaction_date.slice(0, 7)}`}
                            className="flex-none text-vera-primary"
                            aria-label="Has a receipt — view receipts"
                          >
                            <ReceiptText className="h-4 w-4" strokeWidth={1.75} />
                          </a>
                        ) : null}
                      </p>
                      <p className="text-sm text-vera-fg-muted">
                        {row.transaction_date} ·{' '}
                        {categoryLabel(normalizeCategoryKey(row.category), customNames)} ·{' '}
                        {row.account}
                        {row.scope === 'business' ? ' · Business' : ''}
                      </p>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className="text-right">
                        <p
                          className={`text-lg font-bold tabular-nums ${row.direction === 'income' ? 'text-vera-success' : 'text-vera-fg'}`}
                        >
                          {row.direction === 'income' ? '+' : '−'}
                          {formatCurrency(Number(row.amount), row.currency)}
                        </p>
                        {row.currency !== home && row.home_amount !== null ? (
                          <p className="text-xs text-vera-fg-muted tabular-nums">
                            ≈ {formatCurrency(Number(row.home_amount), home)}
                          </p>
                        ) : null}
                      </div>
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
                        <div className="grid grid-cols-[1fr_7rem] gap-3">
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
                          <Field label="Currency">
                            <input
                              className={`${inputClass} uppercase`}
                              name="currency"
                              required
                              maxLength={3}
                              pattern="[A-Za-z]{3}"
                              defaultValue={row.currency}
                            />
                          </Field>
                        </div>
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
                          <CategorySelect options={options} defaultValue={row.category} />
                        </Field>
                        <Field label="Scope">
                          <select className={inputClass} name="scope" defaultValue={row.scope}>
                            <option value="personal">Personal</option>
                            <option value="business">Business</option>
                          </select>
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
            ) : filtered ? (
              <EmptyState
                icon={<ArrowLeftRight className="h-6 w-6" strokeWidth={1.75} />}
                title="No matching transactions"
                body="Nothing matches these filters. Try another month or clear the filters."
                ctaHref="/dashboard/money/transactions"
                ctaLabel="Clear filters"
              />
            ) : (
              <EmptyState
                icon={<ArrowLeftRight className="h-6 w-6" strokeWidth={1.75} />}
                title="No transactions yet"
                body="Log individual purchases or income to keep a searchable transaction history."
              />
            )}
            <Pager
              page={page}
              hasNext={hasNext}
              basePath="/dashboard/money/transactions"
              query={query}
            />
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
            <div className="grid grid-cols-[1fr_7rem] gap-3">
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
            </div>
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
              <CategorySelect options={options} defaultValue="other" />
            </Field>
            <Field label="Scope">
              <select className={inputClass} name="scope" defaultValue="personal">
                <option value="personal">Personal</option>
                <option value="business">Business</option>
              </select>
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
