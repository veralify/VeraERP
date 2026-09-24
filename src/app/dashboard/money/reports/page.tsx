import { Banner } from '@components/generic/Banner';
import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { Card, Field, inputClass, PageHeader } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import type { SupabaseClient } from '@supabase/supabase-js';
import { Download, FileSpreadsheet, FileText, Paperclip, Receipt } from 'lucide-react';
import type { Metadata } from 'next';
import {
  categoryLabel,
  filtersToQuery,
  formatAmount,
  formatDate,
  humaniseKey,
  isoDate,
  loadReport,
  parseReportFilters,
  type ReportFilters,
  SCOPE_LABEL,
} from './_lib/report';

export const metadata: Metadata = { title: 'Reports · Money' };

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

// The page lists this many lines; the downloads always carry the full selection.
const LINES_ON_PAGE = 300;

function presets(filters: ReportFilters, today = new Date()) {
  const y = today.getFullYear();
  const m = today.getMonth();
  const ranges: { label: string; from: Date; to: Date }[] = [
    { label: 'This month', from: new Date(y, m, 1), to: today },
    { label: 'Last month', from: new Date(y, m - 1, 1), to: new Date(y, m, 0) },
    { label: 'This year', from: new Date(y, 0, 1), to: today },
    { label: 'Last year', from: new Date(y - 1, 0, 1), to: new Date(y - 1, 11, 31) },
  ];
  // UK tax year: 6 April to 5 April.
  const taxYearStart = today >= new Date(y, 3, 6) ? y : y - 1;
  ranges.push({
    label: 'UK tax year',
    from: new Date(taxYearStart, 3, 6),
    to: new Date(taxYearStart + 1, 3, 5),
  });
  return ranges.map((range) => {
    const next = { ...filters, from: isoDate(range.from), to: isoDate(range.to) };
    return {
      label: range.label,
      href: `/dashboard/money/reports?${filtersToQuery(next)}`,
      active: next.from === filters.from && next.to === filters.to,
    };
  });
}

