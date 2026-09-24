import { assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { FREEAGENT_BASE_URLS, FreeAgentAdapter } from './freeagent.ts';
import { bytesToBase64 } from './http.ts';
import {
  formValues,
  JPEG_BYTES,
  jsonBody,
  jsonResponse,
  sampleDraft,
  scriptedFetch,
  testTokens,
} from './testing.ts';
import { AccountingError } from './types.ts';

const SANDBOX = FREEAGENT_BASE_URLS.sandbox;
const COMPANY = `${SANDBOX}/company`;
const CATEGORY = `${SANDBOX}/categories/285`;

function adapter(responses: Parameters<typeof scriptedFetch>[0]) {
  const mock = scriptedFetch(responses);
  return {
    fa: new FreeAgentAdapter({
      clientId: 'fid',
      clientSecret: 'fsecret',
      environment: 'sandbox',
      fetch: mock.fetch,
    }),
    requests: mock.requests,
  };
}

const ctx = { companyId: COMPANY, tokens: testTokens() };
const draft = sampleDraft({
  lines: [{ ...sampleDraft().lines[0], accountId: CATEGORY, taxCodeId: '20' }],
  paymentAccountId: null,
});

Deno.test('freeagent: sandbox authorize URL is approve_app', () => {
  const { fa } = adapter([]);
  const url = new URL(fa.authorizeUrl({ state: 's', redirectUri: 'https://fn.test/cb' }));
  assertEquals(url.origin + url.pathname, `${SANDBOX}/approve_app`);
  assertEquals(url.searchParams.get('response_type'), 'code');
  assertEquals(url.searchParams.get('client_id'), 'fid');
});

Deno.test('freeagent: refresh posts to token_endpoint with Basic auth', async () => {
  const { fa, requests } = adapter([
    jsonResponse({ access_token: 'at-2', expires_in: 3600, token_type: 'bearer' }),
  ]);
  const tokens = await fa.refresh(testTokens({ refresh_token: 'rt-1' }));
  assertEquals(requests[0].url.toString(), `${SANDBOX}/token_endpoint`);
  assertEquals(requests[0].headers.get('authorization'), `Basic ${btoa('fid:fsecret')}`);
  assertEquals(formValues(requests[0]), { grant_type: 'refresh_token', refresh_token: 'rt-1' });
  // FreeAgent keeps the refresh token when it does not send a new one.
  assertEquals(tokens.refresh_token, 'rt-1');
  assertEquals(tokens.access_token, 'at-2');
});

Deno.test('freeagent: createExpense posts an expense claimed by the current user', async () => {
  const { fa, requests } = adapter([
    jsonResponse({ user: { url: `${SANDBOX}/users/7` } }),
    jsonResponse({ expense: { url: `${SANDBOX}/expenses/99` } }, 201),
  ]);
  const record = await fa.createExpense(ctx, draft);
  assertEquals(record, { externalId: `${SANDBOX}/expenses/99`, externalType: 'expense' });
  assertEquals(requests[0].url.toString(), `${SANDBOX}/users/me`);
  const create = requests[1];
  assertEquals(create.method, 'POST');
  assertEquals(create.url.toString(), `${SANDBOX}/expenses`);
  assertEquals(create.headers.get('authorization'), 'Bearer access-1');
  assertEquals(create.headers.get('content-type'), 'application/json');
  assertEquals(jsonBody(create), {
    expense: {
      user: `${SANDBOX}/users/7`,
      category: CATEGORY,
      dated_on: '2026-09-20',
      gross_value: '-24.00',
      currency: 'GBP',
      description: 'Staples — printer paper',
      receipt_reference: draft.transactionId,
      manual_sales_tax_amount: '4.00',
      sales_tax_rate: '20',
    },
  });
});

Deno.test('freeagent: attachReceipt sends the image inline as base64', async () => {
  const { fa, requests } = adapter([
    jsonResponse({
      expense: { url: `${SANDBOX}/expenses/99`, attachment: { url: `${SANDBOX}/attachments/5` } },
    }),
  ]);
  const id = await fa.attachReceipt(ctx, {
    externalId: `${SANDBOX}/expenses/99`,
    externalType: 'expense',
  }, {
    fileName: 'receipt-1.jpg',
    contentType: 'image/jpeg',
    bytes: JPEG_BYTES,
  });
  assertEquals(id, `${SANDBOX}/attachments/5`);
  assertEquals(requests[0].method, 'PUT');
  assertEquals(requests[0].url.toString(), `${SANDBOX}/expenses/99`);
  assertEquals(jsonBody(requests[0]), {
    expense: {
      attachment: {
        data: bytesToBase64(JPEG_BYTES),
        file_name: 'receipt-1.jpg',
        content_type: 'image/jpeg',
        description: 'Receipt',
      },
    },
  });
});

Deno.test('freeagent: HEIC attachments are refused before any request', async () => {
  const { fa, requests } = adapter([]);
  const error = await assertRejects(
    () =>
      fa.attachReceipt(ctx, { externalId: `${SANDBOX}/expenses/99`, externalType: 'expense' }, {
        fileName: 'r.heic',
        contentType: 'image/heic',
        bytes: JPEG_BYTES,
      }),
    AccountingError,
  );
  assertEquals(error.kind, 'permanent');
  assertEquals(requests.length, 0);
});

Deno.test('freeagent: a record URL off the API base is refused', async () => {
  const { fa } = adapter([]);
  const error = await assertRejects(
    () =>
      fa.deleteExpense(ctx, {
        externalId: 'https://evil.test/expenses/1',
        externalType: 'expense',
      }),
    AccountingError,
  );
  assertEquals(error.kind, 'permanent');
});

Deno.test('freeagent: delete sends DELETE to the expense url', async () => {
  const { fa, requests } = adapter([new Response(null, { status: 200 })]);
  await fa.deleteExpense(ctx, { externalId: `${SANDBOX}/expenses/99`, externalType: 'expense' });
  assertEquals(requests[0].method, 'DELETE');
  assertEquals(requests[0].url.toString(), `${SANDBOX}/expenses/99`);
});

Deno.test('freeagent: categories come from admin expenses and cost of sales', async () => {
  const { fa } = adapter([
    jsonResponse({
      admin_expenses_categories: [{
        url: `${SANDBOX}/categories/285`,
        description: 'Office Costs',
        nominal_code: '285',
      }],
      cost_of_sales_categories: [{
        url: `${SANDBOX}/categories/101`,
        description: 'Cost of sales',
        nominal_code: '101',
      }],
      income_categories: [{
        url: `${SANDBOX}/categories/001`,
        description: 'Sales',
        nominal_code: '001',
      }],
    }),
  ]);
  const options = await fa.listExpenseAccounts(ctx);
  assertEquals(options.map((o) => o.name), ['285 Office Costs', '101 Cost of sales']);
});

Deno.test('freeagent: HTTP errors map to retryable or not', async () => {
  const cases: [Response, string, boolean][] = [
    [
      jsonResponse({ errors: { error: { message: 'Access token not valid' } } }, 401),
      'auth',
      false,
    ],
    [jsonResponse({}, 429, { 'Retry-After': '60' }), 'rate_limited', true],
    [jsonResponse({}, 502), 'transient', true],
    [jsonResponse({ errors: [{ message: 'Dated on is invalid' }] }, 422), 'permanent', false],
  ];
  for (const [response, kind, retryable] of cases) {
    const { fa } = adapter([jsonResponse({ user: { url: `${SANDBOX}/users/7` } }), response]);
    const error = await assertRejects(() => fa.createExpense(ctx, draft), AccountingError);
    assertEquals(error.kind, kind, `status ${response.status}`);
    assertEquals(error.retryable, retryable);
    if (kind === 'permanent') assertEquals(error.message, 'freeagent 422: Dated on is invalid');
  }
});
