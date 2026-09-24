import { Banner } from '@components/generic/Banner';
import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { Card, inputClass, PageHeader, Pager } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { CategorySelect } from '@components/money/CategorySelect';
import { ReceiptStatusBadge } from '@components/money/ReceiptStatusBadge';
import { formatCurrency } from '@lib/money/format';
import { getCustomCategoryNames, getLinkedTransactions, RECEIPT_COLUMNS } from '@lib/money/queries';
import {
  RECEIPT_STATUS_LABELS,
  RECEIPT_STATUSES,
  receiptView,
  sortImagePaths,
} from '@lib/money/receipts';
import {
  categoryLabel,
  categoryOptions,
  currentMonth,
  monthBounds,
  monthLabel,
  normalizeCategoryKey,
  parseMonth,
} from '@lib/money/spending';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { FileText, ImageOff, ReceiptText } from 'lucide-react';
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Receipts · Money' };

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

const pageSize = 12;
/** Receipt images are private; each view mints links that die after this. */
const SIGNED_URL_SECONDS = 10 * 60;
/** Receipts in one month rarely come close; past it the page says so. */
const MONTH_LIMIT = 1000;

const one = (value: string | string[] | undefined) => (Array.isArray(value) ? value[0] : value);

export default async function ReceiptsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const thisMonth = currentMonth();
  const requested = parseMonth(one(params.month), thisMonth);
  const month = requested > thisMonth ? thisMonth : requested;
  const categoryFilter = one(params.category)?.trim() || null;
  const scopeParam = one(params.scope);
  const scopeFilter = scopeParam === 'personal' || scopeParam === 'business' ? scopeParam : null;
  const statusParam = one(params.status);
  const statusFilter = RECEIPT_STATUSES.find((s) => s === statusParam) ?? null;
  const page = Math.max(1, Number(one(params.page)) || 1);

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  // A receipt belongs to the month on the receipt; one not read yet has no
  // date, so it belongs to the month it was uploaded.
  const { start, end } = monthBounds(month);
  let query = supabase
    .from('money_receipts')
    .select(RECEIPT_COLUMNS)
    .eq('user_id', user.id)
    .is('deleted_at', null)
    .or(
      `and(receipt_date.gte.${start},receipt_date.lt.${end}),and(receipt_date.is.null,created_at.gte.${start},created_at.lt.${end})`,
    )
    .order('created_at', { ascending: false })
    .limit(MONTH_LIMIT);
  if (statusFilter) query = query.eq('status', statusFilter);

  const [{ data: receiptRows, error }, customNames] = await Promise.all([
    query,
    getCustomCategoryNames(supabase, user.id),
  ]);
  const receipts = receiptRows ?? [];
  const linked = await getLinkedTransactions(supabase, user.id, receipts);

  // Category and scope come from the confirmed transaction or, before that,
  // from the AI's reading, so they are filtered here rather than in SQL.
  const views = receipts
    .map((receipt) => {
      const transaction = receipt.transaction_id
        ? (linked.get(receipt.transaction_id) ?? null)
        : null;
      return { receipt, transaction, view: receiptView(receipt, transaction) };
    })
    .filter(
      ({ view }) =>
        (!categoryFilter ||
          (view.category !== null && normalizeCategoryKey(view.category) === categoryFilter)) &&
        (!scopeFilter || view.scope === scopeFilter),
    )
    .sort((a, b) => b.view.date.localeCompare(a.view.date));

  const shown = views.slice((page - 1) * pageSize, page * pageSize);
  const hasNext = views.length > page * pageSize;

  // Signed server-side for only the receipts on screen: the bucket is
  // private and the links expire, so nothing here is a lasting public URL.
  const paths = shown.flatMap(({ receipt }) => receipt.image_paths);
  const signed = new Map<string, string>();
  let imagesFailed = false;
  if (paths.length) {
    const { data, error: signError } = await supabase.storage
      .from('receipts')
      .createSignedUrls(paths, SIGNED_URL_SECONDS);
    if (signError) imagesFailed = true;
    for (const item of data ?? []) {
      if (item.path && item.signedUrl && !item.error) signed.set(item.path, item.signedUrl);
    }
  }

  const options = categoryOptions(customNames);
  const query_ = {
    month,
    category: categoryFilter ?? undefined,
    scope: scopeFilter ?? undefined,
    status: statusFilter ?? undefined,
  };
  const filtered = Boolean(categoryFilter || scopeFilter || statusFilter);

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Receipts"
        body="Receipts you scan or forward from the Veralify app, with what was read from them. Review and confirm them on your phone."
      />

      <form
        method="get"
        action="/dashboard/money/receipts"
        className="flex flex-wrap items-end gap-3"
        aria-label="Filter receipts"
      >
        <label className="grid gap-1 text-sm font-medium">
          <span>Month</span>
          <input
            className={`${inputClass} w-44`}
            type="month"
            name="month"
            defaultValue={month}
            max={thisMonth}
            required
          />
        </label>
        <div className="grid gap-1 text-sm font-medium">
          <label htmlFor="receipt-category">Category</label>
          <CategorySelect
            id="receipt-category"
            options={options}
            defaultValue={categoryFilter ?? ''}
            allLabel="All categories"
          />
        </div>
        <label className="grid gap-1 text-sm font-medium">
          <span>Scope</span>
          <select className={inputClass} name="scope" defaultValue={scopeFilter ?? ''}>
            <option value="">Personal and business</option>
            <option value="personal">Personal</option>
            <option value="business">Business</option>
          </select>
        </label>
        <label className="grid gap-1 text-sm font-medium">
          <span>Status</span>
          <select className={inputClass} name="status" defaultValue={statusFilter ?? ''}>
            <option value="">Any status</option>
            {RECEIPT_STATUSES.map((status) => (
              <option key={status} value={status}>
                {RECEIPT_STATUS_LABELS[status]}
              </option>
            ))}
          </select>
        </label>
        <button type="submit" className="btn-apple-secondary">
          Apply
        </button>
        {filtered ? (
          <a
            className="min-h-11 px-2 py-3 text-sm font-semibold text-vera-primary hover:underline"
            href={`/dashboard/money/receipts?month=${month}`}
          >
            Clear filters
          </a>
        ) : null}
      </form>

      <div className="mt-4 grid gap-3">
        <Banner
          variant="error"
          message={error ? 'We couldn’t load your receipts. Please try again.' : undefined}
        />
        <Banner
          variant="warning"
          message={
            imagesFailed
              ? 'Receipt images couldn’t be loaded right now. The details below are still correct.'
              : receipts.length >= MONTH_LIMIT
                ? `Showing the latest ${MONTH_LIMIT} receipts for ${monthLabel(month)}.`
                : undefined
          }
        />
      </div>

      <Reveal variants={fadeUp} className="mt-4">
        <Card>
          <h2 className="text-xl font-bold">
            {monthLabel(month)}
            <span className="ml-2 text-base font-medium text-vera-fg-muted">
              {views.length} {views.length === 1 ? 'receipt' : 'receipts'}
            </span>
          </h2>
          {shown.length ? (
            <StaggerGroup className="mt-4 divide-y divide-vera-border">
              {shown.map(({ receipt, transaction, view }) => {
                const pages = sortImagePaths(receipt.image_paths);
                const cover = pages[0] ? signed.get(pages[0]) : undefined;
                const coverIsImage = pages[0] ? !/\.pdf$/i.test(pages[0]) : false;
                return (
                  <StaggerItem
                    key={receipt.id}
                    as="article"
                    className="flex flex-col gap-4 py-5 sm:flex-row"
                  >
                    <div className="flex-none">
                      {cover && coverIsImage ? (
                        <a
                          href={cover}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="block overflow-hidden rounded-vera-md border border-vera-border"
                          aria-label={`Open receipt image${view.merchant ? ` from ${view.merchant}` : ''}`}
                        >
                          {/* biome-ignore lint/performance/noImgElement: signed URLs expire in minutes; next/image would cache them past that */}
                          <img
                            src={cover}
                            alt=""
                            loading="lazy"
                            className="h-32 w-24 bg-vera-surface-muted object-cover"
                          />
                        </a>
                      ) : (
                        <div className="flex h-32 w-24 items-center justify-center rounded-vera-md border border-vera-border bg-vera-surface-muted text-vera-fg-subtle">
                          {cover ? (
                            <a
                              href={cover}
                              target="_blank"
                              rel="noopener noreferrer"
                              aria-label="Open receipt document"
                            >
                              <FileText className="h-6 w-6" strokeWidth={1.75} />
                            </a>
                          ) : (
                            <ImageOff
                              className="h-6 w-6"
                              strokeWidth={1.75}
                              aria-label="No image available"
                            />
                          )}
                        </div>
                      )}
                    </div>

                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="truncate text-lg font-semibold">
                            {view.merchant ??
                              (receipt.status === 'failed' ? 'Unreadable receipt' : 'Not read yet')}
                          </p>
                          <p className="mt-0.5 text-sm text-vera-fg-muted">
                            {view.dateIsUpload ? `Uploaded ${view.date}` : view.date}
                            {view.category
                              ? ` · ${categoryLabel(normalizeCategoryKey(view.category), customNames)}`
                              : ''}
                            {view.scope
                              ? ` · ${view.scope === 'business' ? 'Business' : 'Personal'}`
                              : ''}
                          </p>
                        </div>
                        <div className="text-right">
                          <p className="text-lg font-bold tabular-nums">
                            {view.total !== null && view.currency
                              ? formatCurrency(view.total, view.currency)
                              : '—'}
                          </p>
                          <ReceiptStatusBadge status={receipt.status} />
                        </div>
                      </div>

                      <p className="mt-3 text-sm text-vera-fg-muted">
                        {transaction ? (
                          <>
                            Saved as{' '}
                            <a
                              className="font-semibold text-vera-primary hover:underline"
                              href={`/dashboard/money/transactions?month=${transaction.transaction_date.slice(0, 7)}`}
                            >
                              {transaction.merchant}
                            </a>{' '}
                            · {transaction.transaction_date} ·{' '}
                            {formatCurrency(Number(transaction.amount), transaction.currency)}
                          </>
                        ) : receipt.status === 'extracted' ? (
                          'Read and waiting for you to confirm it in the app.'
                        ) : (
                          'Not linked to a transaction yet.'
                        )}
                      </p>

                      {pages.length > 1 ? (
                        <p className="mt-2 flex flex-wrap gap-3 text-sm">
                          {pages.map((path, index) => {
                            const url = signed.get(path);
                            return url ? (
                              <a
                                key={path}
                                href={url}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="font-semibold text-vera-primary hover:underline"
                              >
                                Page {index + 1}
                              </a>
                            ) : (
                              <span key={path} className="text-vera-fg-subtle">
                                Page {index + 1}
                              </span>
                            );
                          })}
                        </p>
                      ) : null}
                    </div>
                  </StaggerItem>
                );
              })}
            </StaggerGroup>
          ) : (
            <EmptyState
              icon={<ReceiptText className="h-6 w-6" strokeWidth={1.75} />}
              title={filtered ? 'No matching receipts' : `No receipts in ${monthLabel(month)}`}
              body={
                filtered
                  ? 'Nothing matches these filters. Try another month or clear the filters.'
                  : 'Scan a receipt with the Veralify app and it appears here once it syncs.'
              }
            />
          )}
          <Pager
            page={page}
            hasNext={hasNext}
            basePath="/dashboard/money/receipts"
            query={query_}
          />
        </Card>
      </Reveal>
    </main>
  );
}
