/**
 * Pure spending maths for the money dashboard, budgets, receipts and CSV
 * export. No Supabase, no React, no path aliases — so it runs unchanged under
 * `node --experimental-strip-types` (see spending.test.mjs) as well as in Next.
 *
 * Currency rule (the reason most helpers take `home`): a transaction counts
 * toward home-currency totals when it has a `home_amount` (converted by the
 * FX job) or is already in the home currency. Anything else stays in its own
 * currency bucket and is reported separately — adding USD to EUR at 1:1 would
 * be silently wrong, and dropping it would hide spending.
 */

// ---------------------------------------------------------------------------
// Categories (contract §3)
// ---------------------------------------------------------------------------

export const CATEGORY_KEYS = [
  'groceries',
  'eating_out',
  'transport',
  'fuel',
  'housing',
  'utilities',
  'shopping',
  'health',
  'entertainment',
  'travel',
  'subscriptions',
  'office_supplies',
  'software',
  'professional_services',
  'education',
  'gifts_donations',
  'fees_charges',
  'other',
] as const;

export type CategoryKey = (typeof CATEGORY_KEYS)[number];

export const CATEGORY_LABELS: Record<CategoryKey, string> = {
  groceries: 'Groceries',
  eating_out: 'Eating out',
  transport: 'Transport',
  fuel: 'Fuel',
  housing: 'Housing',
  utilities: 'Utilities',
  shopping: 'Shopping',
  health: 'Health',
  entertainment: 'Entertainment',
  travel: 'Travel',
  subscriptions: 'Subscriptions',
  office_supplies: 'Office supplies',
  software: 'Software',
  professional_services: 'Professional services',
  education: 'Education',
  gifts_donations: 'Gifts & donations',
  fees_charges: 'Fees & charges',
  other: 'Other',
};

/**
 * Category names written before keys existed: the iOS presets (contract §3)
 * and the web form's old free-text default. Rows keep their stored value, so
 * they are mapped on read rather than migrated.
 */
const LEGACY_CATEGORY_KEYS: Record<string, CategoryKey> = {
  general: 'other',
  tools: 'office_supplies',
  food: 'groceries',
  transport: 'transport',
  bills: 'utilities',
  shopping: 'shopping',
  health: 'health',
  uncategorized: 'other',
};

const KEY_PATTERN = /^[a-z0-9_]{1,40}$/;

export function isCategoryKey(value: string): value is CategoryKey {
  return (CATEGORY_KEYS as readonly string[]).includes(value);
}

/**
 * The key a stored category belongs to. Known keys pass through, legacy names
 * map to their key, and anything else (a custom key, or old free text) is
 * kept verbatim so it still groups with itself.
 */
export function normalizeCategoryKey(raw: string | null | undefined): string {
  const value = (raw ?? '').trim();
  if (!value) return 'other';
  if (isCategoryKey(value)) return value;
  return LEGACY_CATEGORY_KEYS[value.toLowerCase()] ?? value;
}

/** Every stored spelling that means `key`, for an exact-match database filter. */
export function categoryAliases(key: string): string[] {
  const aliases = new Set([key]);
  for (const [legacy, target] of Object.entries(LEGACY_CATEGORY_KEYS)) {
    if (target !== key) continue;
    aliases.add(legacy);
    aliases.add(legacy.charAt(0).toUpperCase() + legacy.slice(1));
  }
  return [...aliases];
}

/**
 * English display name. `customNames` holds the user's own categories
 * (money_categories.name by key); a custom key with no name is humanised,
 * and old free text is shown as typed.
 */
export function categoryLabel(key: string, customNames: Record<string, string> = {}): string {
  if (isCategoryKey(key)) return CATEGORY_LABELS[key];
  const custom = customNames[key];
  if (custom) return custom;
  if (KEY_PATTERN.test(key)) {
    const words = key.replace(/_+/g, ' ').trim();
    return words.charAt(0).toUpperCase() + words.slice(1);
  }
  return key;
}

