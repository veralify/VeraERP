// Turning a money_transactions row into a provider-neutral ExpenseDraft.
//
// Money is handled in integer cents throughout: `numeric` arrives from
// PostgREST as a JSON number, and 0.1 + 0.2 style float drift would otherwise
// leak into a ledger. Every amount leaves here as a two-place decimal string.

import { AccountingError, type ExpenseDraft, type ExpenseLine } from './types.ts';

export interface TransactionRow {
  id: string;
  user_id: string;
  transaction_date: string;
  merchant: string;
  amount: number | string;
  direction: 'income' | 'expense';
  category: string;
  account?: string | null;
  notes?: string | null;
  currency: string;
  tax_amount: number | string | null;
  scope: 'personal' | 'business';
  receipt_id: string | null;
  deleted_at: string | null;
}

export interface MappingRow {
  kind: 'category' | 'tax_rate' | 'payment_account' | 'currency';
  local_key: string;
  external_id: string;
  external_name?: string | null;
}

export interface ReceiptRow {
  id: string;
  image_paths: string[] | null;
  extraction: unknown;
}

/** The mapping key used when nothing more specific matches. */
export const DEFAULT_MAPPING_KEY = 'default';
/** tax_rate mapping key for an expense whose VAT is not known. */
export const UNKNOWN_TAX_KEY = 'none';

// ---------------------------------------------------------------------------
// Cents
// ---------------------------------------------------------------------------

/** Decimal string or number → integer cents (half away from zero); null if unparseable. */
export function toCents(value: number | string | null | undefined): number | null {
  if (value === null || value === undefined || value === '') return null;
  const text = typeof value === 'number'
    ? (Number.isFinite(value) ? value.toFixed(6) : '')
    : value.trim();
  const match = /^(-)?(\d+)(?:\.(\d*))?$/.exec(text);
  if (!match) return null;
  const [, minus, whole, fraction = ''] = match;
  const padded = (fraction + '000').slice(0, 3);
  let cents = Number(whole) * 100 + Number(padded.slice(0, 2));
  if (Number(padded[2]) >= 5) cents += 1;
  return minus ? -cents : cents;
}

export function centsToString(cents: number): string {
  const sign = cents < 0 ? '-' : '';
  const abs = Math.abs(Math.round(cents));
  return `${sign}${Math.floor(abs / 100)}.${String(abs % 100).padStart(2, '0')}`;
}

// ---------------------------------------------------------------------------
// VAT rates
// ---------------------------------------------------------------------------

/**
 * VAT rates in use across the EU and the UK. A rate derived from rounded
 * cents is snapped onto one of these, so a €0.45 + €0.10 receipt line still
 * maps to the 22% tax code rather than to "22.2".
 */
const STANDARD_RATES = [
  0,
  2.1,
  4,
  5,
  5.5,
  6,
  7,
  8,
  9,
  10,
  12,
  13,
  13.5,
  17,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  27,
];

/** "22.0" / 22 / "22" → "22"; "5.50" → "5.5"; null for anything not a percentage. */
export function normalizeRate(value: unknown): string | null {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(typeof value === 'string' ? value.replace('%', '').trim() : value);
  if (!Number.isFinite(n) || n < 0 || n > 100) return null;
  return String(Number(n.toFixed(2)));
}

/**
 * The VAT rate implied by a net/tax pair. Cents rounding makes the ratio
 * inexact, so every standard rate inside the rounding interval is a
 * candidate and the one closest to the raw ratio wins.
 */
export function deriveVatRate(netCents: number, taxCents: number): string | null {
  if (taxCents === 0) return '0';
  if (netCents <= 0 || taxCents < 0) return null;
  const raw = (taxCents / netCents) * 100;
  const low = ((taxCents - 0.5) / netCents) * 100;
  const high = ((taxCents + 0.5) / netCents) * 100;
  const candidates = STANDARD_RATES.filter((rate) => rate >= low && rate <= high);
  if (candidates.length) {
    const best = candidates.reduce((a, b) => (Math.abs(b - raw) < Math.abs(a - raw) ? b : a));
    return String(best);
  }
  return normalizeRate(Math.round(raw * 10) / 10);
}

interface TaxLine {
  rate: string | null;
  netCents: number;
  taxCents: number;
}

/**
 * Tax lines from the receipt extraction (contract §5), when they add up to
 * the transaction. If the user changed the amount or the tax after reading
 * the receipt, the receipt no longer describes the transaction and is ignored.
 */
