import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * The expense report: one selection (date range, scope, category) read once
 * and rendered three ways — the page, the CSV and the PDF — so the three can
 * never disagree about what is in it.
 *
 * Totals are in the user's home currency, using `home_amount`, which the
 * database fills from the ECB rate for the transaction's date (see migration
 * 20260925140000_money_fx_conversion.sql). A foreign-currency row with no rate
 * yet has no home amount: it is listed, counted as "not converted", and left
 * out of the totals rather than added in at a guessed rate.
 */

export type ReportScope = 'all' | 'business' | 'personal';

export interface ReportFilters {
  from: string;
  to: string;
  scope: ReportScope;
  /** A category key, or null for every category. */
  category: string | null;
}

export interface ReportRow {
  id: string;
  date: string;
  merchant: string;
  category: string;
  scope: 'business' | 'personal';
  amount: number;
  currency: string;
  /** In the home currency; null when no rate was available. */
  homeAmount: number | null;
  notes: string;
  receiptId: string | null;
  source: string;
}

export interface CategoryTotal {
  key: string;
  name: string;
  count: number;
  /** Sum of converted rows, home currency. */
  total: number;
  /** Rows in this category that could not be converted. */
  unconverted: number;
}

export interface Report {
  filters: ReportFilters;
  homeCurrency: string;
  rows: ReportRow[];
  byCategory: CategoryTotal[];
  total: number;
  unconvertedCount: number;
  receiptCount: number;
  /** True when the selection had more rows than MAX_REPORT_ROWS. */
  truncated: boolean;
  categories: { key: string; name: string }[];
}

/** Enough for a year of heavy use; beyond it the page asks for a narrower range. */
export const MAX_REPORT_ROWS = 5000;
// PostgREST returns at most 1,000 rows per request on Supabase by default.
const PAGE_SIZE = 1000;

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const CURRENCY = /^[A-Z]{3}$/;

