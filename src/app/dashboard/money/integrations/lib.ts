import type { createSupabaseServerClient } from '@lib/supabase/server';
import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * Plain helpers for the integrations page and its actions (no `'use server'`:
 * that directive would require every export to be an async Server Action).
 *
 * The accounting tables are not in the generated `database.types.ts` yet, so
 * queries on them go through an untyped view of the same client and the row
 * shapes are declared here, matching
 * supabase/migrations/20260925090000_money_receipts_sync_foundation.sql.
 */

type TypedClient = Awaited<ReturnType<typeof createSupabaseServerClient>>;

export function untyped(client: TypedClient): SupabaseClient {
  return client as unknown as SupabaseClient;
}

export const PROVIDERS = ['quickbooks', 'xero', 'freeagent', 'fatture_in_cloud'] as const;
export type Provider = (typeof PROVIDERS)[number];

export function isProvider(value: string): value is Provider {
  return (PROVIDERS as readonly string[]).includes(value);
}

export const PROVIDER_INFO: Record<Provider, { name: string; blurb: string }> = {
  quickbooks: {
    name: 'QuickBooks Online',
    blurb: 'Expenses become purchases, with the receipt attached.',
  },
  xero: {
    name: 'Xero',
    blurb: 'Expenses become spend money transactions, with the receipt attached.',
  },
  freeagent: {
    name: 'FreeAgent',
    blurb: 'Expenses become expense claims, with the receipt attached.',
  },
  fatture_in_cloud: {
    name: 'Fatture in Cloud',
    blurb: 'Expenses become received documents (spese), with the receipt attached.',
  },
};

export type ConnectionStatus = 'active' | 'needs_reauth' | 'revoked' | 'error';
export type Scope = 'personal' | 'business';

export interface ConnectionRow {
  id: string;
  provider: Provider;
  external_company_id: string;
  company_name: string;
  country: string | null;
  home_currency: string | null;
  status: ConnectionStatus;
  sync_scope: Scope;
  auto_sync: boolean;
  last_synced_at: string | null;
  last_error: string | null;
  created_at: string;
}

/** Explicit columns: `token_secret_id` is not granted to clients, so `*` would fail. */
export const CONNECTION_COLUMNS =
  'id, provider, external_company_id, company_name, country, home_currency, status, sync_scope, auto_sync, last_synced_at, last_error, created_at';

export type MappingKind = 'category' | 'tax_rate' | 'payment_account';

export interface MappingRow {
  kind: MappingKind;
  local_key: string;
  external_id: string;
  external_name: string;
}

export interface ExternalOption {
  id: string;
  name: string;
  code?: string | null;
  type?: string | null;
}

export interface ExternalTaxCode extends ExternalOption {
  rate: number | null;
}

/** What `accounting-accounts` returns. */
export interface ProviderOptions {
  requires_payment_account: boolean;
  expense_accounts: ExternalOption[];
  tax_codes: ExternalTaxCode[];
  payment_accounts: ExternalOption[];
}

/** The shared category keys (contract §3), with English labels. */
export const CATEGORY_KEYS: { key: string; label: string }[] = [
  { key: 'groceries', label: 'Groceries' },
  { key: 'eating_out', label: 'Eating out' },
  { key: 'transport', label: 'Transport' },
  { key: 'fuel', label: 'Fuel' },
  { key: 'housing', label: 'Housing' },
  { key: 'utilities', label: 'Utilities' },
  { key: 'shopping', label: 'Shopping' },
  { key: 'health', label: 'Health' },
  { key: 'entertainment', label: 'Entertainment' },
  { key: 'travel', label: 'Travel' },
  { key: 'subscriptions', label: 'Subscriptions' },
  { key: 'office_supplies', label: 'Office supplies' },
  { key: 'software', label: 'Software' },
  { key: 'professional_services', label: 'Professional services' },
  { key: 'education', label: 'Education' },
  { key: 'gifts_donations', label: 'Gifts & donations' },
  { key: 'fees_charges', label: 'Fees & charges' },
  { key: 'other', label: 'Other' },
];

/** Mapping key used when no more specific row matches (see _shared/accounting/draft.ts). */
export const DEFAULT_KEY = 'default';
/** tax_rate key for an expense whose VAT is unknown. */
export const UNKNOWN_TAX_KEY = 'none';

/** Common VAT rates by country, so the editor offers them before any tax code is mapped. */
const STANDARD_RATES: Record<string, string[]> = {
  IT: ['22', '10', '5', '4', '0'],
  GB: ['20', '5', '0'],
};

/** "22.0" / 22 → "22"; matches normalizeRate in the worker. */
export function normalizeRate(value: unknown): string | null {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0 || n > 100) return null;
  return String(Number(n.toFixed(2)));
}

/** VAT rate rows for the editor: country defaults, the provider's rates, and anything mapped. */
export function vatRateKeys(
  country: string | null,
  taxCodes: ExternalTaxCode[],
  mappings: MappingRow[],
): string[] {
  const keys = new Set<string>(STANDARD_RATES[country ?? ''] ?? []);
  for (const code of taxCodes) {
    const rate = normalizeRate(code.rate);
    if (rate !== null) keys.add(rate);
  }
  for (const m of mappings) {
    if (m.kind === 'tax_rate' && m.local_key !== UNKNOWN_TAX_KEY) keys.add(m.local_key);
  }
  return [...keys].sort((a, b) => Number(b) - Number(a));
}

/**
 * A mapping choice travels as one select value holding both the provider id
 * and its display name, so saving needs no second round trip to the provider.
 */
export function encodeOption(option: ExternalOption): string {
  return JSON.stringify([option.id, option.name]);
}

export function decodeOption(value: string): { id: string; name: string } | null {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value) as unknown;
    if (
      Array.isArray(parsed) &&
      typeof parsed[0] === 'string' &&
      parsed[0].length > 0 &&
      parsed[0].length <= 500 &&
      typeof parsed[1] === 'string'
    ) {
      return { id: parsed[0], name: parsed[1].slice(0, 200) };
    }
  } catch {
    // Not one of ours: ignored.
  }
  return null;
}

export function optionLabel(option: ExternalOption): string {
  return option.code && !option.name.startsWith(option.code)
    ? `${option.code} · ${option.name}`
    : option.name;
}

export const STATUS_LABEL: Record<ConnectionStatus, string> = {
  active: 'Connected',
  needs_reauth: 'Needs reconnecting',
  revoked: 'Disconnected',
  error: 'Error',
};

/** Messages for `?status=error&error=` from accounting-callback. */
export const CALLBACK_ERRORS: Record<string, string> = {
  denied: 'You cancelled the connection. Nothing was changed.',
  expired_state: 'The connection took too long. Please try again.',
  invalid_state: 'That connection link is no longer valid. Please try again.',
  no_company: 'No company was found on that account.',
  exchange: 'We couldn’t finish connecting. Please try again.',
  provider: 'The provider reported a problem. Please try again.',
  server: 'Something went wrong on our side. Please try again.',
};