export default async function ReportsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const filters = parseReportFilters(params);
  let report: Awaited<ReturnType<typeof loadReport>> | null = null;
  try {
    report = await loadReport(supabase as unknown as SupabaseClient, user.id, filters);
  } catch (error) {
    console.error('money report failed', error);
  }

  const query = filtersToQuery(filters);
  const home = report?.homeCurrency ?? 'EUR';
  const names = new Map((report?.categories ?? []).map((row) => [row.key, row.name]));
  const categoryOptions = [...(report?.categories ?? [])];
  if (filters.category && !names.has(filters.category)) {
    categoryOptions.push({ key: filters.category, name: humaniseKey(filters.category) });
  }

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Expense report"
        body="Pick a period and see where the money went, by category and line by line. Download it as a PDF with your receipts attached, or as a CSV for your accountant."
        action={
          report?.rows.length ? (
            <div className="flex flex-wrap gap-2">
              <a className="btn-apple" href={`/api/money/reports/pdf?${query}`}>
                <Download className="h-4 w-4" strokeWidth={2} aria-hidden="true" />
                PDF with receipts
              </a>
              <a className="btn-apple-secondary" href={`/api/money/reports/csv?${query}`}>
                <FileSpreadsheet className="h-4 w-4" strokeWidth={1.75} aria-hidden="true" />
                CSV
              </a>
            </div>
          ) : null
        }
      />

      <Banner
        variant="error"
        message={report ? undefined : 'We couldn’t load this report. Please try again.'}
      />

      <Reveal variants={fadeUp}>
        <Card>
          <form
            method="get"
            className="grid gap-4 sm:grid-cols-2 lg:grid-cols-[1fr_1fr_1fr_1fr_auto]"
          >
            <Field label="From">
              <input className={inputClass} type="date" name="from" defaultValue={filters.from} />
            </Field>
            <Field label="To">
              <input className={inputClass} type="date" name="to" defaultValue={filters.to} />
            </Field>
            <Field label="Scope">
              <select className={inputClass} name="scope" defaultValue={filters.scope}>
                <option value="all">Business and personal</option>
                <option value="business">Business</option>
                <option value="personal">Personal</option>
              </select>
            </Field>
            <Field label="Category">
              <select
                className={inputClass}
                name="category"
                defaultValue={filters.category ?? 'all'}
              >
                <option value="all">All categories</option>
                {categoryOptions.map((category) => (
                  <option key={category.key} value={category.key}>
                    {category.name}
                  </option>
                ))}
              </select>
            </Field>
            <div className="flex items-end">
              <button type="submit" className="btn-apple w-full lg:w-auto">
                Show report
              </button>
            </div>
          </form>
          <nav className="mt-4 flex flex-wrap gap-2" aria-label="Date presets">
            {presets(filters).map((preset) => (
              <a
                key={preset.label}
                href={preset.href}
                aria-current={preset.active ? 'true' : undefined}
                className={`rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors ${
                  preset.active
                    ? 'border-vera-primary bg-vera-primary/10 text-vera-primary'
                    : 'border-vera-border text-vera-fg-muted hover:border-vera-primary/40'
                }`}
              >
                {preset.label}
              </a>
            ))}
          </nav>
        </Card>
      </Reveal>

      {report ? (
        <>
          <StaggerGroup className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {[
              { label: `Total (${home})`, value: formatAmount(report.total, home), icon: Receipt },
              { label: 'Expenses', value: String(report.rows.length), icon: FileText },
              { label: 'With a receipt', value: String(report.receiptCount), icon: Paperclip },
              {
                label: 'Not converted',
                value: String(report.unconvertedCount),
                icon: FileSpreadsheet,
              },
            ].map((stat) => (
              <StaggerItem
                key={stat.label}
                as="article"
                className="rounded-vera-xl border border-vera-border bg-vera-surface p-5 shadow-[var(--vera-shadow-sm)]"
              >
                <stat.icon className="h-5 w-5 text-vera-primary" strokeWidth={1.75} />
                <p className="mt-3 text-2xl font-black tracking-tight">{stat.value}</p>
                <p className="mt-1 text-sm text-vera-fg-muted">{stat.label}</p>
              </StaggerItem>
            ))}
          </StaggerGroup>

          <p className="mt-4 text-sm text-vera-fg-muted">
            {formatDate(filters.from)} – {formatDate(filters.to)} · {SCOPE_LABEL[filters.scope]} ·{' '}
            {categoryLabel(report)}. Foreign-currency expenses are converted to {home} at the ECB
            reference rate for their date.
          </p>
          <Banner
            variant="warning"
            className="mt-4"
            message={
              report.unconvertedCount
                ? `${report.unconvertedCount} expense(s) in another currency have no exchange rate for their date yet. They are listed below but left out of the totals.`
                : undefined
            }
          />
          <Banner
            variant="warning"
            className="mt-4"
            message={
              report.truncated
                ? 'This selection is very large; only the first 5,000 expenses are included. Narrow the date range to see everything.'
                : undefined
            }
          />

          {report.rows.length ? (
            <div className="mt-6 grid gap-6 xl:grid-cols-[420px_1fr]">
              <Reveal variants={fadeUp}>
                <Card>
                  <h2 className="text-xl font-bold">By category</h2>
                  <div className="mt-4 grid gap-4">
                    {report.byCategory.map((line) => {
                      const share = report.total > 0 ? (line.total / report.total) * 100 : 0;
                      return (
                        <div key={line.key}>
                          <div className="flex items-baseline justify-between gap-3 text-sm">
                            <span className="font-semibold">{line.name}</span>
                            <span className="font-semibold tabular-nums">
                              {formatAmount(line.total, home)}
                            </span>
                          </div>
                          <div
                            className="mt-1.5 h-2 overflow-hidden rounded-full bg-vera-surface-muted"
                            role="img"
                            aria-label={`${line.name}: ${Math.round(share)}% of the total`}
                          >
                            <div
                              className="h-full rounded-full bg-vera-primary"
                              style={{ width: `${Math.min(100, share)}%` }}
                            />
                          </div>
                          <p className="mt-1 text-xs text-vera-fg-muted">
                            {line.count} {line.count === 1 ? 'expense' : 'expenses'} ·{' '}
                            {Math.round(share)}%
                            {line.unconverted ? ` · ${line.unconverted} not converted` : ''}
                          </p>
                        </div>
                      );
                    })}
                  </div>
                </Card>
              </Reveal>

              <Reveal variants={fadeUp} delay={0.05}>
                <Card>
                  <h2 className="text-xl font-bold">Expenses</h2>
                  <div className="mt-4 overflow-x-auto">
                    <table className="w-full min-w-[640px] text-left text-sm">
                      <thead className="text-xs uppercase tracking-wide text-vera-fg-muted">
                        <tr className="border-b border-vera-border">
                          <th className="py-2 pr-3 font-semibold">Date</th>
                          <th className="py-2 pr-3 font-semibold">Merchant</th>
                          <th className="py-2 pr-3 font-semibold">Category</th>
                          <th className="py-2 pr-3 font-semibold">Scope</th>
                          <th className="py-2 pr-3 text-right font-semibold">Amount</th>
                          <th className="py-2 text-right font-semibold">{home}</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-vera-border">
                        {report.rows.slice(0, LINES_ON_PAGE).map((row) => (
                          <tr key={row.id}>
                            <td className="whitespace-nowrap py-3 pr-3 text-vera-fg-muted">
                              {formatDate(row.date)}
                            </td>
                            <td className="py-3 pr-3">
                              <span className="font-semibold">{row.merchant}</span>
                              {row.receiptId ? (
                                <Paperclip
                                  className="ml-1.5 inline h-3.5 w-3.5 text-vera-fg-muted"
                                  strokeWidth={1.75}
                                  aria-label="Receipt attached"
                                />
                              ) : null}
                            </td>
                            <td className="py-3 pr-3">
                              {names.get(row.category) ?? humaniseKey(row.category)}
                            </td>
                            <td className="py-3 pr-3 capitalize text-vera-fg-muted">{row.scope}</td>
                            <td className="whitespace-nowrap py-3 pr-3 text-right tabular-nums">
                              {formatAmount(row.amount, row.currency)}
                            </td>
                            <td className="whitespace-nowrap py-3 text-right font-semibold tabular-nums">
                              {row.homeAmount === null ? (
                                <span className="text-vera-warning" title="No exchange rate yet">
                                  —
                                </span>
                              ) : (
                                formatAmount(row.homeAmount, home)
                              )}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  {report.rows.length > LINES_ON_PAGE ? (
                    <p className="mt-4 text-sm text-vera-fg-muted">
                      Showing the first {LINES_ON_PAGE} of {report.rows.length} expenses. The PDF
                      and CSV include all of them.
                    </p>
                  ) : null}
                </Card>
              </Reveal>
            </div>
          ) : (
            <Card className="mt-6">
              <EmptyState
                icon={<Receipt className="h-6 w-6" strokeWidth={1.75} />}
                title="No expenses in this selection"
                body="Try a wider date range, another scope, or all categories."
              />
            </Card>
          )}
        </>
      ) : null}
    </main>
  );
}
