// receipts-extract: the route end to end against an in-memory database and a
// fake OpenRouter, plus the pure pieces it is built from.
//
// `node:assert` rather than std/assert: it ships with Deno, so these tests
// run without fetching anything.
import { deepStrictEqual as equal, ok, strictEqual as is, throws } from 'node:assert/strict';
import { merchantKey } from '../merchant-key.ts';
import { normaliseDecimal, normaliseMoney } from '../receipt-money.ts';
import {
  modelOutputJsonSchema,
  parseModelReceipt,
  parseReceiptExtraction,
  type ReceiptExtraction,
  SchemaError,
} from '../receipt-schema.ts';
import {
  assembleExtraction,
  handleReceiptsExtract,
  normaliseDate,
  type ReceiptsDeps,
  scanLimitFromEnv,
  totalMismatch,
} from '../receipts.ts';
import { loadModelPolicy } from '../registry.ts';
import { resolveModelsForTask } from '../router.ts';
import { normalizeAiRoute } from '../routes.ts';
import { OpenRouterClient, type OpenRouterTransport } from '../openrouter.ts';
import { resetInMemoryRateLimitsForTests } from '../ratelimit.ts';
import { completion, FakeDb, fakeTransport, field } from './receipts_fakes.ts';
import { runReceiptEval } from '../evals/receipts-runner.ts';

const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
const RECEIPT = '33333333-3333-4333-8333-333333333333';
const TRANSACTION = '44444444-4444-4444-8444-444444444444';
const TOKENS: Record<string, string> = { 'user-token': USER, 'other-token': OTHER };
const SERVICE_KEY = 'service-role-key';

const policy = await loadModelPolicy();
const prompt = await Deno.readTextFile(
  new URL('../prompts/receipts-extraction.md', import.meta.url),
);

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/** An Esselunga scontrino, read the way a model would answer. */
function esselunga(overrides: Record<string, unknown> = {}) {
  return {
    is_receipt: true,
    document_type: 'scontrino',
    merchant: {
      name: field('ESSELUNGA S.p.A.', 0.97),
      vat_id: field('IT 04916380159', 0.9),
      address: field('Viale Piave 1, Milano', 0.8),
      country: field('IT', 0.95),
    },
    date: field('2026-09-20', 0.96),
    time: field('18:42', 0.9),
    currency: field('EUR', 0.99),
    total: field('12,50', 0.98),
    subtotal: field(null, 0),
    tip: field(null, 0),
    discount: field('1,00-', 0.9),
    tax_total: field('1,07', 0.85),
    tax_lines: [
      { rate: '10%', taxable: '4,36', tax: '0,44' },
      { rate: '22,00', taxable: '2,86', tax: '0,63' },
    ],
    line_items: [
      { description: 'LATTE INTERO', quantity: '1', unit_price: '1,29', amount: '1,29' },
      { description: 'PANE', quantity: null, unit_price: null, amount: '3,21' },
      { description: 'DETERSIVO', quantity: '2', unit_price: '4,50', amount: '9,00' },
    ],
    payment: { method: field('card', 0.9), card_last4: field('**** **** 1234', 0.8) },
    receipt_number: field('0042-0117', 0.8),
    category: { key: 'groceries', confidence: 0.93 },
    scope_suggestion: 'personal',
    warnings: [],
    ...overrides,
  };
}

function seededDb(receiptOwner = USER): FakeDb {
  const db = new FakeDb({
    money_receipts: [{
      id: RECEIPT,
      user_id: receiptOwner,
      status: 'uploaded',
      source: 'camera',
      image_paths: [`${receiptOwner}/${RECEIPT}/1.jpg`, `${receiptOwner}/${RECEIPT}/2.jpg`],
      extraction: null,
      updated_at: '2026-09-24T09:59:00Z',
      deleted_at: null,
    }],
    money_categories: [
      'groceries',
      'eating_out',
      'shopping',
      'other',
    ].map((key) => ({
      user_id: receiptOwner,
      key,
      kind: 'expense',
      archived: false,
      deleted_at: null,
    })).concat([
      { user_id: receiptOwner, key: 'salary', kind: 'income', archived: false, deleted_at: null },
      { user_id: receiptOwner, key: 'fuel', kind: 'expense', archived: true, deleted_at: null },
    ]),
  });
  db.files.set(
    `${receiptOwner}/${RECEIPT}/1.jpg`,
    new Blob([new Uint8Array([0xff, 0xd8, 0xff, 1])], { type: 'image/jpeg' }),
  );
  db.files.set(
    `${receiptOwner}/${RECEIPT}/2.jpg`,
    new Blob([new Uint8Array([0xff, 0xd8, 0xff, 2])], { type: 'image/jpeg' }),
  );
  return db;
}

