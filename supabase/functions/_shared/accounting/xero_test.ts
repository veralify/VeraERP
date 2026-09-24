import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@1';
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
import {
  XERO_API_BASE,
  XERO_REVOKE_URL,
  XERO_TOKEN_URL,
  XERO_UK_PURCHASE_TAX_TYPES,
  XeroAdapter,
} from './xero.ts';

const TENANT = '70784a63-d24b-46a9-a4db-0e70a274b056';

function adapter(responses: Parameters<typeof scriptedFetch>[0]) {
  const mock = scriptedFetch(responses);
  return {
    xero: new XeroAdapter({ clientId: 'xid', clientSecret: 'xsecret', fetch: mock.fetch }),
    requests: mock.requests,
  };
}

const ctx = { companyId: TENANT, tokens: testTokens() };

Deno.test('xero: authorize URL carries the PKCE challenge and offline_access', () => {
  const { xero } = adapter([]);
  const url = new URL(
    xero.authorizeUrl({ state: 's', redirectUri: 'https://fn.test/cb', codeChallenge: 'chal' }),
  );
  assertEquals(url.origin + url.pathname, 'https://login.xero.com/identity/connect/authorize');
  assertEquals(url.searchParams.get('code_challenge'), 'chal');
  assertEquals(url.searchParams.get('code_challenge_method'), 'S256');
  assert(url.searchParams.get('scope')!.split(' ').includes('offline_access'));
  assert(url.searchParams.get('scope')!.split(' ').includes('accounting.attachments'));
});

Deno.test('xero: code exchange sends the PKCE verifier', async () => {
  const { xero, requests } = adapter([
    jsonResponse({ access_token: 'at', refresh_token: 'rt', expires_in: 1800 }),
  ]);
  await xero.exchangeCode({ code: 'c', redirectUri: 'https://fn.test/cb', codeVerifier: 'ver' });
  assertEquals(requests[0].url.toString(), XERO_TOKEN_URL);
  assertEquals(requests[0].headers.get('authorization'), `Basic ${btoa('xid:xsecret')}`);
  assertEquals(formValues(requests[0]), {
    grant_type: 'authorization_code',
    code: 'c',
    redirect_uri: 'https://fn.test/cb',
    code_verifier: 'ver',
  });
});

Deno.test('xero: refresh stores the rotated refresh token', async () => {
  const { xero, requests } = adapter([
    jsonResponse({ access_token: 'at-2', refresh_token: 'rt-2', expires_in: 1800 }),
  ]);
  const tokens = await xero.refresh(testTokens({ refresh_token: 'rt-1' }));
  assertEquals(formValues(requests[0]), { grant_type: 'refresh_token', refresh_token: 'rt-1' });
  assertEquals(tokens.refresh_token, 'rt-2');
  assert(Date.parse(tokens.expires_at) <= Date.now() + 1800_000);
});

Deno.test('xero: listCompanies lists tenants from /connections', async () => {
  const { xero, requests } = adapter([
    jsonResponse([
      { id: 'c-1', tenantId: TENANT, tenantType: 'ORGANISATION', tenantName: 'Demo Company (UK)' },
      { id: 'c-2', tenantId: 'practice', tenantType: 'PRACTICEMANAGER', tenantName: 'XPM' },
    ]),
    jsonResponse({ Organisations: [{ CountryCode: 'GB', BaseCurrency: 'GBP' }] }),
  ]);
  const companies = await xero.listCompanies(testTokens(), new URLSearchParams());
  assertEquals(companies, [{
    id: TENANT,
    name: 'Demo Company (UK)',
    country: 'GB',
    currency: 'GBP',
  }]);
  assertEquals(requests[0].url.toString(), 'https://api.xero.com/connections');
  assertEquals(requests[1].headers.get('xero-tenant-id'), TENANT);
});

