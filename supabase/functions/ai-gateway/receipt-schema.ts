// ReceiptExtraction v1 — what `receipts-extract` stores and returns — and the
// narrower shape the model is asked to produce.
//
// The two are kept apart on purpose. The model reads the paper: amounts,
// dates, the merchant, a category guess. Everything the server knows better
// (merchant_key, the user's learned rules, duplicates, the arithmetic behind
// `total_mismatch`) is added afterwards, so the model is never trusted with a
// field it cannot see. Both shapes are validated: the model's answer on the
// way in, and the assembled extraction before it is written to the row.
//
// Contract: money-manager-ios/docs/RECEIPTS_CONTRACTS.md §5. The iOS decoder
// is `ReceiptExtraction` in VeralifyCore.

export const RECEIPT_PROMPT_VERSION = 'receipts-v1';

/** Seeded for every user (contract §3); used when a user has none yet. */
export const DEFAULT_CATEGORY_KEYS = [
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

export const DOCUMENT_TYPES = ['receipt', 'invoice', 'scontrino', 'other'] as const;
export const PAYMENT_METHODS = ['card', 'cash', 'other'] as const;
export const SCOPES = ['business', 'personal'] as const;
export const WARNINGS = [
  'total_mismatch',
  'low_confidence',
  'not_a_receipt',
  'multiple_currencies',
] as const;
export const CATEGORY_SOURCES = ['rule', 'model', 'default'] as const;

export type DocumentType = typeof DOCUMENT_TYPES[number];
export type PaymentMethod = typeof PAYMENT_METHODS[number];
export type Scope = typeof SCOPES[number];
export type ReceiptWarning = typeof WARNINGS[number];
export type CategorySource = typeof CATEGORY_SOURCES[number];

/** A read value with the reader's confidence in it, 0…1. */
export type Field<T> = { value: T | null; confidence: number };

export type TaxLine = { rate: string | null; taxable: string | null; tax: string | null };
export type LineItem = {
  description: string;
  quantity: string | null;
  unit_price: string | null;
  amount: string | null;
};

export type ReceiptExtraction = {
  version: '1';
  receipt_id: string;
  document_type: DocumentType;
  merchant: {
    name: Field<string>;
    vat_id: Field<string>;
    address: Field<string>;
    country: Field<string>;
  };
  merchant_key: string;
  date: Field<string>;
  time: Field<string>;
  currency: Field<string>;
  total: Field<string>;
  subtotal: Field<string>;
  tip: Field<string>;
  discount: Field<string>;
  tax_total: Field<string>;
  tax_lines: TaxLine[];
  line_items: LineItem[];
  payment: { method: Field<PaymentMethod>; card_last4: Field<string> };
  receipt_number: Field<string>;
  category: { key: string; confidence: number; source: CategorySource };
  scope_suggestion: Scope | null;
  duplicate_of: string | null;
  warnings: ReceiptWarning[];
  model: string;
  prompt_version: string;
};

/** What the model returns: the paper, read. Values are raw and normalised later. */
export type ModelReceipt = {
  is_receipt: boolean;
  document_type: DocumentType;
  merchant: {
    name: Field<string>;
    vat_id: Field<string>;
    address: Field<string>;
    country: Field<string>;
  };
  date: Field<string>;
  time: Field<string>;
  currency: Field<string>;
  total: Field<string>;
  subtotal: Field<string>;
  tip: Field<string>;
  discount: Field<string>;
  tax_total: Field<string>;
  tax_lines: TaxLine[];
  line_items: LineItem[];
  payment: { method: Field<PaymentMethod>; card_last4: Field<string> };
  receipt_number: Field<string>;
  category: { key: string; confidence: number };
  scope_suggestion: Scope | null;
  warnings: ReceiptWarning[];
};

// ---------------------------------------------------------------------------
// JSON schema sent to the model (strict mode)
// ---------------------------------------------------------------------------

// Strict structured output needs every property listed as required and no
// extra properties anywhere; "optional" is expressed as a nullable type.
const nullableString = { type: ['string', 'null'] };
const confidence = { type: 'number', minimum: 0, maximum: 1 };
const field = (value: Record<string, unknown> = nullableString) => ({
  type: 'object',
  additionalProperties: false,
  required: ['value', 'confidence'],
  properties: { value, confidence },
});
const object = (properties: Record<string, unknown>) => ({
  type: 'object',
  additionalProperties: false,
  required: Object.keys(properties),
  properties,
});

/**
 * The model's answer format. `categoryKeys` becomes an enum, so the model can
 * only pick one of the user's own categories — it cannot invent "Coffee".
 */
export function modelOutputJsonSchema(categoryKeys: readonly string[]): Record<string, unknown> {
  return object({
    is_receipt: { type: 'boolean' },
    document_type: { type: 'string', enum: [...DOCUMENT_TYPES] },
    merchant: object({
      name: field(),
      vat_id: field(),
      address: field(),
      country: field(),
    }),
    date: field(),
    time: field(),
    currency: field(),
    total: field(),
    subtotal: field(),
    tip: field(),
    discount: field(),
    tax_total: field(),
    tax_lines: {
      type: 'array',
      items: object({ rate: nullableString, taxable: nullableString, tax: nullableString }),
    },
    line_items: {
      type: 'array',
      items: object({
        description: { type: 'string' },
        quantity: nullableString,
        unit_price: nullableString,
        amount: nullableString,
      }),
    },
    payment: object({
      method: field({ type: ['string', 'null'], enum: [...PAYMENT_METHODS, null] }),
      card_last4: field(),
    }),
    receipt_number: field(),
    category: object({
      key: { type: 'string', enum: [...categoryKeys] },
      confidence,
    }),
    scope_suggestion: { type: ['string', 'null'], enum: [...SCOPES, null] },
    warnings: { type: 'array', items: { type: 'string', enum: [...WARNINGS] } },
  });
}

// ---------------------------------------------------------------------------
// Validation helpers
// ---------------------------------------------------------------------------

export class SchemaError extends Error {}

type Json = Record<string, unknown>;

const isObject = (v: unknown): v is Json => !!v && typeof v === 'object' && !Array.isArray(v);

function obj(v: unknown, path: string): Json {
  if (!isObject(v)) throw new SchemaError(`${path} must be an object`);
  return v;
}

function arr(v: unknown, path: string): unknown[] {
  if (!Array.isArray(v)) throw new SchemaError(`${path} must be an array`);
  return v;
}

function conf(v: unknown, path: string): number {
  if (typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > 1) {
    throw new SchemaError(`${path} must be a number between 0 and 1`);
  }
  return v;
}

function oneOf<T extends string>(v: unknown, allowed: readonly T[], path: string): T {
  if (typeof v !== 'string' || !allowed.includes(v as T)) {
    throw new SchemaError(`${path} must be one of ${allowed.join(', ')}`);
  }
  return v as T;
}

/**
 * A model value that should be text. Numbers are accepted and stringified —
 * an amount answered as `12.5` is still an answer, and the money normaliser
 * handles it — but objects and booleans are not.
 */
function looseString(v: unknown, path: string): string | null {
  if (v === null || v === undefined) return null;
  if (typeof v === 'number' && Number.isFinite(v)) return String(v);
  if (typeof v !== 'string') throw new SchemaError(`${path} must be a string or null`);
  const trimmed = v.trim();
  return trimmed ? trimmed : null;
}

function looseField(v: unknown, path: string): Field<string> {
  const o = obj(v, path);
  return {
    value: looseString(o.value, `${path}.value`),
    confidence: conf(o.confidence, `${path}.confidence`),
  };
}

// ---------------------------------------------------------------------------
// The model's answer
// ---------------------------------------------------------------------------

/** Validates the model's JSON. Throws `SchemaError`; the router then asks once for a repair. */
export function parseModelReceipt(value: unknown): ModelReceipt {
  const v = obj(value, 'receipt');
  if (typeof v.is_receipt !== 'boolean') throw new SchemaError('is_receipt must be a boolean');
  const merchant = obj(v.merchant, 'merchant');
  const payment = obj(v.payment, 'payment');
  const method = obj(payment.method, 'payment.method');
  const category = obj(v.category, 'category');

  return {
    is_receipt: v.is_receipt,
    document_type: oneOf(v.document_type, DOCUMENT_TYPES, 'document_type'),
    merchant: {
      name: looseField(merchant.name, 'merchant.name'),
      vat_id: looseField(merchant.vat_id, 'merchant.vat_id'),
      address: looseField(merchant.address, 'merchant.address'),
      country: looseField(merchant.country, 'merchant.country'),
    },
    date: looseField(v.date, 'date'),
    time: looseField(v.time, 'time'),
    currency: looseField(v.currency, 'currency'),
    total: looseField(v.total, 'total'),
    subtotal: looseField(v.subtotal, 'subtotal'),
    tip: looseField(v.tip, 'tip'),
    discount: looseField(v.discount, 'discount'),
    tax_total: looseField(v.tax_total, 'tax_total'),
    tax_lines: arr(v.tax_lines ?? [], 'tax_lines').map((line, i) => {
      const l = obj(line, `tax_lines[${i}]`);
      return {
        rate: looseString(l.rate, `tax_lines[${i}].rate`),
        taxable: looseString(l.taxable, `tax_lines[${i}].taxable`),
        tax: looseString(l.tax, `tax_lines[${i}].tax`),
      };
    }),
    line_items: arr(v.line_items ?? [], 'line_items').map((item, i) => {
      const l = obj(item, `line_items[${i}]`);
      return {
        description: looseString(l.description, `line_items[${i}].description`) ?? '',
        quantity: looseString(l.quantity, `line_items[${i}].quantity`),
        unit_price: looseString(l.unit_price, `line_items[${i}].unit_price`),
        amount: looseString(l.amount, `line_items[${i}].amount`),
      };
    }),
    payment: {
      method: {
        value: method.value === null || method.value === undefined
          ? null
          : oneOf(method.value, PAYMENT_METHODS, 'payment.method.value'),
        confidence: conf(method.confidence, 'payment.method.confidence'),
      },
      card_last4: looseField(payment.card_last4, 'payment.card_last4'),
    },
    receipt_number: looseField(v.receipt_number, 'receipt_number'),
    // An unknown key is not a schema failure — worth a repair round trip —
    // just a guess the server replaces with "other". Only its type is checked.
    category: {
      key: typeof category.key === 'string' ? category.key : '',
      confidence: conf(category.confidence, 'category.confidence'),
    },
    scope_suggestion: v.scope_suggestion === null || v.scope_suggestion === undefined
      ? null
      : oneOf(v.scope_suggestion, SCOPES, 'scope_suggestion'),
    // Unknown warnings are dropped rather than rejected, for the same reason.
    warnings: arr(v.warnings ?? [], 'warnings').filter((w): w is ReceiptWarning =>
      typeof w === 'string' && (WARNINGS as readonly string[]).includes(w)
    ),
  };
}

// ---------------------------------------------------------------------------
// ReceiptExtraction v1 — the stored document
// ---------------------------------------------------------------------------

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MONEY = /^-?\d+(\.\d+)?$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const CURRENCY = /^[A-Z]{3}$/;

export const isUuid = (v: unknown): v is string => typeof v === 'string' && UUID.test(v);

function strictString(v: unknown, path: string, pattern?: RegExp): string | null {
  if (v === null) return null;
  if (typeof v !== 'string' || (pattern && !pattern.test(v))) {
    throw new SchemaError(`${path} is not a valid value`);
  }
  return v;
}

function strictField(v: unknown, path: string, pattern?: RegExp): Field<string> {
  const o = obj(v, path);
  return {
    value: strictString(o.value, `${path}.value`, pattern),
    confidence: conf(o.confidence, `${path}.confidence`),
  };
}

/**
 * Validates a complete ReceiptExtraction v1. Run on every extraction before
 * it is written, so a bug in assembly can never store a document the apps
 * cannot decode. `categoryKeys`, when given, must contain the chosen key.
 */
export function parseReceiptExtraction(
  value: unknown,
  categoryKeys?: readonly string[],
): ReceiptExtraction {
  const v = obj(value, 'extraction');
  if (v.version !== '1') throw new SchemaError('version must be "1"');
  if (!isUuid(v.receipt_id)) throw new SchemaError('receipt_id must be a uuid');
  const merchant = obj(v.merchant, 'merchant');
  const payment = obj(v.payment, 'payment');
  const method = obj(payment.method, 'payment.method');
  const category = obj(v.category, 'category');
  if (typeof v.merchant_key !== 'string') throw new SchemaError('merchant_key must be a string');
  if (typeof category.key !== 'string' || !/^[a-z0-9_]{1,40}$/.test(category.key)) {
    throw new SchemaError('category.key must be a category key');
  }
  if (categoryKeys && !categoryKeys.includes(category.key)) {
    throw new SchemaError(`category.key ${category.key} is not one of the user's categories`);
  }
  if (v.duplicate_of !== null && !isUuid(v.duplicate_of)) {
    throw new SchemaError('duplicate_of must be a uuid or null');
  }
  if (typeof v.model !== 'string' || !v.model) throw new SchemaError('model must be a string');
  if (typeof v.prompt_version !== 'string' || !v.prompt_version) {
    throw new SchemaError('prompt_version must be a string');
  }

  return {
    version: '1',
    receipt_id: v.receipt_id,
    document_type: oneOf(v.document_type, DOCUMENT_TYPES, 'document_type'),
    merchant: {
      name: strictField(merchant.name, 'merchant.name'),
      vat_id: strictField(merchant.vat_id, 'merchant.vat_id'),
      address: strictField(merchant.address, 'merchant.address'),
      country: strictField(merchant.country, 'merchant.country', /^[A-Z]{2}$/),
    },
    merchant_key: v.merchant_key,
    date: strictField(v.date, 'date', DATE),
    time: strictField(v.time, 'time', TIME),
    currency: strictField(v.currency, 'currency', CURRENCY),
    total: strictField(v.total, 'total', MONEY),
    subtotal: strictField(v.subtotal, 'subtotal', MONEY),
    tip: strictField(v.tip, 'tip', MONEY),
    discount: strictField(v.discount, 'discount', MONEY),
    tax_total: strictField(v.tax_total, 'tax_total', MONEY),
    tax_lines: arr(v.tax_lines, 'tax_lines').map((line, i) => {
      const l = obj(line, `tax_lines[${i}]`);
      return {
        rate: strictString(l.rate, `tax_lines[${i}].rate`, MONEY),
        taxable: strictString(l.taxable, `tax_lines[${i}].taxable`, MONEY),
        tax: strictString(l.tax, `tax_lines[${i}].tax`, MONEY),
      };
    }),
    line_items: arr(v.line_items, 'line_items').map((item, i) => {
      const l = obj(item, `line_items[${i}]`);
      if (typeof l.description !== 'string') {
        throw new SchemaError(`line_items[${i}].description must be a string`);
      }
      return {
        description: l.description,
        quantity: strictString(l.quantity, `line_items[${i}].quantity`, MONEY),
        unit_price: strictString(l.unit_price, `line_items[${i}].unit_price`, MONEY),
        amount: strictString(l.amount, `line_items[${i}].amount`, MONEY),
      };
    }),
    payment: {
      method: {
        value: method.value === null
          ? null
          : oneOf(method.value, PAYMENT_METHODS, 'payment.method.value'),
        confidence: conf(method.confidence, 'payment.method.confidence'),
      },
      card_last4: strictField(payment.card_last4, 'payment.card_last4', /^\d{4}$/),
    },
    receipt_number: strictField(v.receipt_number, 'receipt_number'),
    category: {
      key: category.key,
      confidence: conf(category.confidence, 'category.confidence'),
      source: oneOf(category.source, CATEGORY_SOURCES, 'category.source'),
    },
    scope_suggestion: v.scope_suggestion === null
      ? null
      : oneOf(v.scope_suggestion, SCOPES, 'scope_suggestion'),
    duplicate_of: v.duplicate_of,
    warnings: arr(v.warnings, 'warnings').map((w, i) => oneOf(w, WARNINGS, `warnings[${i}]`)),
    model: v.model,
    prompt_version: v.prompt_version,
  };
}