function isRealDate(value: string | undefined | null): value is string {
  if (!value || !DATE.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

/** `YYYY-MM-DD` from local date parts; `toISOString()` would shift the day east of UTC. */
export function isoDate(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

type ParamSource = URLSearchParams | Record<string, string | string[] | undefined>;

function param(source: ParamSource, key: string): string | undefined {
  if (source instanceof URLSearchParams) return source.get(key) ?? undefined;
  const value = source[key];
  return Array.isArray(value) ? value[0] : value;
}

/**
 * Filters from a query string, with every value validated: unknown scopes
 * become "all", bad dates fall back to this month, and a reversed range is
 * swapped rather than returning nothing.
 */
export function parseReportFilters(source: ParamSource, today = new Date()): ReportFilters {
  const monthStart = isoDate(new Date(today.getFullYear(), today.getMonth(), 1));
  let from = param(source, 'from');
  let to = param(source, 'to');
  from = isRealDate(from) ? from : monthStart;
  to = isRealDate(to) ? to : isoDate(today);
  if (from > to) [from, to] = [to, from];

  const scopeValue = param(source, 'scope');
  const scope: ReportScope =
    scopeValue === 'business' || scopeValue === 'personal' ? scopeValue : 'all';
  const categoryValue = param(source, 'category')?.trim();
  const category =
    categoryValue && categoryValue !== 'all' && categoryValue.length <= 60 ? categoryValue : null;
  return { from, to, scope, category };
}

/** The same selection as a query string, for the download links and range presets. */
export function filtersToQuery(filters: ReportFilters): string {
  const params = new URLSearchParams({ from: filters.from, to: filters.to, scope: filters.scope });
  if (filters.category) params.set('category', filters.category);
  return params.toString();
}

/** Mirrors public.money_home_currency: tolerant of quotes and case, EUR when unset. */
export function normaliseCurrency(value: string | null | undefined): string {
  const code = (value ?? '')
    .trim()
    .replace(/^"+|"+$/g, '')
    .toUpperCase();
  return CURRENCY.test(code) ? code : 'EUR';
}

/** "eating_out" → "Eating out", for keys with no row in money_categories. */
export function humaniseKey(key: string): string {
  const words = key.replace(/_/g, ' ').trim();
  return words ? words[0].toUpperCase() + words.slice(1) : 'Uncategorised';
}

const cents = (value: number) => Math.round(value * 100);

/** Totals per category, largest first. Money is summed in integer cents. */
export function summarise(
  rows: ReportRow[],
  names: Map<string, string>,
): Pick<Report, 'byCategory' | 'total' | 'unconvertedCount' | 'receiptCount'> {
  const groups = new Map<string, { count: number; cents: number; unconverted: number }>();
  let totalCents = 0;
  let unconvertedCount = 0;
  let receiptCount = 0;
  for (const row of rows) {
    const group = groups.get(row.category) ?? { count: 0, cents: 0, unconverted: 0 };
    group.count++;
    if (row.homeAmount === null) {
      group.unconverted++;
      unconvertedCount++;
    } else {
      group.cents += cents(row.homeAmount);
      totalCents += cents(row.homeAmount);
    }
    if (row.receiptId) receiptCount++;
    groups.set(row.category, group);
  }
  const byCategory = [...groups.entries()]
    .map(([key, group]) => ({
      key,
      name: names.get(key) ?? humaniseKey(key),
      count: group.count,
      total: group.cents / 100,
      unconverted: group.unconverted,
    }))
    .sort((a, b) => b.total - a.total || a.name.localeCompare(b.name));
  return { byCategory, total: totalCents / 100, unconvertedCount, receiptCount };
}

interface TransactionRecord {
  id: string;
  transaction_date: string;
  merchant: string;
  category: string;
  scope: 'business' | 'personal' | null;
  amount: number | string;
  currency: string | null;
  home_amount: number | string | null;
  notes: string | null;
  receipt_id: string | null;
  source: string | null;
}

export function toReportRow(record: TransactionRecord, homeCurrency: string): ReportRow {
  const amount = Number(record.amount);
  const currency = normaliseCurrency(record.currency);
  // Rows saved before the conversion trigger existed have no home_amount;
  // in the home currency that is simply the amount.
  const homeAmount =
    record.home_amount !== null && record.home_amount !== undefined
      ? Number(record.home_amount)
      : currency === homeCurrency
        ? amount
        : null;
  return {
    id: record.id,
    date: record.transaction_date,
    merchant: record.merchant,
    category: record.category,
    scope: record.scope === 'business' ? 'business' : 'personal',
    amount,
    currency,
    homeAmount,
    notes: record.notes ?? '',
    receiptId: record.receipt_id,
    source: record.source ?? 'manual',
  };
}

/**
 * Reads the selection for the signed-in user. Takes the request-scoped
 * client, so row security still applies on top of the explicit user filter.
 *
 * The client is untyped here on purpose: this reads columns added by the
 * receipts foundation migration, which the generated Database types may not
 * include yet.
 */
export async function loadReport(
  client: SupabaseClient,
  userId: string,
  filters: ReportFilters,
): Promise<Report> {
  const [{ data: setting }, { data: categoryRows }] = await Promise.all([
    client
      .from('money_settings')
      .select('value')
      .eq('user_id', userId)
      .eq('key', 'homeCurrency')
      .is('deleted_at', null)
      .maybeSingle(),
    client
      .from('money_categories')
      .select('key, name, sort_order')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('sort_order', { ascending: true }),
  ]);
  const homeCurrency = normaliseCurrency((setting as { value?: string } | null)?.value);
  const categories = ((categoryRows ?? []) as { key: string; name: string }[]).map((row) => ({
    key: row.key,
    name: row.name,
  }));
  const names = new Map(categories.map((row) => [row.key, row.name]));

  const records: TransactionRecord[] = [];
  let truncated = false;
  for (let offset = 0; offset < MAX_REPORT_ROWS + 1; offset += PAGE_SIZE) {
    let query = client
      .from('money_transactions')
      .select(
        'id, transaction_date, merchant, category, scope, amount, currency, home_amount, notes, receipt_id, source',
      )
      .eq('user_id', userId)
      .eq('direction', 'expense')
      .is('deleted_at', null)
      .gte('transaction_date', filters.from)
      .lte('transaction_date', filters.to);
    if (filters.scope !== 'all') query = query.eq('scope', filters.scope);
    if (filters.category) query = query.eq('category', filters.category);
    const { data, error } = await query
      .order('transaction_date', { ascending: true })
      .order('id', { ascending: true })
      .range(offset, offset + PAGE_SIZE - 1);
    if (error) throw new Error(`Could not load transactions: ${error.message}`);
    const page = (data ?? []) as TransactionRecord[];
    records.push(...page);
    if (page.length < PAGE_SIZE) break;
  }
  if (records.length > MAX_REPORT_ROWS) {
    truncated = true;
    records.length = MAX_REPORT_ROWS;
  }

  const rows = records.map((record) => toReportRow(record, homeCurrency));
  return {
    filters,
    homeCurrency,
    rows,
    categories,
    truncated,
    ...summarise(rows, names),
  };
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

const formatters = new Map<string, Intl.NumberFormat>();

/** Money in any currency. Fixed locale, as formatMoney does, so server and client agree. */
export function formatAmount(amount: number, currency: string): string {
  let formatter = formatters.get(currency);
  if (!formatter) {
    try {
      formatter = new Intl.NumberFormat('en-IE', { style: 'currency', currency });
    } catch {
      formatter = new Intl.NumberFormat('en-IE', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      });
    }
    formatters.set(currency, formatter);
  }
  return formatter.format(amount);
}

/** "1 Sep 2026" — unambiguous in both UK and Italian reading. */
export function formatDate(value: string): string {
  const [year, month, day] = value.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day)).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    timeZone: 'UTC',
  });
}