/** Choices for a category picker: the built-in keys, then the user's own. */
export function categoryOptions(
  customNames: Record<string, string> = {},
): { key: string; label: string }[] {
  const builtIn = CATEGORY_KEYS.map((key) => ({ key, label: CATEGORY_LABELS[key] }));
  const custom = Object.keys(customNames)
    .filter((key) => !isCategoryKey(key))
    .map((key) => ({ key, label: categoryLabel(key, customNames) }));
  return [...builtIn, ...custom];
}

// ---------------------------------------------------------------------------
// Months ("YYYY-MM")
// ---------------------------------------------------------------------------

const MONTH_PATTERN = /^(\d{4})-(0[1-9]|1[0-2])$/;

/** The current month from local date parts (not `toISOString`, which is UTC). */
export function currentMonth(now: Date = new Date()): string {
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

export function isMonth(value: string | null | undefined): value is string {
  return typeof value === 'string' && MONTH_PATTERN.test(value);
}

export function parseMonth(value: string | null | undefined, fallback: string): string {
  return isMonth(value) ? value : fallback;
}

export function shiftMonth(month: string, delta: number): string {
  const [year, mon] = month.split('-').map(Number);
  const index = year * 12 + (mon - 1) + delta;
  const nextYear = Math.floor(index / 12);
  return `${nextYear}-${String((index % 12) + 1).padStart(2, '0')}`;
}

/** First day of the month and first day of the next one (exclusive end). */
export function monthBounds(month: string): { start: string; end: string } {
  return { start: `${month}-01`, end: `${shiftMonth(month, 1)}-01` };
}

/** "YYYY-MM" of a "YYYY-MM-DD" date (or an ISO timestamp). */
export function monthOf(date: string): string {
  return date.slice(0, 7);
}

// en-US: en-IE/en-GB abbreviate September as "Sept", which breaks the
// three-letter rhythm of the trend axis.
const longMonth = new Intl.DateTimeFormat('en-US', {
  month: 'long',
  year: 'numeric',
  timeZone: 'UTC',
});
const shortMonth = new Intl.DateTimeFormat('en-US', { month: 'short', timeZone: 'UTC' });

export function monthLabel(month: string, style: 'long' | 'short' = 'long'): string {
  const [year, mon] = month.split('-').map(Number);
  const date = new Date(Date.UTC(year, mon - 1, 1));
  return (style === 'long' ? longMonth : shortMonth).format(date);
}

/** The `count` months ending with `endMonth`, oldest first. */
export function monthsEnding(endMonth: string, count: number): string[] {
  return Array.from({ length: count }, (_, i) => shiftMonth(endMonth, i - (count - 1)));
}

// ---------------------------------------------------------------------------
// Amounts
// ---------------------------------------------------------------------------

export type Direction = 'income' | 'expense';

export interface TransactionLike {
  transaction_date: string;
  amount: number | string;
  direction: Direction;
  category: string;
  currency: string;
  home_amount: number | string | null;
}

export interface ResolvedAmount {
  currency: string;
  value: number;
  /** True when the value is in the home currency (natively or converted). */
  inHome: boolean;
}

export function resolveAmount(tx: TransactionLike, home: string): ResolvedAmount {
  if (tx.home_amount !== null && tx.home_amount !== '' && Number.isFinite(Number(tx.home_amount))) {
    return { currency: home, value: Number(tx.home_amount), inHome: true };
  }
  const currency = tx.currency || home;
  return { currency, value: Number(tx.amount) || 0, inHome: currency === home };
}

// Sums run in integer hundredths so a month of 0.1s doesn't drift to x.x0000001.
const toCents = (value: number) => Math.round(value * 100);
const fromCents = (cents: number) => cents / 100;

export interface CurrencyBucket {
  currency: string;
  income: number;
  spending: number;
}

export interface CategoryTotal {
  key: string;
  total: number;
  count: number;
}

export interface Summary {
  /** Home-currency totals. */
  income: number;
  spending: number;
  net: number;
  count: number;
  /** Home-currency spending by category, largest first. */
  byCategory: CategoryTotal[];
  /** Totals that could not be expressed in the home currency, by currency. */
  unconverted: CurrencyBucket[];
}

export function summarize(txs: readonly TransactionLike[], home: string): Summary {
  let income = 0;
  let spending = 0;
  const categories = new Map<string, { cents: number; count: number }>();
  const other = new Map<string, { income: number; spending: number }>();

  for (const tx of txs) {
    const amount = resolveAmount(tx, home);
    const cents = toCents(amount.value);
    if (!amount.inHome) {
      const bucket = other.get(amount.currency) ?? { income: 0, spending: 0 };
      if (tx.direction === 'income') bucket.income += cents;
      else bucket.spending += cents;
      other.set(amount.currency, bucket);
      continue;
    }
    if (tx.direction === 'income') {
      income += cents;
    } else {
      spending += cents;
      const key = normalizeCategoryKey(tx.category);
      const entry = categories.get(key) ?? { cents: 0, count: 0 };
      entry.cents += cents;
      entry.count += 1;
      categories.set(key, entry);
    }
  }

  return {
    income: fromCents(income),
    spending: fromCents(spending),
    net: fromCents(income - spending),
    count: txs.length,
    byCategory: [...categories.entries()]
      .map(([key, entry]) => ({ key, total: fromCents(entry.cents), count: entry.count }))
      .sort((a, b) => b.total - a.total || a.key.localeCompare(b.key)),
    unconverted: [...other.entries()]
      .map(([currency, bucket]) => ({
        currency,
        income: fromCents(bucket.income),
        spending: fromCents(bucket.spending),
      }))
      .sort((a, b) => a.currency.localeCompare(b.currency)),
  };
}

export interface TrendPoint {
  month: string;
  income: number;
  spending: number;
  net: number;
}

/** Home-currency income and spending per month for the `count` months ending `endMonth`. */
export function monthlyTrend(
  txs: readonly TransactionLike[],
  home: string,
  endMonth: string,
  count = 12,
): TrendPoint[] {
  const months = monthsEnding(endMonth, count);
  const totals = new Map(months.map((m) => [m, { income: 0, spending: 0 }]));
  for (const tx of txs) {
    const bucket = totals.get(monthOf(tx.transaction_date));
    if (!bucket) continue;
    const amount = resolveAmount(tx, home);
    if (!amount.inHome) continue;
    if (tx.direction === 'income') bucket.income += toCents(amount.value);
    else bucket.spending += toCents(amount.value);
  }
  return months.map((month) => {
    const bucket = totals.get(month) ?? { income: 0, spending: 0 };
    return {
      month,
      income: fromCents(bucket.income),
      spending: fromCents(bucket.spending),
      net: fromCents(bucket.income - bucket.spending),
    };
  });
}

/** Clean axis ticks from 0 (0 / 500 / 1,000 …) whose last value covers `max`. */
export function niceTicks(max: number, count = 4): number[] {
  if (!(max > 0)) return [0, 1];
  const raw = max / count;
  const magnitude = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 2.5, 5, 10].map((m) => m * magnitude).find((s) => s >= raw) ?? raw;
  const ticks: number[] = [];
  for (let i = 0; ticks.length === 0 || ticks[ticks.length - 1] < max; i++) {
    ticks.push(Math.round(i * step * 100) / 100);
  }
  return ticks;
}

