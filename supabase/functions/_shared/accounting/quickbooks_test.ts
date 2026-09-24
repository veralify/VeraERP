import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { QBO_MINOR_VERSION, QBO_TOKEN_URL, QuickBooksAdapter } from './quickbooks.ts';
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

const REALM = '9130350000000001';

function adapter(
  responses: Parameters<typeof scriptedFetch>[0],
  environment: 'sandbox' | 'production' = 'sandbox',
) {
  const mock = scriptedFetch(responses);
  return {
    qbo: new QuickBooksAdapter({
      clientId: 'cid',
      clientSecret: 'secret',
      environment,
      fetch: mock.fetch,
    }),
    requests: mock.requests,
  };
}

const ctx = { companyId: REALM, tokens: testTokens() };
const draft = sampleDraft({
  lines: [{ ...sampleDraft().lines[0], accountId: '7', taxCodeId: '5' }],
  paymentAccountId: '41',
});

Deno.test('quickbooks: authorize URL asks for the accounting scope without PKCE', () => {
  const { qbo } = adapter([]);
  const url = new URL(
    qbo.authorizeUrl({ state: 's1', redirectUri: 'https://fn.test/accounting-callback' }),
  );
  assertEquals(url.origin + url.pathname, 'https://appcenter.intuit.com/connect/oauth2');
  assertEquals(url.searchParams.get('scope'), 'com.intuit.quickbooks.accounting');
  assertEquals(url.searchParams.get('state'), 's1');
  assertEquals(url.searchParams.get('redirect_uri'), 'https://fn.test/accounting-callback');
  assertEquals(url.searchParams.get('code_challenge'), null);
});

Deno.test('quickbooks: code exchange posts a form with Basic auth', async () => {
  const { qbo, requests } = adapter([
    jsonResponse({
      access_token: 'at',
      refresh_token: 'rt',
      expires_in: 3600,
      x_refresh_token_expires_in: 8726400,
      token_type: 'bearer',
    }),
  ]);
  const tokens = await qbo.exchangeCode({ code: 'c1', redirectUri: 'https://fn.test/cb' });
  const [req] = requests;
  assertEquals(req.method, 'POST');
  assertEquals(req.url.toString(), QBO_TOKEN_URL);
  assertEquals(req.headers.get('authorization'), `Basic ${btoa('cid:secret')}`);
  assertEquals(req.headers.get('content-type'), 'application/x-www-form-urlencoded');
  assertEquals(formValues(req), {
    grant_type: 'authorization_code',
    code: 'c1',
    redirect_uri: 'https://fn.test/cb',
  });
  assertEquals(tokens.access_token, 'at');
  assertEquals(tokens.refresh_token, 'rt');
  assert(Date.parse(tokens.expires_at) > Date.now() + 3500_000);
  assert(tokens.refresh_expires_at);
});

Deno.test('quickbooks: refresh sends the refresh token and keeps the rotated one', async () => {
  const { qbo, requests } = adapter([
    jsonResponse({ access_token: 'at-2', refresh_token: 'rt-2', expires_in: 3600 }),
  ]);
  const tokens = await qbo.refresh(testTokens({ refresh_token: 'rt-1' }));
  assertEquals(formValues(requests[0]), { grant_type: 'refresh_token', refresh_token: 'rt-1' });
  assertEquals(tokens.refresh_token, 'rt-2');
});

Deno.test('quickbooks: a rejected refresh is an auth error (needs re-consent)', async () => {
  const { qbo } = adapter([jsonResponse({ error: 'invalid_grant' }, 400)]);
  const error = await assertRejects(() => qbo.refresh(testTokens()), AccountingError);
  assertEquals(error.kind, 'auth');
  assertEquals(error.retryable, false);
});

Deno.test('quickbooks: listCompanies reads the realmId from the redirect', async () => {
  const { qbo, requests } = adapter([
    jsonResponse({ CompanyInfo: { CompanyName: 'Acme Ltd', Country: 'GB' } }),
    jsonResponse({ Preferences: { CurrencyPrefs: { HomeCurrency: { value: 'GBP' } } } }),
  ]);
  const companies = await qbo.listCompanies(testTokens(), new URLSearchParams({ realmId: REALM }));
  assertEquals(companies, [{ id: REALM, name: 'Acme Ltd', country: 'GB', currency: 'GBP' }]);
  assertEquals(
    requests[0].url.pathname,
    `/v3/company/${REALM}/companyinfo/${REALM}`,
  );
  assertEquals(requests[0].url.host, 'sandbox-quickbooks.api.intuit.com');
});

