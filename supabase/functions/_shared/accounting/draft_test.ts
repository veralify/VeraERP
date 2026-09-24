import { assertEquals, assertThrows } from 'jsr:@std/assert@1';
import {
  buildExpenseDraft,
  centsToString,
  deriveVatRate,
  type MappingRow,
  normalizeRate,
  toCents,
  type TransactionRow,
} from './draft.ts';
import { kindForStatus, parseRetryAfter, tokenBundleFromResponse } from './http.ts';
import { codeChallengeS256 } from './pkce.ts';
import { AccountingError } from './types.ts';

const tx: TransactionRow = {
  id: 'a3200000-0000-0000-0000-000000000001',
  user_id: 'u1',
  transaction_date: '2026-09-20',
  merchant: 'Esselunga',
  amount: 12.5,
  direction: 'expense',
  category: 'groceries',
  notes: '',
  currency: 'EUR',
  tax_amount: 2.25,
  scope: 'business',
  receipt_id: null,
  deleted_at: null,
};

const mappings: MappingRow[] = [
  { kind: 'category', local_key: 'groceries', external_id: '400' },
  { kind: 'category', local_key: 'default', external_id: '499' },
  { kind: 'tax_rate', local_key: '22', external_id: 'IVA22' },
  { kind: 'tax_rate', local_key: '10', external_id: 'IVA10' },
  { kind: 'tax_rate', local_key: 'none', external_id: 'NOVAT' },
  { kind: 'payment_account', local_key: 'default', external_id: 'bank-eur' },
  { kind: 'payment_account', local_key: 'USD', external_id: 'bank-usd' },
];

Deno.test('cents: parse and format without float drift', () => {
  assertEquals(toCents('12.50'), 1250);
  assertEquals(toCents(0.1 + 0.2), 30);
  assertEquals(toCents('10.255'), 1026);
  assertEquals(toCents(12), 1200);
  assertEquals(toCents('abc'), null);
  assertEquals(toCents(null), null);
  assertEquals(centsToString(1250), '12.50');
  assertEquals(centsToString(-2400), '-24.00');
  assertEquals(centsToString(5), '0.05');
});

Deno.test('vat: rates are normalised and derived from rounded cents', () => {
  assertEquals(normalizeRate('22.00'), '22');
  assertEquals(normalizeRate('5,5'.replace(',', '.')), '5.5');
  assertEquals(normalizeRate('20%'), '20');
  assertEquals(normalizeRate(120), null);
  assertEquals(deriveVatRate(1025, 225), '22');
  assertEquals(deriveVatRate(45, 10), '22');
  assertEquals(deriveVatRate(2000, 400), '20');
  assertEquals(deriveVatRate(1000, 0), '0');
  assertEquals(deriveVatRate(0, 10), null);
});

Deno.test('draft: a transaction with a tax amount becomes one mapped line', () => {
  const draft = buildExpenseDraft(tx, mappings, null, { requiresPaymentAccount: true });
  assertEquals(draft.total, '12.50');
  assertEquals(draft.taxTotal, '2.25');
  assertEquals(draft.taxKnown, true);
  assertEquals(draft.paymentAccountId, 'bank-eur');
  assertEquals(draft.lines, [{
    description: 'Esselunga',
    accountId: '400',
    taxCodeId: 'IVA22',
    vatRate: '22',
    net: '10.25',
    tax: '2.25',
    gross: '12.50',
  }]);
});

Deno.test('draft: receipt tax lines split a mixed-rate receipt', () => {
  const draft = buildExpenseDraft(
    { ...tx, amount: '23.20', tax_amount: '3.20', notes: 'weekly shop' },
    mappings,
    {
      id: 'r1',
      image_paths: [],
      extraction: {
        tax_lines: [
          { rate: '22', taxable: '10.00', tax: '2.20' },
          { rate: '10', taxable: '10.00', tax: '1.00' },
        ],
      },
    },
    { requiresPaymentAccount: false },
  );
  assertEquals(draft.lines.map((l) => [l.taxCodeId, l.net, l.tax, l.gross, l.description]), [
    ['IVA22', '10.00', '2.20', '12.20', 'Esselunga — weekly shop (VAT 22%)'],
    ['IVA10', '10.00', '1.00', '11.00', 'Esselunga — weekly shop (VAT 10%)'],
  ]);
});

Deno.test('draft: receipt lines that no longer match the edited amount are ignored', () => {
  const draft = buildExpenseDraft(
    { ...tx, amount: 30, tax_amount: null },
    mappings,
    {
      id: 'r1',
      image_paths: [],
      extraction: { tax_lines: [{ rate: '22', taxable: '10.25', tax: '2.25' }] },
    },
    { requiresPaymentAccount: false },
  );
  assertEquals(draft.lines.length, 1);
  assertEquals(draft.taxKnown, false);
  assertEquals(draft.lines[0].gross, '30.00');
  assertEquals(draft.lines[0].taxCodeId, 'NOVAT');
});

Deno.test('draft: category falls back to the default mapping, payment account by currency', () => {
  const draft = buildExpenseDraft(
    { ...tx, category: 'software', currency: 'USD' },
    mappings,
    null,
    { requiresPaymentAccount: true },
  );
  assertEquals(draft.lines[0].accountId, '499');
  assertEquals(draft.paymentAccountId, 'bank-usd');
});

Deno.test('draft: missing mappings are config errors the user can fix', () => {
  const noCategory = assertThrows(
    () =>
      buildExpenseDraft(tx, mappings.filter((m) => m.kind !== 'category'), null, {
        requiresPaymentAccount: false,
      }),
    AccountingError,
  );
  assertEquals(noCategory.kind, 'config');
  assertEquals(noCategory.retryable, true);
  const noPayment = assertThrows(
    () =>
      buildExpenseDraft(tx, mappings.filter((m) => m.kind !== 'payment_account'), null, {
        requiresPaymentAccount: true,
      }),
    AccountingError,
  );
  assertEquals(noPayment.kind, 'config');
});

Deno.test('http: status → kind, Retry-After and token bundles', () => {
  assertEquals(kindForStatus(401), 'auth');
  assertEquals(kindForStatus(404), 'not_found');
  assertEquals(kindForStatus(429), 'rate_limited');
  assertEquals(kindForStatus(503), 'transient');
  assertEquals(kindForStatus(400), 'permanent');
  assertEquals(parseRetryAfter('120'), 120);
  assertEquals(
    parseRetryAfter('Wed, 21 Oct 2015 07:28:00 GMT', Date.parse('2015-10-21T07:27:00Z')),
    60,
  );
  const now = new Date('2026-09-24T10:00:00Z');
  const bundle = tokenBundleFromResponse({ access_token: 'a', expires_in: 1800 }, {
    access_token: 'old',
    refresh_token: 'keep',
    expires_at: now.toISOString(),
  }, now);
  assertEquals(bundle.expires_at, '2026-09-24T10:30:00.000Z');
  assertEquals(bundle.refresh_token, 'keep');
});

Deno.test('pkce: S256 challenge matches the RFC 7636 example', async () => {
  assertEquals(
    await codeChallengeS256('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
    'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
  );
});
