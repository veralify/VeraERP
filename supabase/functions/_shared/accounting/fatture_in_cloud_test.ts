import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { FattureInCloudAdapter, FIC_API_BASE } from './fatture_in_cloud.ts';
import {
  JPEG_BYTES,
  jsonBody,
  jsonResponse,
  sampleDraft,
  scriptedFetch,
  testTokens,
} from './testing.ts';
import { AccountingError } from './types.ts';

const COMPANY = '123456';

function adapter(responses: Parameters<typeof scriptedFetch>[0]) {
  const mock = scriptedFetch(responses);
  return {
    fic: new FattureInCloudAdapter({
      clientId: 'ficid',
      clientSecret: 'ficsecret',
      fetch: mock.fetch,
    }),
    requests: mock.requests,
  };
}

const ctx = { companyId: COMPANY, tokens: testTokens() };

// €12.50 at the Italian 22% rate: 10.25 + 2.25.
const draft = sampleDraft({
  merchant: 'Esselunga',
  description: 'Esselunga',
  currency: 'EUR',
  total: '12.50',
  taxTotal: '2.25',
  lines: [{
    description: 'Esselunga',
    accountId: 'Spesa',
    taxCodeId: '0',
    vatRate: '22',
    net: '10.25',
    tax: '2.25',
    gross: '12.50',
  }],
  paymentAccountId: '42',
});

Deno.test('fatture in cloud: code exchange posts client credentials as JSON', async () => {
  const { fic, requests } = adapter([
    jsonResponse({
      access_token: 'a/1',
      refresh_token: 'r/1',
      expires_in: 86400,
      token_type: 'bearer',
    }),
  ]);
  const tokens = await fic.exchangeCode({ code: 'c', redirectUri: 'https://fn.test/cb' });
  assertEquals(requests[0].url.toString(), `${FIC_API_BASE}/oauth/token`);
  assertEquals(requests[0].headers.get('content-type'), 'application/json');
  assertEquals(jsonBody(requests[0]), {
    grant_type: 'authorization_code',
    client_id: 'ficid',
    client_secret: 'ficsecret',
    redirect_uri: 'https://fn.test/cb',
    code: 'c',
  });
  assertEquals(tokens.refresh_token, 'r/1');
});

Deno.test('fatture in cloud: companies include those an accountant controls', async () => {
  const { fic } = adapter([
    jsonResponse({
      data: {
        companies: [
          { id: 1, name: 'Studio Rossi', controlled_companies: [{ id: 2, name: 'Cliente Srl' }] },
          { id: 2, name: 'Cliente Srl' },
        ],
      },
    }),
  ]);
  const companies = await fic.listCompanies(testTokens(), new URLSearchParams());
  assertEquals(companies.map((c) => [c.id, c.name, c.country, c.currency]), [
    ['1', 'Studio Rossi', 'IT', 'EUR'],
    ['2', 'Cliente Srl', 'IT', 'EUR'],
  ]);
});

Deno.test('fatture in cloud: createExpense posts a detailed received document of type expense', async () => {
  const { fic, requests } = adapter([jsonResponse({ data: { id: 777, type: 'expense' } })]);
  const record = await fic.createExpense(ctx, draft);
  assertEquals(record, { externalId: '777', externalType: 'received_document' });
  const [req] = requests;
  assertEquals(req.method, 'POST');
  assertEquals(req.url.toString(), `${FIC_API_BASE}/c/${COMPANY}/received_documents`);
  assertEquals(req.headers.get('authorization'), 'Bearer access-1');
  assertEquals(req.headers.get('content-type'), 'application/json');
  const data = jsonBody(req).data as Record<string, unknown>;
  assertEquals(data.type, 'expense');
  assertEquals(data.entity, { name: 'Esselunga' });
  assertEquals(data.date, '2026-09-20');
  assertEquals(data.currency, { id: 'EUR' });
  assertEquals(data.amount_net, 10.25);
  assertEquals(data.amount_vat, 2.25);
  assertEquals(data.is_detailed, true);
  assertEquals(data.items_list, [{
    name: 'Esselunga',
    qty: 1,
    net_price: 10.25,
    category: 'Spesa',
    vat: { id: 0 },
  }]);
  assertEquals(data.payments_list, [{
    amount: 12.5,
    due_date: '2026-09-20',
    paid_date: '2026-09-20',
    status: 'paid',
    payment_account: { id: 42 },
  }]);
});