Deno.test('quickbooks: createExpense posts a Purchase with account-based lines', async () => {
  const { qbo, requests } = adapter([
    jsonResponse({ Account: { Id: '41', AccountType: 'Credit Card' } }),
    jsonResponse({ Purchase: { Id: '145', SyncToken: '0' } }),
  ], 'production');
  const record = await qbo.createExpense(ctx, draft);
  assertEquals(record, { externalId: '145', externalType: 'Purchase' });

  const [account, create] = requests;
  assertEquals(account.method, 'GET');
  assertEquals(account.url.pathname, `/v3/company/${REALM}/account/41`);

  assertEquals(create.method, 'POST');
  assertEquals(create.url.origin, 'https://quickbooks.api.intuit.com');
  assertEquals(create.url.pathname, `/v3/company/${REALM}/purchase`);
  assertEquals(create.url.searchParams.get('minorversion'), QBO_MINOR_VERSION);
  assertEquals(create.headers.get('authorization'), 'Bearer access-1');
  assertEquals(create.headers.get('accept'), 'application/json');
  assertEquals(create.headers.get('content-type'), 'application/json');
  const body = jsonBody(create);
  assertEquals(body.PaymentType, 'CreditCard');
  assertEquals(body.AccountRef, { value: '41' });
  assertEquals(body.TxnDate, '2026-09-20');
  assertEquals(body.CurrencyRef, { value: 'GBP' });
  assertEquals(body.GlobalTaxCalculation, 'TaxExcluded');
  assertEquals(body.DocNumber, 'VL-0f8fad5b');
  assertEquals(body.Line, [{
    DetailType: 'AccountBasedExpenseLineDetail',
    Amount: 20,
    Description: 'Staples — printer paper',
    AccountBasedExpenseLineDetail: {
      AccountRef: { value: '7' },
      TaxCodeRef: { value: '5' },
      BillableStatus: 'NotBillable',
    },
  }]);
});

Deno.test('quickbooks: without tax codes the gross amount is sent and no tax mode', async () => {
  const { qbo, requests } = adapter([
    jsonResponse({ Account: { Id: '41', AccountType: 'Bank' } }),
    jsonResponse({ Purchase: { Id: '146' } }),
  ]);
  await qbo.createExpense(ctx, {
    ...draft,
    lines: [{ ...draft.lines[0], taxCodeId: null }],
  });
  const body = jsonBody(requests[1]);
  assertEquals(body.PaymentType, 'Cash');
  assertEquals(body.GlobalTaxCalculation, undefined);
  assertEquals((body.Line as { Amount: number }[])[0].Amount, 24);
});

Deno.test('quickbooks: updateExpense sends the current SyncToken', async () => {
  const { qbo, requests } = adapter([
    jsonResponse({ Purchase: { Id: '145', SyncToken: '3' } }),
    jsonResponse({ Account: { Id: '41', AccountType: 'Bank' } }),
    jsonResponse({ Purchase: { Id: '145', SyncToken: '4' } }),
  ]);
  await qbo.updateExpense(ctx, { externalId: '145', externalType: 'Purchase' }, draft);
  assertEquals(requests[0].url.pathname, `/v3/company/${REALM}/purchase/145`);
  const body = jsonBody(requests[2]);
  assertEquals(body.Id, '145');
  assertEquals(body.SyncToken, '3');
  assertEquals(body.sparse, false);
});

Deno.test('quickbooks: deleteExpense uses operation=delete', async () => {
  const { qbo, requests } = adapter([
    jsonResponse({ Purchase: { Id: '145', SyncToken: '4' } }),
    jsonResponse({ Purchase: { Id: '145', status: 'Deleted' } }),
  ]);
  await qbo.deleteExpense(ctx, { externalId: '145', externalType: 'Purchase' });
  assertEquals(requests[1].url.searchParams.get('operation'), 'delete');
  assertEquals(jsonBody(requests[1]), { Id: '145', SyncToken: '4' });
});

