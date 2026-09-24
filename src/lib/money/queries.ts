import type { Database } from '@lib/api/database.types';
import type { createSupabaseServerClient } from '@lib/supabase/server';
import { categoryAliases, type TransactionFilters } from './spending';

type SupabaseClient = Awaited<ReturnType<typeof createSupabaseServerClient>>;
export type TransactionRow = Database['public']['Tables']['money_transactions']['Row'];

/**
 * PostgREST caps a response at the project's max-rows (1000 by default), so a
 * year of transactions has to be read in pages or the trend would quietly
 * stop at row 1000. The hard stop keeps a runaway query from holding the
 * render; at that size the page says the figures are partial.
 */
const PAGE_SIZE = 1000;
const MAX_ROWS = 50_000;

export const TRANSACTION_COLUMNS =
  'id, transaction_date, merchant, amount, direction, category, account, notes, currency, home_amount, tax_amount, scope, source, receipt_id';

export type TransactionListRow = Pick<
  TransactionRow,
  | 'id'
  | 'transaction_date'
  | 'merchant'
  | 'amount'
  | 'direction'
  | 'category'
  | 'account'
  | 'notes'
  | 'currency'
  | 'home_amount'
  | 'tax_amount'
  | 'scope'
  | 'source'
  | 'receipt_id'
>;

export interface TransactionRange {
  /** Inclusive "YYYY-MM-DD". */
  from?: string;
  /** Exclusive "YYYY-MM-DD". */
  to?: string;
}

/** The owner's live (not soft-deleted) transactions matching the filters. */
export function transactionQuery(
  supabase: SupabaseClient,
  userId: string,
  range: TransactionRange,
  filters: Omit<TransactionFilters, 'month'> = { category: null, scope: null, direction: null },
) {
  let query = supabase
    .from('money_transactions')
    .select(TRANSACTION_COLUMNS)
    .eq('user_id', userId)
    .is('deleted_at', null);
  if (range.from) query = query.gte('transaction_date', range.from);
  if (range.to) query = query.lt('transaction_date', range.to);
  if (filters.category) query = query.in('category', categoryAliases(filters.category));
  if (filters.scope) query = query.eq('scope', filters.scope);
  if (filters.direction) query = query.eq('direction', filters.direction);
  // `id` breaks ties so paging never repeats or skips rows sharing a date.
  return query.order('transaction_date', { ascending: false }).order('id', { ascending: true });
}

export async function fetchAllTransactions(
  supabase: SupabaseClient,
  userId: string,
  range: TransactionRange,
  filters?: Omit<TransactionFilters, 'month'>,
): Promise<{ rows: TransactionListRow[]; truncated: boolean; error: boolean }> {
  const rows: TransactionListRow[] = [];
  for (let from = 0; from < MAX_ROWS; from += PAGE_SIZE) {
    const { data, error } = await transactionQuery(supabase, userId, range, filters).range(
      from,
      from + PAGE_SIZE - 1,
    );
    if (error) return { rows, truncated: false, error: true };
    rows.push(...(data ?? []));
    if ((data?.length ?? 0) < PAGE_SIZE) return { rows, truncated: false, error: false };
  }
  return { rows, truncated: true, error: false };
}

/** The user's home currency (money_settings `homeCurrency`, synced from iOS); EUR by default. */
export async function getHomeCurrency(supabase: SupabaseClient, userId: string): Promise<string> {
  const { data } = await supabase
    .from('money_settings')
    .select('value')
    .eq('user_id', userId)
    .eq('key', 'homeCurrency')
    .is('deleted_at', null)
    .maybeSingle();
  const value = data?.value?.trim().toUpperCase() ?? '';
  return /^[A-Z]{3}$/.test(value) ? value : 'EUR';
}

/**
 * The user's own category names by key. Built-in keys keep the app's
 * English labels (each client localises those itself, contract §3); a name
 * here only matters for a key the user added.
 */
export async function getCustomCategoryNames(
  supabase: SupabaseClient,
  userId: string,
): Promise<Record<string, string>> {
  const { data } = await supabase
    .from('money_categories')
    .select('key, name')
    .eq('user_id', userId)
    .eq('kind', 'expense')
    .eq('archived', false)
    .is('deleted_at', null)
    .order('sort_order', { ascending: true });
  return Object.fromEntries((data ?? []).map((row) => [row.key, row.name]));
}

export async function getBudgets(supabase: SupabaseClient, userId: string) {
  const { data } = await supabase
    .from('money_budgets')
    .select('id, category_key, monthly_limit, currency')
    .eq('user_id', userId)
    .is('deleted_at', null)
    .order('category_key', { ascending: true });
  return data ?? [];
}

export const RECEIPT_COLUMNS =
  'id, status, source, extraction, merchant_key, receipt_date, total, currency, created_at, transaction_id, image_paths';

export type ReceiptListRow = Pick<
  Database['public']['Tables']['money_receipts']['Row'],
  | 'id'
  | 'status'
  | 'source'
  | 'extraction'
  | 'merchant_key'
  | 'receipt_date'
  | 'total'
  | 'currency'
  | 'created_at'
  | 'transaction_id'
  | 'image_paths'
>;

/**
 * The live transactions the receipts were confirmed into, by id. Fetched
 * separately rather than embedded: receipts and transactions reference each
 * other both ways, so an embed would need a hint per direction, and a
 * soft-deleted transaction has to drop out anyway.
 */
export async function getLinkedTransactions(
  supabase: SupabaseClient,
  userId: string,
  receipts: readonly Pick<ReceiptListRow, 'transaction_id'>[],
) {
  const ids = [...new Set(receipts.map((r) => r.transaction_id).filter((id) => id !== null))];
  if (!ids.length) return new Map<string, TransactionListRow>();
  const { data } = await supabase
    .from('money_transactions')
    .select(TRANSACTION_COLUMNS)
    .eq('user_id', userId)
    .is('deleted_at', null)
    .in('id', ids);
  return new Map((data ?? []).map((row) => [row.id, row]));
}