Deno.test('fatture in cloud: without IVA mappings the document carries totals only', async () => {
  const { fic, requests } = adapter([jsonResponse({ data: { id: 778 } })]);
  await fic.createExpense(ctx, {
    ...draft,
    lines: [{ ...draft.lines[0], taxCodeId: null }],
    paymentAccountId: null,
  });
  const data = jsonBody(requests[0]).data as Record<string, unknown>;
  assertEquals(data.is_detailed, false);
  assertEquals(data.items_list, undefined);
  assertEquals(data.payments_list, undefined);
});

Deno.test('fatture in cloud: attachReceipt uploads, then sets the token on the document', async () => {
  const { fic, requests } = adapter([
    jsonResponse({ data: { attachment_token: 'tok-1' } }),
    jsonResponse({ data: { id: 777 } }),
  ]);
  const id = await fic.attachReceipt(
    ctx,
    { externalId: '777', externalType: 'received_document' },
    {
      fileName: 'receipt-1.jpg',
      contentType: 'image/jpeg',
      bytes: JPEG_BYTES,
    },
  );
  assertEquals(id, 'tok-1');
  const [upload, attach] = requests;
  assertEquals(upload.method, 'POST');
  assertEquals(upload.url.toString(), `${FIC_API_BASE}/c/${COMPANY}/received_documents/attachment`);
  const form = upload.body as FormData;
  assertEquals(form.get('filename'), 'receipt-1.jpg');
  const file = form.get('attachment') as File;
  assertEquals(file.type, 'image/jpeg');
  assertEquals(new Uint8Array(await file.arrayBuffer()), JPEG_BYTES);
  assertEquals(attach.method, 'PUT');
  assertEquals(attach.url.toString(), `${FIC_API_BASE}/c/${COMPANY}/received_documents/777`);
  assertEquals(jsonBody(attach), { data: { attachment_token: 'tok-1' } });
});

Deno.test('fatture in cloud: IVA rates come from vat_types', async () => {
  const { fic, requests } = adapter([
    jsonResponse({
      data: [
        { id: 0, value: 22, description: 'Ordinaria 22%' },
        { id: 3, value: 10, description: 'Ridotta 10%' },
        { id: 9, value: 4, description: 'Old', is_disabled: true },
      ],
    }),
  ]);
  assertEquals(await fic.listTaxCodes(ctx), [
    { id: '0', name: 'Ordinaria 22%', rate: 22 },
    { id: '3', name: 'Ridotta 10%', rate: 10 },
  ]);
  assertEquals(requests[0].url.pathname, `/c/${COMPANY}/info/vat_types`);
});

Deno.test('fatture in cloud: HTTP errors map to retryable or not', async () => {
  const cases: [Response, string, boolean][] = [
    [jsonResponse({ error: { message: 'Unauthorized' } }, 401), 'auth', false],
    [jsonResponse({ error: { message: 'Forbidden' } }, 403), 'permanent', false],
    [jsonResponse({}, 429, { 'Retry-After': '10' }), 'rate_limited', true],
    [jsonResponse({}, 500), 'transient', true],
    [
      jsonResponse({
        error: { message: 'Validation error', validation_result: { date: ['Invalid date'] } },
      }, 422),
      'permanent',
      false,
    ],
  ];
  for (const [response, kind, retryable] of cases) {
    const { fic } = adapter([response]);
    const error = await assertRejects(() => fic.createExpense(ctx, draft), AccountingError);
    assertEquals(error.kind, kind, `status ${response.status}`);
    assertEquals(error.retryable, retryable);
    if (response.status === 422) assert(error.message.includes('date: Invalid date'));
  }
});