Deno.test('xero: a paid expense is a SPEND bank transaction with UK tax types', async () => {
  const { xero, requests } = adapter([
    jsonResponse({ BankTransactions: [{ BankTransactionID: 'bt-1', Type: 'SPEND' }] }),
  ]);
  const record = await xero.createExpense(ctx, sampleDraft());
  assertEquals(record, { externalId: 'bt-1', externalType: 'SPEND' });
  const [req] = requests;
  assertEquals(req.method, 'PUT');
  assertEquals(req.url.toString(), `${XERO_API_BASE}/BankTransactions`);
  assertEquals(req.headers.get('xero-tenant-id'), TENANT);
  assertEquals(req.headers.get('authorization'), 'Bearer access-1');
  assertEquals(req.headers.get('content-type'), 'application/json');
  const [bt] = jsonBody(req).BankTransactions as Record<string, unknown>[];
  assertEquals(bt, {
    Type: 'SPEND',
    Contact: { Name: 'Staples' },
    Date: '2026-09-20',
    Reference: 'VL-0f8fad5b',
    CurrencyCode: 'GBP',
    BankAccount: { AccountID: 'bank-1' },
    LineAmountTypes: 'Inclusive',
    LineItems: [{
      Description: 'Staples — printer paper',
      Quantity: 1,
      UnitAmount: 24,
      AccountCode: '429',
      TaxType: XERO_UK_PURCHASE_TAX_TYPES['20'],
      TaxAmount: 4,
    }],
  });
});

Deno.test('xero: without a paid-from account the expense becomes a draft ACCPAY bill', async () => {
  const { xero, requests } = adapter([
    jsonResponse({ Invoices: [{ InvoiceID: 'inv-1' }] }),
  ]);
  const record = await xero.createExpense(ctx, sampleDraft({ paymentAccountId: null }));
  assertEquals(record, { externalId: 'inv-1', externalType: 'ACCPAY' });
  assertEquals(requests[0].url.toString(), `${XERO_API_BASE}/Invoices`);
  const [bill] = jsonBody(requests[0]).Invoices as Record<string, unknown>[];
  assertEquals(bill.Type, 'ACCPAY');
  assertEquals(bill.Status, 'DRAFT');
  assertEquals(bill.InvoiceNumber, 'VL-0f8fad5b');
});

Deno.test('xero: unknown VAT is sent as NoTax', async () => {
  const { xero, requests } = adapter([
    jsonResponse({ BankTransactions: [{ BankTransactionID: 'bt-2' }] }),
  ]);
  const draft = sampleDraft({ taxKnown: false, taxTotal: '0.00' });
  draft.lines = [{ ...draft.lines[0], taxCodeId: null, vatRate: null, tax: '0.00', net: '24.00' }];
  await xero.createExpense(ctx, draft);
  const [bt] = jsonBody(requests[0]).BankTransactions as Record<string, unknown>[];
  assertEquals(bt.LineAmountTypes, 'NoTax');
  assertEquals((bt.LineItems as Record<string, unknown>[])[0].TaxType, undefined);
});

Deno.test('xero: update and delete go to the record URL', async () => {
  const { xero, requests } = adapter([
    jsonResponse({ BankTransactions: [{ BankTransactionID: 'bt-1' }] }),
    jsonResponse({ BankTransactions: [{ BankTransactionID: 'bt-1', Status: 'DELETED' }] }),
  ]);
  const record = { externalId: 'bt-1', externalType: 'SPEND' };
  await xero.updateExpense(ctx, record, sampleDraft());
  await xero.deleteExpense(ctx, record);
  assertEquals(requests[0].method, 'POST');
  assertEquals(requests[0].url.toString(), `${XERO_API_BASE}/BankTransactions/bt-1`);
  const [updated] = jsonBody(requests[0]).BankTransactions as Record<string, unknown>[];
  assertEquals(updated.BankTransactionID, 'bt-1');
  assertEquals(jsonBody(requests[1]), {
    BankTransactions: [{ BankTransactionID: 'bt-1', Status: 'DELETED' }],
  });
});

Deno.test('xero: attachReceipt PUTs the raw file to the Attachments endpoint', async () => {
  const { xero, requests } = adapter([
    jsonResponse({ Attachments: [{ AttachmentID: 'att-1', FileName: 'receipt-1.jpg' }] }),
  ]);
  const id = await xero.attachReceipt(ctx, { externalId: 'bt-1', externalType: 'SPEND' }, {
    fileName: 'receipt-1.jpg',
    contentType: 'image/jpeg',
    bytes: JPEG_BYTES,
  });
  assertEquals(id, 'att-1');
  const [req] = requests;
  assertEquals(req.method, 'PUT');
  assertEquals(
    req.url.toString(),
    `${XERO_API_BASE}/BankTransactions/bt-1/Attachments/receipt-1.jpg`,
  );
  assertEquals(req.headers.get('content-type'), 'image/jpeg');
  assertEquals(req.headers.get('xero-tenant-id'), TENANT);
  assertEquals(new Uint8Array(await (req.body as Blob).arrayBuffer()), JPEG_BYTES);
});