Deno.test('quickbooks: attachReceipt uploads an Attachable linked to the Purchase', async () => {
  const { qbo, requests } = adapter([
    jsonResponse({ AttachableResponse: [{ Attachable: { Id: '5000000000000010' } }] }),
  ]);
  const id = await qbo.attachReceipt(ctx, { externalId: '145', externalType: 'Purchase' }, {
    fileName: 'receipt-1.jpg',
    contentType: 'image/jpeg',
    bytes: JPEG_BYTES,
  });
  assertEquals(id, '5000000000000010');
  const [req] = requests;
  assertEquals(req.method, 'POST');
  assertEquals(req.url.pathname, `/v3/company/${REALM}/upload`);
  assertEquals(req.headers.get('authorization'), 'Bearer access-1');
  // FormData sets its own multipart boundary.
  assertEquals(req.headers.get('content-type'), null);
  const form = req.body as FormData;
  const metadata = JSON.parse(await (form.get('file_metadata_01') as Blob).text());
  assertEquals(metadata.AttachableRef, [{ EntityRef: { type: 'Purchase', value: '145' } }]);
  assertEquals(metadata.FileName, 'receipt-1.jpg');
  const file = form.get('file_content_01') as File;
  assertEquals(file.type, 'image/jpeg');
  assertEquals(file.name, 'receipt-1.jpg');
  assertEquals(new Uint8Array(await file.arrayBuffer()), JPEG_BYTES);
});

Deno.test('quickbooks: HTTP errors map to retryable or not', async () => {
  const cases: [Response, string, boolean][] = [
    [jsonResponse({ fault: { error: [{ message: 'AuthenticationFailed' }] } }, 401), 'auth', false],
    [jsonResponse({}, 429, { 'Retry-After': '30' }), 'rate_limited', true],
    [jsonResponse({}, 503), 'transient', true],
    [
      jsonResponse({
        Fault: { Error: [{ Message: 'Invalid Reference Id', Detail: 'Account 7', code: '2500' }] },
      }, 400),
      'permanent',
      false,
    ],
    [
      jsonResponse({ Fault: { Error: [{ Message: 'Object Not Found', code: '610' }] } }, 400),
      'not_found',
      false,
    ],
    [
      jsonResponse({ Fault: { Error: [{ Message: 'Stale Object Error', code: '5010' }] } }, 400),
      'transient',
      true,
    ],
  ];
  for (const [response, kind, retryable] of cases) {
    const { qbo } = adapter([response]);
    const error = await assertRejects(
      () => qbo.listExpenseAccounts(ctx),
      AccountingError,
    );
    assertEquals(error.kind, kind, `status ${response.status}`);
    assertEquals(error.retryable, retryable);
    if (kind === 'rate_limited') assertEquals(error.retryAfterSeconds, 30);
    if (kind === 'permanent') assert(error.message.includes('Invalid Reference Id: Account 7'));
  }
});

Deno.test('quickbooks: a network failure is transient', async () => {
  const { qbo } = adapter([() => Promise.reject(new TypeError('connection reset'))]);
  const error = await assertRejects(() => qbo.listTaxCodes(ctx), AccountingError);
  assertEquals(error.kind, 'transient');
});

Deno.test('quickbooks: tax codes carry their purchase rate', async () => {
  const { qbo } = adapter([
    jsonResponse({
      QueryResponse: {
        TaxCode: [
          {
            Id: '5',
            Name: '20.0% S',
            PurchaseTaxRateList: { TaxRateDetail: [{ TaxRateRef: { value: '9' } }] },
          },
          {
            Id: '6',
            Name: 'Sales only',
            SalesTaxRateList: { TaxRateDetail: [{ TaxRateRef: { value: '10' } }] },
          },
          { Id: '7', Name: 'No VAT' },
        ],
      },
    }),
    jsonResponse({
      QueryResponse: { TaxRate: [{ Id: '9', RateValue: 20 }, { Id: '10', RateValue: 20 }] },
    }),
  ]);
  const codes = await qbo.listTaxCodes(ctx);
  assertEquals(codes, [
    { id: '5', name: '20.0% S', rate: 20 },
    { id: '7', name: 'No VAT', rate: null },
  ]);
});