/** Signed % change, or null when there is no base to compare against. */
export function percentChange(current: number, previous: number): number | null {
  if (!previous) return null;
  return ((current - previous) / Math.abs(previous)) * 100;
}

// ---------------------------------------------------------------------------
// Budgets
// ---------------------------------------------------------------------------

export interface BudgetLike {
  id: string;
  category_key: string;
  monthly_limit: number | string;
  currency: string;
}

export type BudgetState = 'ok' | 'near' | 'over';

export interface BudgetProgress {
  id: string;
  key: string;
  limit: number;
  currency: string;
  spent: number;
  remaining: number;
  /** spent / limit; can exceed 1. */
  ratio: number;
  state: BudgetState;
}

/** A budget turns "near" at 80% of its limit and "over" once spending passes it. */
export const BUDGET_NEAR_RATIO = 0.8;

/**
 * Progress of each budget over `txs` (already limited to one month). Spending
 * is matched in the budget's own currency: a home-currency budget sees
 * converted spending too; a foreign-currency budget sees only unconverted
 * spending in that currency.
 */
export function budgetProgress(
  budgets: readonly BudgetLike[],
  txs: readonly TransactionLike[],
  home: string,
): BudgetProgress[] {
  const spent = new Map<string, number>();
  for (const tx of txs) {
    if (tx.direction !== 'expense') continue;
    const amount = resolveAmount(tx, home);
    const id = `${normalizeCategoryKey(tx.category)}|${amount.currency}`;
    spent.set(id, (spent.get(id) ?? 0) + toCents(amount.value));
  }
  return budgets
    .map((budget) => {
      const limit = Number(budget.monthly_limit) || 0;
      const cents = spent.get(`${budget.category_key}|${budget.currency}`) ?? 0;
      const used = fromCents(cents);
      const ratio = limit > 0 ? used / limit : 0;
      const state: BudgetState = ratio > 1 ? 'over' : ratio >= BUDGET_NEAR_RATIO ? 'near' : 'ok';
      return {
        id: budget.id,
        key: budget.category_key,
        limit,
        currency: budget.currency,
        spent: used,
        remaining: fromCents(toCents(limit) - cents),
        ratio,
        state,
      };
    })
    .sort((a, b) => b.ratio - a.ratio || a.key.localeCompare(b.key));
}