Deno.test('xero: bill attachments go to Invoices', async () => {
  const { xero, requests } = adapter([jsonResponse({ Attachments: [{ AttachmentID: 'att-2' }] })]);
  await xero.attachReceipt(ctx, { externalId: 'inv-1', externalType: 'ACCPAY' }, {
    fileName: 'r.jpg',
    contentType: 'image/jpeg',
    bytes: JPEG_BYTES,
  });
  assertEquals(requests[0].url.pathname, '/api.xro/2.0/Invoices/inv-1/Attachments/r.jpg');
});

Deno.test('xero: HTTP errors map to retryable or not', async () => {
  const cases: [Response, string, boolean][] = [
    [jsonResponse({ Title: 'Unauthorized', Detail: 'TokenExpired' }, 401), 'auth', false],
    [
      jsonResponse({ Title: 'Forbidden', Detail: 'AuthenticationUnsuccessful' }, 403),
      'auth',
      false,
    ],
    [jsonResponse({}, 429, { 'Retry-After': '45' }), 'rate_limited', true],
    [jsonResponse({}, 500), 'transient', true],
    [jsonResponse({}, 404), 'not_found', false],
    [
      jsonResponse({
        ErrorNumber: 10,
        Type: 'ValidationException',
        Elements: [{ ValidationErrors: [{ Message: 'Account code 999 is not a valid code' }] }],
      }, 400),
      'permanent',
      false,
    ],
  ];
  for (const [response, kind, retryable] of cases) {
    const { xero } = adapter([response]);
    const error = await assertRejects(
      () => xero.createExpense(ctx, sampleDraft()),
      AccountingError,
    );
    assertEquals(error.kind, kind, `status ${response.status}`);
    assertEquals(error.retryable, retryable);
    if (kind === 'rate_limited') assertEquals(error.retryAfterSeconds, 45);
    if (kind === 'permanent') assert(error.message.includes('Account code 999'));
  }
});

Deno.test('xero: revoking a shared grant only removes this tenant', async () => {
  const { xero, requests } = adapter([
    jsonResponse([{ id: 'conn-7', tenantId: TENANT }, { id: 'conn-8', tenantId: 'other' }]),
    new Response(null, { status: 204 }),
  ]);
  await xero.revoke(ctx, { tokenShared: true });
  assertEquals(requests[1].method, 'DELETE');
  assertEquals(requests[1].url.toString(), 'https://api.xero.com/connections/conn-7');
});

Deno.test('xero: revoking an unshared grant revokes the refresh token', async () => {
  const { xero, requests } = adapter([new Response(null, { status: 200 })]);
  await xero.revoke(ctx, { tokenShared: false });
  assertEquals(requests[0].url.toString(), XERO_REVOKE_URL);
  assertEquals(formValues(requests[0]), { token: 'refresh-1' });
});

Deno.test('xero: tax rates become tax codes with their effective rate', async () => {
  const { xero } = adapter([
    jsonResponse({
      TaxRates: [
        {
          Name: '20% (VAT on Expenses)',
          TaxType: 'INPUT2',
          EffectiveRate: 20,
          Status: 'ACTIVE',
          CanApplyToExpenses: true,
        },
        {
          Name: '20% (VAT on Income)',
          TaxType: 'OUTPUT2',
          EffectiveRate: 20,
          Status: 'ACTIVE',
          CanApplyToExpenses: false,
        },
        { Name: 'Old', TaxType: 'OLD', EffectiveRate: 17.5, Status: 'DELETED' },
      ],
    }),
  ]);
  assertEquals(await xero.listTaxCodes(ctx), [
    { id: 'INPUT2', name: '20% (VAT on Expenses)', rate: 20, type: 'INPUT2' },
  ]);
});