export const SCOPE_LABEL: Record<ReportScope, string> = {
  all: 'Business and personal',
  business: 'Business',
  personal: 'Personal',
};

export function categoryLabel(report: Report): string {
  if (!report.filters.category) return 'All categories';
  return (
    report.categories.find((row) => row.key === report.filters.category)?.name ??
    humaniseKey(report.filters.category)
  );
}

export function reportFileName(filters: ReportFilters, extension: 'csv' | 'pdf'): string {
  const scope = filters.scope === 'all' ? '' : `-${filters.scope}`;
  return `expenses-${filters.from}-to-${filters.to}${scope}.${extension}`;
}

// ---------------------------------------------------------------------------
// CSV
// ---------------------------------------------------------------------------

/**
 * One cell. Text that a spreadsheet would run as a formula (a merchant name
 * starting with "=", "+", "-" or "@", as typed or as read off a receipt) is
 * prefixed with an apostrophe, so opening the export cannot execute it.
 */
function csvCell(value: string | number | null, kind: 'text' | 'number' = 'text'): string {
  if (value === null) return '';
  let text = String(value);
  if (kind === 'text' && /^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/** Plain decimal with a dot, no grouping: what every spreadsheet reads as a number. */
const plain = (value: number) => value.toFixed(2);

export function reportToCsv(report: Report): string {
  const names = new Map(report.categories.map((row) => [row.key, row.name]));
  const header = [
    'Date',
    'Merchant',
    'Category',
    'Category key',
    'Scope',
    'Amount',
    'Currency',
    `Amount (${report.homeCurrency})`,
    'Receipt',
    'Source',
    'Notes',
  ];
  const lines = [header.map((cell) => csvCell(cell)).join(',')];
  for (const row of report.rows) {
    lines.push(
      [
        csvCell(row.date),
        csvCell(row.merchant),
        csvCell(names.get(row.category) ?? humaniseKey(row.category)),
        csvCell(row.category),
        csvCell(row.scope),
        csvCell(plain(row.amount), 'number'),
        csvCell(row.currency),
        csvCell(row.homeAmount === null ? null : plain(row.homeAmount), 'number'),
        csvCell(row.receiptId ? 'yes' : 'no'),
        csvCell(row.source),
        csvCell(row.notes),
      ].join(','),
    );
  }
  // Byte-order mark so Excel opens the UTF-8 (accented merchants, €) correctly.
  return `﻿${lines.join('\r\n')}\r\n`;
}