// ---------------------------------------------------------------------------
// Transaction filters (shared by the transactions page and the CSV export)
// ---------------------------------------------------------------------------

export type Scope = 'personal' | 'business';

export interface TransactionFilters {
  month: string | null;
  category: string | null;
  scope: Scope | null;
  direction: Direction | null;
}

type ParamValue = string | string[] | undefined;
const first = (value: ParamValue) => (Array.isArray(value) ? value[0] : value);

export function parseTransactionFilters(params: Record<string, ParamValue>): TransactionFilters {
  const month = first(params.month);
  const category = first(params.category)?.trim();
  const scope = first(params.scope);
  const direction = first(params.direction);
  return {
    month: isMonth(month) ? month : null,
    category: category && category.length <= 80 ? category : null,
    scope: scope === 'personal' || scope === 'business' ? scope : null,
    direction: direction === 'income' || direction === 'expense' ? direction : null,
  };
}

/** The filters as query-string pairs, omitting empty ones (for links). */
export function filtersToQuery(filters: TransactionFilters): Record<string, string> {
  const query: Record<string, string> = {};
  if (filters.month) query.month = filters.month;
  if (filters.category) query.category = filters.category;
  if (filters.scope) query.scope = filters.scope;
  if (filters.direction) query.direction = filters.direction;
  return query;
}

// ---------------------------------------------------------------------------
// CSV
// ---------------------------------------------------------------------------

/**
 * One RFC 4180 cell. Text that a spreadsheet would run as a formula
 * (leading = + - @, tab or CR) is prefixed with an apostrophe — merchant
 * names come from receipts and e-mail, so they are untrusted. Numbers are
 * written as numbers and never prefixed.
 */
export function csvCell(value: string | number | null | undefined): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : '';
  let text = value;
  if (/^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

export function toCsv(rows: readonly (readonly (string | number | null | undefined)[])[]): string {
  return `${rows.map((row) => row.map(csvCell).join(',')).join('\r\n')}\r\n`;
}