function deps(
  db: FakeDb,
  transport: OpenRouterTransport,
  overrides: Partial<ReceiptsDeps> = {},
): ReceiptsDeps {
  return {
    db,
    serviceRoleKey: SERVICE_KEY,
    userIdForToken: (token) => Promise.resolve(TOKENS[token] ?? null),
    policy,
    openRouter: () => new OpenRouterClient('test-key', transport),
    scanLimit: 100,
    prompt,
    now: () => new Date('2026-09-24T10:00:00Z'),
    ...overrides,
  };
}

function call(d: ReceiptsDeps, body: Record<string, unknown>, token: string | null = 'user-token') {
  resetInMemoryRateLimitsForTests();
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (token) headers.authorization = `Bearer ${token}`;
  const req = new Request('http://local/functions/v1/ai-gateway/receipts-extract', {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  return handleReceiptsExtract(req, () => Promise.resolve(d));
}

const receiptRow = (db: FakeDb) => db.table('money_receipts').find((r) => r.id === RECEIPT)!;

// ---------------------------------------------------------------------------
// Route
// ---------------------------------------------------------------------------

Deno.test('receipts-extract: reads, normalises and stores the extraction', async () => {
  const db = seededDb();
  const { transport, calls } = fakeTransport(() => completion(esselunga()));
  const res = await call(deps(db, transport), {
    receipt_id: RECEIPT,
    locale: 'it-IT',
    home_currency: 'EUR',
  });
  is(res.status, 200);
  const body = await res.json() as ReceiptExtraction;

  is(body.version, '1');
  is(body.receipt_id, RECEIPT);
  is(body.document_type, 'scontrino');
  is(body.merchant_key, 'esselunga');
  equal(body.merchant.vat_id, { value: 'IT04916380159', confidence: 0.9 });
  equal(body.total, { value: '12.50', confidence: 0.98 });
  equal(body.discount, { value: '1.00', confidence: 0.9 });
  equal(body.tax_total, { value: '1.07', confidence: 0.85 });
  equal(body.tax_lines, [{ rate: '10', taxable: '4.36', tax: '0.44' }, {
    rate: '22',
    taxable: '2.86',
    tax: '0.63',
  }]);
  equal(body.line_items[2], {
    description: 'DETERSIVO',
    quantity: '2',
    unit_price: '4.50',
    amount: '9.00',
  });
  equal(body.payment.card_last4, { value: '1234', confidence: 0.8 });
  equal(body.category, { key: 'groceries', confidence: 0.93, source: 'model' });
  is(body.scope_suggestion, 'personal');
  is(body.duplicate_of, null);
  equal(body.warnings, []);
  is(body.model, 'google/gemini-3.7-flash');
  is(body.prompt_version, 'receipts-v1');

  // Written with the service role, alongside the columns the duplicate index uses.
  const row = receiptRow(db);
  is(row.status, 'extracted');
  equal(row.extraction, body);
  is(row.merchant_key, 'esselunga');
  is(row.receipt_date, '2026-09-20');
  is(row.total, '12.50');
  is(row.currency, 'EUR');
  is(row.model, 'google/gemini-3.7-flash');
  is(row.prompt_version, 'receipts-v1');
  is(row.model_version, policy.model_policy_version);
  is(db.updates[0].values.status, 'processing', 'marked processing before the model is called');
  is(db.usage(USER)?.scans, 1);
  ok(Number(db.usage(USER)?.cost_usd) > 0, 'model cost is recorded against the month');

  // Provenance, as the rest of the gateway records it.
  is(db.table('ai_requests')[0].task, 'receipt_extraction');
  is(db.table('ai_requests')[0].status, 'succeeded');
  is(db.table('ai_model_runs')[0].prompt_version, 'receipts-v1');

  // One call to the role's primary model, both pages attached, strict schema
  // whose category enum is the user's own expense categories.
  is(calls.length, 1);
  const sent = calls[0].body;
  is(sent.model, policy.roles.multimodal_primary.primary_model);
  is(sent.max_tokens, 4096);
  const format = sent.response_format as {
    type: string;
    json_schema: { strict: boolean; schema: Record<string, unknown> };
  };
  is(format.type, 'json_schema');
  is(format.json_schema.strict, true);
  const categoryEnum = (format.json_schema.schema.properties as Record<
    string,
    { properties: Record<string, { enum: string[] }> }
  >)
    .category.properties.key.enum;
  equal(categoryEnum, ['groceries', 'eating_out', 'shopping', 'other']);
  const messages = sent.messages as Array<{ role: string; content: unknown }>;
  ok(String(messages[0].content).includes('it-IT'), 'locale reaches the prompt');
  ok(String(messages[0].content).includes('groceries, eating_out, shopping, other'));
  const parts = messages[1].content as Array<{ type: string; image_url?: { url: string } }>;
  equal(parts.filter((p) => p.type === 'image_url').length, 2);
  ok(parts[1].image_url!.url.startsWith('data:image/jpeg;base64,'));
});

Deno.test('receipts-extract: a learned merchant rule beats the model', async () => {
  const db = seededDb();
  db.table('money_merchant_rules').push({
    user_id: USER,
    merchant_key: 'esselunga',
    category_key: 'shopping',
    scope: 'business',
    deleted_at: null,
  });
  const { transport } = fakeTransport(() => completion(esselunga()));
  const body = await (await call(deps(db, transport), { receipt_id: RECEIPT })).json();
  equal(body.category, { key: 'shopping', confidence: 1, source: 'rule' });
  is(body.scope_suggestion, 'business');
});

Deno.test('receipts-extract: a rule for a category the user no longer has is ignored', async () => {
  const db = seededDb();
  db.table('money_merchant_rules').push({
    user_id: USER,
    merchant_key: 'esselunga',
    category_key: 'fuel',
    scope: null,
    deleted_at: null,
  });
  const { transport } = fakeTransport(() => completion(esselunga()));
  const body = await (await call(deps(db, transport), { receipt_id: RECEIPT })).json();
  equal(body.category, { key: 'groceries', confidence: 0.93, source: 'model' });
});

Deno.test("receipts-extract: a category outside the user's list falls back to other", async () => {
  const db = seededDb();
  const { transport } = fakeTransport(() =>
    completion(esselunga({ category: { key: 'coffee', confidence: 0.99 } }))
  );
  const body = await (await call(deps(db, transport), { receipt_id: RECEIPT })).json();
  equal(body.category, { key: 'other', confidence: 0, source: 'default' });
});

Deno.test('receipts-extract: flags a transaction already saved for the same merchant, day and total', async () => {
  const db = seededDb();
  db.table('money_transactions').push({
    id: TRANSACTION,
    user_id: USER,
    merchant: 'Esselunga',
    transaction_date: '2026-09-20',
    amount: '12.50',
    direction: 'expense',
    deleted_at: null,
  });
  // Same day and amount, different shop: not a duplicate.
  db.table('money_transactions').push({
    id: crypto.randomUUID(),
    user_id: USER,
    merchant: 'Coop',
    transaction_date: '2026-09-20',
    amount: '12.50',
    direction: 'expense',
    deleted_at: null,
  });
  const { transport } = fakeTransport(() => completion(esselunga()));
  const body = await (await call(deps(db, transport), { receipt_id: RECEIPT })).json();
  is(body.duplicate_of, TRANSACTION);
});

Deno.test('receipts-extract: flags a receipt confirmed earlier with the same key, date and total', async () => {
  const db = seededDb();
  db.table('money_receipts').push({
    id: crypto.randomUUID(),
    user_id: USER,
    status: 'confirmed',
    merchant_key: 'esselunga',
    receipt_date: '2026-09-20',
    total: '12.50',
    transaction_id: TRANSACTION,
    deleted_at: null,
  });
  const { transport } = fakeTransport(() => completion(esselunga()));
  const body = await (await call(deps(db, transport), { receipt_id: RECEIPT })).json();
  is(body.duplicate_of, TRANSACTION);
});

Deno.test('receipts-extract: 402 when the monthly scan limit is used up', async () => {
  const db = seededDb();
  db.table('money_receipt_usage').push({ user_id: USER, month: db.month, scans: 3, cost_usd: 0 });
  const { transport, calls } = fakeTransport(() => completion(esselunga()));
  const res = await call(deps(db, transport, { scanLimit: 3 }), { receipt_id: RECEIPT });
  is(res.status, 402);
  equal((await res.json()).error, 'SCAN_LIMIT_REACHED');
  is(calls.length, 0, 'no model is called');
  is(receiptRow(db).status, 'uploaded');
  is(db.usage(USER)?.scans, 3);
});

Deno.test("receipts-extract: 404 for a receipt that is not the caller's", async () => {
  const db = seededDb(OTHER);
  const { transport, calls } = fakeTransport(() => completion(esselunga()));
  const res = await call(deps(db, transport), { receipt_id: RECEIPT });
  is(res.status, 404);
  equal(await res.json(), { error: 'RECEIPT_NOT_FOUND', message: 'No such receipt.' });
  is(calls.length, 0);
  is(receiptRow(db).status, 'uploaded');
});

Deno.test('receipts-extract: 422 and status failed when there is no receipt in the image', async () => {
  const db = seededDb();
  const notReceipt = esselunga({
    is_receipt: false,
    document_type: 'other',
    merchant: {
      name: field(null, 0),
      vat_id: field(null, 0),
      address: field(null, 0),
      country: field(null, 0),
    },
    total: field(null, 0),
    warnings: ['not_a_receipt'],
  });
  const { transport } = fakeTransport(() => completion(notReceipt));
  const res = await call(deps(db, transport), { receipt_id: RECEIPT });
  is(res.status, 422);
  is((await res.json()).error, 'UNREADABLE');
  const row = receiptRow(db);
  is(row.status, 'failed');
  is(row.error_code, 'UNREADABLE');
  is(db.usage(USER)?.scans, 1, 'the model call still counts as a scan');
});

Deno.test('receipts-extract: 503 when every model in the role fails, and the scan is returned', async () => {
  const db = seededDb();
  const { transport, calls } = fakeTransport(() => new Response('upstream down', { status: 503 }));
  const res = await call(deps(db, transport), { receipt_id: RECEIPT });
  is(res.status, 503);
  is((await res.json()).error, 'AI_UNAVAILABLE');
  const models = [
    policy.roles.multimodal_primary.primary_model,
    ...policy.roles.multimodal_primary.fallback_models,
  ];
  equal([...new Set(calls.map((c) => c.body.model))], models, 'every model in the role was tried');
  is(receiptRow(db).status, 'failed');
  is(receiptRow(db).error_code, 'AI_UNAVAILABLE');
  is(db.usage(USER)?.scans, 0, 'an outage does not use up the allowance');
  is(db.table('ai_requests')[0].status, 'failed');
});

Deno.test('receipts-extract: 503 when no OpenRouter key is configured', async () => {
  const saved = Deno.env.get('OPENROUTER_API_KEY');
  Deno.env.delete('OPENROUTER_API_KEY');
  try {
    const db = seededDb();
    const res = await call(
      deps(db, () => Promise.reject(new Error('unreachable')), {
        openRouter: () => new OpenRouterClient(),
      }),
      { receipt_id: RECEIPT },
    );
    is(res.status, 503);
    is(db.usage(USER)?.scans, 0);
  } finally {
    if (saved !== undefined) Deno.env.set('OPENROUTER_API_KEY', saved);
  }
});

Deno.test('receipts-extract: a malformed answer is repaired once, then succeeds', async () => {
  const db = seededDb();
  const { transport, calls } = fakeTransport((_body, n) =>
    completion(n === 1 ? '{"is_receipt": "maybe"}' : esselunga())
  );
  const res = await call(deps(db, transport), { receipt_id: RECEIPT });
  is(res.status, 200);
  is(calls.length, 2);
});

Deno.test('receipts-extract: the service role acts for user_id in the body', async () => {
  const db = seededDb();
  const { transport } = fakeTransport(() => completion(esselunga()));
  const res = await call(deps(db, transport), { receipt_id: RECEIPT, user_id: USER }, SERVICE_KEY);
  is(res.status, 200);
  is(receiptRow(db).status, 'extracted');
  is(db.usage(USER)?.scans, 1, 'the same allowance applies');

  const missing = await call(deps(seededDb(), transport), { receipt_id: RECEIPT }, SERVICE_KEY);
  is(missing.status, 400, 'the service role must say whom it acts for');
});

/** A receipt stored the way inbound e-mail stores it: one page, PNG or PDF. */
function emailedDb(name: string, type: string): FakeDb {
  const db = seededDb();
  receiptRow(db).image_paths = [`${USER}/${RECEIPT}/${name}`];
  receiptRow(db).source = 'email';
  db.files.clear();
  db.files.set(`${USER}/${RECEIPT}/${name}`, new Blob([new Uint8Array([1, 2, 3])], { type }));
  return db;
}

Deno.test('receipts-extract: an e-mailed PNG is sent with its own media type', async () => {
  const db = emailedDb('1.png', 'image/png');
  const { transport, calls } = fakeTransport(() => completion(esselunga()));
  const res = await call(deps(db, transport), {
    receipt_id: RECEIPT,
    user_id: USER,
    locale: 'en-GB',
  }, SERVICE_KEY);
  is(res.status, 200);
  const messages = calls[0].body.messages as Array<{ content: unknown }>;
  ok(String(messages[0].content).includes('en-GB'));
  const parts = messages[1].content as Array<{ type: string; image_url?: { url: string } }>;
  ok(parts[1].image_url!.url.startsWith('data:image/png;base64,'));
});

Deno.test('receipts-extract: a PDF goes to the model as a file part', async () => {
  const db = emailedDb('1.pdf', 'application/pdf');
  const { transport, calls } = fakeTransport(() => completion(esselunga()));
  const res = await call(deps(db, transport), {
    receipt_id: RECEIPT,
    user_id: USER,
    locale: 'en-GB',
  }, SERVICE_KEY);
  is(res.status, 200);
  const parts = (calls[0].body.messages as Array<{ content: unknown }>)[1].content as Array<
    { type: string; file?: { file_data: string } }
  >;
  is(parts[1].type, 'file');
  ok(parts[1].file!.file_data.startsWith('data:application/pdf;base64,'));
});

Deno.test('receipts-extract: a PDF no model will take is UNREADABLE, not an outage', async () => {
  const db = emailedDb('1.pdf', 'application/pdf');
  const { transport } = fakeTransport(() =>
    new Response('{"error":"unsupported file type"}', { status: 400 })
  );
  const res = await call(deps(db, transport), { receipt_id: RECEIPT, user_id: USER }, SERVICE_KEY);
  is(res.status, 422);
  const body = await res.json();
  is(body.error, 'UNREADABLE');
  ok(body.message.includes('PDF'));
  is(receiptRow(db).status, 'failed');
  is(db.usage(USER)?.scans, 0, 'a refused document does not use a scan');
});

Deno.test('receipts-extract: user_id from anyone but the service role is ignored', async () => {
  const db = seededDb(OTHER);
  const { transport, calls } = fakeTransport(() => completion(esselunga()));
  // USER names OTHER as the user; the token still decides.
  const res = await call(
    deps(db, transport),
    { receipt_id: RECEIPT, user_id: OTHER },
    'user-token',
  );
  is(res.status, 404);
  is(calls.length, 0);
});

Deno.test('receipts-extract: 401 without a valid token', async () => {
  const { transport } = fakeTransport(() => completion(esselunga()));
  const none = await call(deps(seededDb(), transport), { receipt_id: RECEIPT }, null);
  is(none.status, 401);
  is((await none.json()).error, 'UNAUTHENTICATED');
  const bad = await call(deps(seededDb(), transport), { receipt_id: RECEIPT }, 'forged');
  is(bad.status, 401);
});

Deno.test("receipts-extract: page paths outside the receipt's folder are refused before any scan", async () => {
  const db = seededDb();
  receiptRow(db).image_paths = [`${OTHER}/${RECEIPT}/1.jpg`];
  const { transport, calls } = fakeTransport(() => completion(esselunga()));
  const res = await call(deps(db, transport), { receipt_id: RECEIPT });
  is(res.status, 400);
  is(calls.length, 0);
  is(db.usage(USER), undefined);
});

Deno.test('receipts-extract: a missing page sends the receipt back to uploaded', async () => {
  const db = seededDb();
  db.files.delete(`${USER}/${RECEIPT}/2.jpg`);
  const { transport, calls } = fakeTransport(() => completion(esselunga()));
  const res = await call(deps(db, transport), { receipt_id: RECEIPT });
  is(res.status, 400);
  is((await res.json()).error, 'IMAGES_MISSING');
  is(receiptRow(db).status, 'uploaded');
  is(calls.length, 0);
  is(db.usage(USER)?.scans, 0);
});

Deno.test('receipts-extract: a retry returns the stored reading without a second scan', async () => {
  const db = seededDb();
  const { transport, calls } = fakeTransport(() => completion(esselunga()));
  const first = await (await call(deps(db, transport), { receipt_id: RECEIPT })).json();
  const again = await call(deps(db, transport), { receipt_id: RECEIPT });
  is(again.status, 200);
  equal(await again.json(), first);
  is(calls.length, 1);
  is(db.usage(USER)?.scans, 1);

  const forced = await call(deps(db, transport), { receipt_id: RECEIPT, force: true });
  is(forced.status, 200);
  is(calls.length, 2, '`force` reads it again');
});

Deno.test('receipts-extract: a receipt already being read is not read twice', async () => {
  const db = seededDb();
  Object.assign(receiptRow(db), { status: 'processing', updated_at: '2026-09-24T09:59:30Z' });
  const { transport, calls } = fakeTransport(() => completion(esselunga()));
  const res = await call(deps(db, transport), { receipt_id: RECEIPT });
  is(res.status, 409);
  is(calls.length, 0);
});

// ---------------------------------------------------------------------------
// Pure pieces
// ---------------------------------------------------------------------------

Deno.test('merchantKey matches the shared example table', async () => {
  const examples: Array<{ name: string; key: string }> = JSON.parse(
    await Deno.readTextFile(new URL('./fixtures/merchant_keys.json', import.meta.url)),
  );
  ok(examples.length >= 20);
  for (const { name, key } of examples) {
    is(merchantKey(name), key, `merchantKey(${JSON.stringify(name)})`);
  }
  // The contract's own examples.
  is(merchantKey('ESSELUNGA S.p.A.'), 'esselunga');
  is(merchantKey('Marks & Spencer PLC'), 'marks and spencer');
});

Deno.test('the Swift tests read the same example tables', async () => {
  for (const name of ['merchant_keys.json', 'receipt_money_cases.json']) {
    const here = await Deno.readTextFile(new URL(`./fixtures/${name}`, import.meta.url));
    const swift = await Deno.readTextFile(
      new URL(
        `../../../../money-manager-ios/VeralifyCore/Tests/VeralifyCoreTests/Fixtures/${name}`,
        import.meta.url,
      ),
    );
    is(swift, here, `copy tests/fixtures/${name} over the Swift fixture after editing either`);
  }
});

Deno.test('money matches the shared case table', async () => {
  const cases: Array<{ input: string; currency: string; money: string | null }> = JSON.parse(
    await Deno.readTextFile(new URL('./fixtures/receipt_money_cases.json', import.meta.url)),
  );
  for (const { input, currency, money } of cases) {
    is(
      normaliseMoney(input, currency),
      money,
      `normaliseMoney(${JSON.stringify(input)}, ${currency})`,
    );
  }
});

Deno.test('the iOS decoder fixture is exactly what the route returns', async () => {
  // money-manager-ios/VeralifyCore/Tests/VeralifyCoreTests/Fixtures/receipt-extraction-v1.json
  // is decoded by the Swift `ReceiptExtraction` tests. Producing it here keeps
  // the two sides of the contract from drifting apart.
  const db = seededDb();
  db.table('money_transactions').push({
    id: TRANSACTION,
    user_id: USER,
    merchant: 'Esselunga',
    transaction_date: '2026-09-20',
    amount: '12.50',
    direction: 'expense',
    deleted_at: null,
  });
  const { transport } = fakeTransport(() =>
    completion(esselunga({ tax_total: field('1,07', 0.6) }))
  );
  const body = await (await call(deps(db, transport), { receipt_id: RECEIPT })).json();
  const fixture = JSON.parse(
    await Deno.readTextFile(
      new URL(
        '../../../../money-manager-ios/VeralifyCore/Tests/VeralifyCoreTests/Fixtures/receipt-extraction-v1.json',
        import.meta.url,
      ),
    ),
  );
  equal(fixture, body, `regenerate the fixture from:\n${JSON.stringify(body, null, 2)}`);
});

Deno.test('money is normalised to canonical decimal strings', () => {
  const cases: Array<[unknown, string | null | undefined, string | null]> = [
    ['12,50', 'EUR', '12.50'],
    ['12.5', 'EUR', '12.50'],
    [12.5, 'EUR', '12.50'],
    [0.1 + 0.2, 'EUR', '0.30'],
    ['1.234,56', 'EUR', '1234.56'],
    ['1,234.56', 'GBP', '1234.56'],
    ['1.234', 'EUR', '1234.00'],
    ['0,500', 'EUR', '0.50'],
    ['€ 3,99', 'EUR', '3.99'],
    ['£1,000', 'GBP', '1000.00'],
    ['1.250.000', 'EUR', '1250000.00'],
    ['2,00-', 'EUR', '-2.00'],
    ['-€2,00', 'EUR', '-2.00'],
    ['(4.20)', 'GBP', '-4.20'],
    ['2,005', 'EUR', '2005.00'],
    ['0,005', 'EUR', '0.01'],
    ['1500', 'JPY', '1500'],
    ['12-05', 'EUR', null],
    ['abc', 'EUR', null],
    ['', 'EUR', null],
    [null, 'EUR', null],
  ];
  for (const [input, currency, expected] of cases) {
    is(normaliseMoney(input, currency), expected, `normaliseMoney(${JSON.stringify(input)})`);
  }
  is(normaliseDecimal('22,00'), '22');
  is(normaliseDecimal('5.5'), '5.5');
  is(normaliseDecimal('1,234'), '1.234', 'a quantity keeps its decimals');
  is(normaliseDecimal('0'), '0');
});

Deno.test('dates are read day-first when not ISO', () => {
  is(normaliseDate('2026-09-20'), '2026-09-20');
  is(normaliseDate('05/03/26'), '2026-03-05');
  is(normaliseDate('20.09.2026'), '2026-09-20');
  is(normaliseDate('2026-02-30'), null);
  is(normaliseDate('yesterday'), null);
});

Deno.test('assembly: arithmetic that does not add up is flagged, and weak key fields too', () => {
  const base = {
    receiptId: RECEIPT,
    model: 'm',
    categoryKeys: ['groceries', 'other'],
    rule: null,
    homeCurrency: 'EUR',
  };
  const fine = assembleExtraction({ ...base, parsed: parseModelReceipt(esselunga()) });
  is(totalMismatch(fine), false);
  equal(fine.warnings, []);

  const wrong = assembleExtraction({
    ...base,
    parsed: parseModelReceipt(esselunga({ total: field('20,00', 0.6) })),
  });
  equal(wrong.warnings, ['total_mismatch', 'low_confidence']);

  // Nothing to add up: the model's own impression stands.
  const noItems = assembleExtraction({
    ...base,
    parsed: parseModelReceipt(
      esselunga({ line_items: [], warnings: ['total_mismatch', 'multiple_currencies'] }),
    ),
  });
  is(totalMismatch(noItems), null);
  equal(noItems.warnings, ['multiple_currencies', 'total_mismatch']);

  // UK style: VAT inclusive, GBP, VAT registration number with spaces.
  const uk = assembleExtraction({
    ...base,
    parsed: parseModelReceipt(esselunga({
      merchant: {
        name: field('Tesco Stores Ltd', 0.95),
        vat_id: field('GB 220 4302 31', 0.9),
        address: field(null, 0),
        country: field('UK', 0.9),
      },
      currency: field('£', 0.9),
      total: field('4.20', 0.95),
      discount: field(null, 0),
      tax_lines: [{ rate: '20%', taxable: '3.50', tax: '0.70' }],
      line_items: [{ description: 'Meal deal', quantity: null, unit_price: null, amount: '4.20' }],
    })),
  });
  is(uk.merchant_key, 'tesco stores');
  equal(uk.merchant.vat_id.value, 'GB220430231');
  equal(uk.merchant.country.value, 'GB');
  equal(uk.currency.value, 'GBP');
  equal(uk.tax_lines, [{ rate: '20', taxable: '3.50', tax: '0.70' }]);
  equal(uk.warnings, []);
});

Deno.test('the stored document is validated before it is written', () => {
  const extraction = assembleExtraction({
    receiptId: RECEIPT,
    model: 'm',
    categoryKeys: ['groceries', 'other'],
    rule: null,
    homeCurrency: 'EUR',
    parsed: parseModelReceipt(esselunga()),
  });
  equal(parseReceiptExtraction(structuredClone(extraction), ['groceries', 'other']), extraction);
  throws(
    () => parseReceiptExtraction({ ...extraction, total: { value: '12,50', confidence: 1 } }),
    SchemaError,
  );
  throws(() => parseReceiptExtraction({ ...extraction, version: '2' }), SchemaError);
  throws(
    () => parseReceiptExtraction(extraction, ['other']),
    SchemaError,
    "category must be one of the user's",
  );
  throws(
    () => parseModelReceipt({ ...esselunga(), total: { value: {}, confidence: 1 } }),
    SchemaError,
  );
});

Deno.test('the model schema is strict all the way down', () => {
  const visit = (node: unknown): void => {
    if (!node || typeof node !== 'object') return;
    const n = node as Record<string, unknown>;
    if (n.type === 'object') {
      is(n.additionalProperties, false);
      equal([...(n.required as string[])].sort(), Object.keys(n.properties as object).sort());
    }
    Object.values(n).forEach(visit);
  };
  visit(modelOutputJsonSchema(['groceries', 'other']));
});

Deno.test('the receipt eval scores the offline seed set through the real route', async () => {
  const report = await runReceiptEval(
    new URL('../evals/datasets/receipts_seed.jsonl', import.meta.url),
    {
      write: false,
    },
  );
  is(report.summary.cases, 3);
  is(report.summary.pass_rate, 1, JSON.stringify(report.cases.filter((c) => !c.passed)));
  is(report.summary.wrong_but_not_flagged, 0);
});

Deno.test('route, policy and limit wiring', () => {
  is(normalizeAiRoute('http://local/functions/v1/ai-gateway/receipts-extract'), 'receipts-extract');
  const { rolePolicy, taskPolicy } = resolveModelsForTask(policy, 'receipt_extraction');
  is(taskPolicy.role, 'multimodal_primary');
  is(rolePolicy.primary_model, policy.roles.multimodal_primary.primary_model);
  is(rolePolicy.max_tokens, 4096);
  is(policy.roles.multimodal_primary.max_tokens, 1200, 'the override does not leak into the role');
  is(scanLimitFromEnv(undefined), 100);
  is(scanLimitFromEnv('25'), 25);
  is(scanLimitFromEnv('lots'), 100);
});
