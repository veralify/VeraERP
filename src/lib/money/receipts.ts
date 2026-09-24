/**
 * Reads the fields the web shows from a money_receipts row. The row's own
 * columns (receipt_date, total, currency) are written by the gateway after
 * extraction; the merchant name, category and scope suggestion live only in
 * the `extraction` JSON (ReceiptExtraction v1, contract §5), which is
 * untrusted model output — every read here checks the shape before using it.
 *
 * Pure (no aliases, no Supabase) so spending.test.mjs can exercise it.
 */

export type ReceiptStatus = 'uploaded' | 'processing' | 'extracted' | 'confirmed' | 'failed';

export const RECEIPT_STATUSES: readonly ReceiptStatus[] = [
  'uploaded',
  'processing',
  'extracted',
  'confirmed',
  'failed',
];

export const RECEIPT_STATUS_LABELS: Record<ReceiptStatus, string> = {
  uploaded: 'Uploaded',
  processing: 'Reading',
  extracted: 'Needs review',
  confirmed: 'Confirmed',
  failed: 'Couldn’t read',
};

export interface ReceiptRowLike {
  id: string;
  status: ReceiptStatus;
  extraction: unknown;
  merchant_key: string | null;
  receipt_date: string | null;
  total: number | string | null;
  currency: string | null;
  created_at: string;
  transaction_id: string | null;
}

export interface LinkedTransactionLike {
  id: string;
  merchant: string;
  amount: number | string;
  currency: string;
  category: string;
  scope: 'personal' | 'business';
  transaction_date: string;
}

export interface ReceiptView {
  merchant: string | null;
  /** "YYYY-MM-DD" — the receipt's date, else the day it was uploaded. */
  date: string;
  dateIsUpload: boolean;
  total: number | null;
  currency: string | null;
  /** The confirmed transaction's category, else the AI's suggestion. */
  category: string | null;
  scope: 'personal' | 'business' | null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** `extraction.a.b...` when every step is an object, else undefined. */
function pick(root: unknown, path: readonly string[]): unknown {
  let node = root;
  for (const key of path) {
    if (!isRecord(node)) return undefined;
    node = node[key];
  }
  return node;
}

function text(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

export function receiptView(
  receipt: ReceiptRowLike,
  transaction: LinkedTransactionLike | null,
): ReceiptView {
  const extraction = receipt.extraction;
  const merchant =
    transaction?.merchant ||
    text(pick(extraction, ['merchant', 'name', 'value'])) ||
    receipt.merchant_key ||
    null;

  const extractedScope = pick(extraction, ['scope_suggestion']);
  const scope =
    transaction?.scope ??
    (extractedScope === 'business' || extractedScope === 'personal' ? extractedScope : null);

  const receiptDate = receipt.receipt_date ?? transaction?.transaction_date ?? null;
  const total =
    receipt.total !== null && receipt.total !== ''
      ? Number(receipt.total)
      : transaction
        ? Number(transaction.amount)
        : null;

  return {
    merchant,
    date: receiptDate ?? receipt.created_at.slice(0, 10),
    dateIsUpload: receiptDate === null,
    total: total !== null && Number.isFinite(total) ? total : null,
    currency: receipt.currency ?? transaction?.currency ?? null,
    category: transaction?.category || text(pick(extraction, ['category', 'key'])),
    scope,
  };
}

/** Pages in upload order: ".../2.jpg" sorts before ".../10.jpg". */
export function sortImagePaths(paths: readonly string[]): string[] {
  const page = (path: string) => Number(path.match(/(\d+)\.[a-z]+$/i)?.[1] ?? 0);
  return [...paths].sort((a, b) => page(a) - page(b) || a.localeCompare(b));
}