export function receiptTaxLines(
  extraction: unknown,
  totalCents: number,
  userTaxCents: number | null,
): TaxLine[] | null {
  const lines = (extraction as { tax_lines?: unknown } | null)?.tax_lines;
  if (!Array.isArray(lines) || lines.length === 0) return null;
  const parsed: TaxLine[] = [];
  for (const line of lines) {
    const row = (line ?? {}) as Record<string, unknown>;
    const net = toCents(row.taxable as string);
    const tax = toCents(row.tax as string);
    if (net === null || tax === null || net < 0 || tax < 0) return null;
    parsed.push({
      rate: normalizeRate(row.rate) ?? deriveVatRate(net, tax),
      netCents: net,
      taxCents: tax,
    });
  }
  const gross = parsed.reduce((sum, l) => sum + l.netCents + l.taxCents, 0);
  const tax = parsed.reduce((sum, l) => sum + l.taxCents, 0);
  // One cent of rounding per line is normal on printed receipts.
  if (Math.abs(gross - totalCents) > parsed.length) return null;
  if (userTaxCents !== null && Math.abs(userTaxCents - tax) > parsed.length) return null;
  // Absorb the rounding into the last line's net so the lines sum to the total exactly.
  parsed[parsed.length - 1].netCents += totalCents - gross;
  if (parsed[parsed.length - 1].netCents < 0) return null;
  return parsed;
}

// ---------------------------------------------------------------------------
// Mappings
// ---------------------------------------------------------------------------

export function findMapping(
  mappings: MappingRow[],
  kind: MappingRow['kind'],
  ...keys: (string | null | undefined)[]
): MappingRow | null {
  for (const key of keys) {
    if (!key) continue;
    const hit = mappings.find((m) => m.kind === kind && m.local_key === key);
    if (hit) return hit;
  }
  return null;
}

export interface DraftOptions {
  requiresPaymentAccount: boolean;
}

/**
 * The expense as it should exist at the provider right now. Throws a
 * `config` AccountingError when a mapping the user has to choose is missing.
 */
export function buildExpenseDraft(
  tx: TransactionRow,
  mappings: MappingRow[],
  receipt: ReceiptRow | null,
  options: DraftOptions,
): ExpenseDraft {
  const totalCents = toCents(tx.amount);
  if (totalCents === null || totalCents < 0) {
    throw new AccountingError('permanent', `Transaction ${tx.id} has an invalid amount`);
  }
  const account = findMapping(mappings, 'category', tx.category, DEFAULT_MAPPING_KEY);
  if (!account) {
    throw new AccountingError(
      'config',
      `No expense account is mapped for category "${tx.category}" (and no default). Set one in Money → Integrations.`,
    );
  }
  const payment = findMapping(mappings, 'payment_account', tx.currency, DEFAULT_MAPPING_KEY);
  if (!payment && options.requiresPaymentAccount) {
    throw new AccountingError(
      'config',
      'No payment account is mapped. Choose the account expenses are paid from in Money → Integrations.',
    );
  }

  const userTax = toCents(tx.tax_amount);
  const fromReceipt = receipt ? receiptTaxLines(receipt.extraction, totalCents, userTax) : null;
  const taxKnown = fromReceipt !== null || userTax !== null;
  const taxLines: TaxLine[] = fromReceipt ?? [
    {
      rate: userTax === null ? null : deriveVatRate(totalCents - userTax, userTax),
      netCents: totalCents - (userTax ?? 0),
      taxCents: userTax ?? 0,
    },
  ];
  if (taxLines.some((l) => l.netCents < 0)) {
    throw new AccountingError('permanent', `Transaction ${tx.id} has more tax than its total`);
  }

  const merchant = tx.merchant.trim() || 'Expense';
  const notes = (tx.notes ?? '').trim();
  const description = notes ? `${merchant} — ${notes}` : merchant;
  const lines: ExpenseLine[] = taxLines.map((line) => {
    const taxMapping = findMapping(
      mappings,
      'tax_rate',
      taxKnown ? line.rate : UNKNOWN_TAX_KEY,
    );
    return {
      description: taxLines.length > 1 && line.rate !== null
        ? `${description} (VAT ${line.rate}%)`
        : description,
      accountId: account.external_id,
      taxCodeId: taxMapping?.external_id ?? null,
      vatRate: taxKnown ? line.rate : null,
      net: centsToString(line.netCents),
      tax: centsToString(line.taxCents),
      gross: centsToString(line.netCents + line.taxCents),
    };
  });

  return {
    transactionId: tx.id,
    date: tx.transaction_date,
    merchant,
    description,
    currency: tx.currency || 'EUR',
    total: centsToString(totalCents),
    taxTotal: centsToString(taxLines.reduce((sum, l) => sum + l.taxCents, 0)),
    taxKnown,
    lines,
    paymentAccountId: payment?.external_id ?? null,
  };
}

/** Short, stable reference shown in the provider ("VL-1a2b3c4d"). */
export function draftReference(draft: ExpenseDraft): string {
  return `VL-${draft.transactionId.replaceAll('-', '').slice(0, 8)}`;
}
