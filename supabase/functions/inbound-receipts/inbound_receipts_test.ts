// deno-lint-ignore no-import-prefix -- CI runs from the repo root, where this folder's deno.json is not read.
import { assert, assertEquals, assertMatch, assertThrows } from 'jsr:@std/assert@1';
import {
  base64DecodedLength,
  checkAttachments,
  MAX_ATTACHMENT_BYTES,
  MAX_ATTACHMENTS,
  receiptIdFor,
  receiptPath,
  sniffKind,
} from './attachments.ts';
import { extractUrl, requestExtraction } from './extract.ts';
import { handleInbound, type InboundStore } from './handler.ts';
import { inboundToken, parseInboundEmail, PayloadError } from './payload.ts';
import { hmacSha256Hex, verifySignature } from './signature.ts';

const SECRET = 'test-webhook-secret';
const DOMAIN = 'in.veralify.test';
const TOKEN = '3f9c2a7b1d4e5f6a7b8c9d0e';
const USER = '11111111-1111-4111-8111-111111111111';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function jpeg(size = 20_000, seed = 1): Uint8Array {
  const bytes = new Uint8Array(size);
  bytes.set([0xff, 0xd8, 0xff, 0xe0]);
  for (let i = 4; i < size; i++) bytes[i] = (i * seed) % 251;
  return bytes;
}

function png(size = 20_000): Uint8Array {
  const bytes = new Uint8Array(size);
  bytes.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  return bytes;
}

const pdf = new TextEncoder().encode('%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\n%%EOF\n');

function attachment(filename: string, bytes: Uint8Array, contentType = 'application/octet-stream') {
  return { filename, contentType, contentBase64: bytesToBase64(bytes) };
}

function memoryStore(options: { enabled?: boolean; existing?: string[] } = {}) {
  const uploads: { path: string; size: number; contentType: string }[] = [];
  const rows: { id: string; user_id: string; image_paths: string[]; source: string }[] = [];
  const existing = new Set(options.existing ?? []);
  const store: InboundStore = {
    findAddress: (token) =>
      Promise.resolve(token === TOKEN ? { userId: USER, enabled: options.enabled ?? true } : null),
    homeCurrency: () => Promise.resolve('GBP'),
    receiptExists: (id) => Promise.resolve(existing.has(id)),
    uploadReceiptFile: (path, bytes, contentType) => {
      uploads.push({ path, size: bytes.length, contentType });
      return Promise.resolve();
    },
    insertReceipt: (row) => {
      if (existing.has(row.id)) return Promise.resolve('duplicate' as const);
      existing.add(row.id);
      rows.push(row);
      return Promise.resolve('inserted' as const);
    },
  };
  return { store, uploads, rows };
}

interface Captured {
  url: string;
  headers: Headers;
  body: Record<string, unknown>;
}

function mockExtractFetch(responder: (call: number) => Response = () => Response.json({})) {
  const calls: Captured[] = [];
  const fetchImpl = ((input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({
      url: String(input),
      headers: new Headers(init?.headers),
      body: JSON.parse(String(init?.body)),
    });
    return Promise.resolve(responder(calls.length));
  }) as typeof fetch;
  return { fetchImpl, calls };
}

async function signedRequest(payload: unknown, secret = SECRET, tamper = false) {
  const body = new TextEncoder().encode(JSON.stringify(payload));
  const signature = await hmacSha256Hex(secret, body);
  const sent = tamper ? new TextEncoder().encode(JSON.stringify(payload) + ' ') : body;
  return new Request('https://example.test/functions/v1/inbound-receipts', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Inbound-Signature': `sha256=${signature}` },
    body: sent,
  });
}

function email(attachments: unknown[], to: unknown = `Receipts <receipts+${TOKEN}@${DOMAIN}>`) {
  return { to, from: 'Shop <orders@shop.example>', subject: 'Your receipt', attachments };
}

async function run(req: Request, store: InboundStore, fetchImpl?: typeof fetch) {
  const background: Promise<unknown>[] = [];
  const response = await handleInbound(req, {
    secret: SECRET,
    domain: DOMAIN,
    supabaseUrl: 'https://project.supabase.co/',
    serviceRoleKey: 'service-role-key',
    store,
    fetchImpl,
    background: (work) => background.push(work),
    log: () => {},
  });
  await Promise.all(background);
  return { response, body: await response.json(), background };
}

// ---------------------------------------------------------------------------
// Signature
// ---------------------------------------------------------------------------

Deno.test('signature: HMAC-SHA256 of the raw body, bare or sha256= prefixed', async () => {
  const body = new TextEncoder().encode('{"a":1}');
  const hex = await hmacSha256Hex(SECRET, body);
  assertMatch(hex, /^[0-9a-f]{64}$/);
  assertEquals(await verifySignature(SECRET, body, hex), true);
  assertEquals(await verifySignature(SECRET, body, `sha256=${hex.toUpperCase()}`), true);
  assertEquals(await verifySignature('other-secret', body, hex), false);
  assertEquals(await verifySignature(SECRET, new TextEncoder().encode('{"a": 1}'), hex), false);
  assertEquals(await verifySignature(SECRET, body, null), false);
  assertEquals(await verifySignature(SECRET, body, 'sha256=nothex'), false);
  assertEquals(await verifySignature('', body, hex), false);
});

Deno.test('webhook: a bad or missing signature is refused before anything is read', async () => {
  const { store, uploads } = memoryStore();
  const tampered = await signedRequest(email([attachment('r.jpg', jpeg())]), SECRET, true);
  assertEquals((await run(tampered, store)).response.status, 401);
  const wrongKey = await signedRequest(email([attachment('r.jpg', jpeg())]), 'wrong');
  assertEquals((await run(wrongKey, store)).response.status, 401);
  const unsigned = new Request('https://example.test', { method: 'POST', body: '{}' });
  assertEquals((await run(unsigned, store)).response.status, 401);
  assertEquals(uploads.length, 0);
});

Deno.test('webhook: only POST', async () => {
  const { store } = memoryStore();
  const result = await run(new Request('https://example.test', { method: 'GET' }), store);
  assertEquals(result.response.status, 405);
});

// ---------------------------------------------------------------------------
// Payload and token lookup
// ---------------------------------------------------------------------------

Deno.test('payload: shape is validated', () => {
  assertThrows(() => parseInboundEmail([]), PayloadError);
  assertThrows(() => parseInboundEmail({ to: 42 }), PayloadError);
  assertThrows(() => parseInboundEmail({ to: 'a@b', attachments: {} }), PayloadError);
  assertThrows(
    () => parseInboundEmail({ to: 'a@b', attachments: [{ filename: 'x' }] }),
    PayloadError,
  );
  const parsed = parseInboundEmail({ to: ['a@b', 'c@d'] });
  assertEquals(parsed, { to: ['a@b', 'c@d'], from: '', subject: '', attachments: [] });
});

Deno.test('token: found among several recipients, display names and case ignored', () => {
  assertEquals(inboundToken([`receipts+${TOKEN}@${DOMAIN}`], DOMAIN), TOKEN);
  assertEquals(
    inboundToken([
      `Me <me@home.example>, "Receipts" <RECEIPTS+${TOKEN.toUpperCase()}@IN.Veralify.test>`,
    ], DOMAIN),
    TOKEN,
  );
  assertEquals(inboundToken(['x@y.example', `receipts+${TOKEN}@${DOMAIN}`], DOMAIN), TOKEN);
});

Deno.test('token: other domains, other mailboxes and malformed tokens are not matched', () => {
  assertEquals(inboundToken([`receipts+${TOKEN}@evil.example`], DOMAIN), null);
  assertEquals(inboundToken([`billing+${TOKEN}@${DOMAIN}`], DOMAIN), null);
  assertEquals(inboundToken([`receipts+short@${DOMAIN}`], DOMAIN), null);
  assertEquals(inboundToken([`receipts+${TOKEN}-x@${DOMAIN}`], DOMAIN), null);
  assertEquals(inboundToken([`receipts+${TOKEN}@${DOMAIN}`], ''), null);
});

Deno.test('webhook: unknown, paused or missing recipients are acknowledged and ignored', async () => {
  const unknown = memoryStore();
  const req = await signedRequest(
    email([attachment('r.jpg', jpeg())], `receipts+aaaaaaaaaaaaaaaaaaaaaaaa@${DOMAIN}`),
  );
  const result = await run(req, unknown.store);
  assertEquals(result.response.status, 200);
  assertEquals(result.body.ignored, 'unknown_recipient');
  assertEquals(unknown.uploads.length, 0);

  const paused = memoryStore({ enabled: false });
  const pausedResult = await run(
    await signedRequest(email([attachment('r.jpg', jpeg())])),
    paused.store,
  );
  assertEquals(pausedResult.body.ignored, 'disabled');
  assertEquals(paused.rows.length, 0);

  const nobody = memoryStore();
  const nobodyResult = await run(
    await signedRequest(email([], 'someone@else.example')),
    nobody.store,
  );
  assertEquals(nobodyResult.body.ignored, 'no_recipient');
});

Deno.test('webhook: invalid JSON is a 400', async () => {
  const { store } = memoryStore();
  const body = new TextEncoder().encode('not json');
  const req = new Request('https://example.test', {
    method: 'POST',
    headers: { 'X-Inbound-Signature': await hmacSha256Hex(SECRET, body) },
    body,
  });
  const result = await run(req, store);
  assertEquals(result.response.status, 400);
  assertEquals(result.body.error, 'INVALID_PAYLOAD');
});

// ---------------------------------------------------------------------------
// Attachments
// ---------------------------------------------------------------------------

Deno.test('attachments: type comes from the bytes, not the declared content type', () => {
  assertEquals(sniffKind(jpeg()), 'jpeg');
  assertEquals(sniffKind(png()), 'png');
  assertEquals(sniffKind(pdf), 'pdf');
  assertEquals(sniffKind(new TextEncoder().encode('<html>')), null);
  // HEIC: ftypheic box
  assertEquals(
    sniffKind(new Uint8Array([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63])),
    null,
  );
});

Deno.test('attachments: oversized, unsupported, tiny and broken files are rejected', () => {
  const huge = 'A'.repeat(Math.ceil(((MAX_ATTACHMENT_BYTES + 3) * 4) / 3));
  assert(base64DecodedLength(huge) > MAX_ATTACHMENT_BYTES);
  const checked = checkAttachments([
    { filename: 'huge.jpg', contentType: 'image/jpeg', contentBase64: huge },
    attachment('page.html', new TextEncoder().encode('<html>'.repeat(3000)), 'text/html'),
    attachment('logo.png', png(900), 'image/png'),
    { filename: 'broken.pdf', contentType: 'application/pdf', contentBase64: '%%%not base64' },
    attachment('receipt.pdf', pdf, 'application/pdf'),
  ]);
  assertEquals(
    checked.map((item) => (item.ok ? item.kind : item.reason)),
    ['too_large', 'unsupported_type', 'too_small', 'invalid_base64', 'pdf'],
  );
});

Deno.test('attachments: MIME line breaks in base64 are tolerated', () => {
  const wrapped = bytesToBase64(jpeg()).replace(/(.{76})/g, '$1\r\n');
  const [checked] = checkAttachments([{
    filename: 'r.jpg',
    contentType: '',
    contentBase64: wrapped,
  }]);
  assertEquals(checked.ok, true);
});

Deno.test('attachments: at most MAX_ATTACHMENTS are kept', () => {
  const many = Array.from(
    { length: MAX_ATTACHMENTS + 2 },
    (_, i) => attachment(`${i}.jpg`, jpeg(20_000, i + 1)),
  );
  const checked = checkAttachments(many);
  assertEquals(checked.filter((item) => item.ok).length, MAX_ATTACHMENTS);
  assertEquals(checked.at(-1), {
    ok: false,
    filename: `${MAX_ATTACHMENTS + 1}.jpg`,
    reason: 'too_many_attachments',
  });
});

Deno.test('receipt ids are UUIDs derived from the user and the file', async () => {
  const a = await receiptIdFor(USER, jpeg());
  assertMatch(a, /^[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assertEquals(await receiptIdFor(USER, jpeg()), a, 'same file, same user: same id');
  assert(a !== (await receiptIdFor('22222222-2222-4222-8222-222222222222', jpeg())), 'per user');
  assert(a !== (await receiptIdFor(USER, jpeg(20_000, 7))), 'per file');
  assertEquals(receiptPath(USER, a, 'jpeg'), `${USER}/${a}/1.jpg`);
  assertEquals(receiptPath(USER, a, 'pdf'), `${USER}/${a}/1.pdf`);
});

// ---------------------------------------------------------------------------
// End to end, network mocked
// ---------------------------------------------------------------------------

Deno.test('webhook: stores each usable attachment, creates email receipts, then asks for extraction', async () => {
  const { store, uploads, rows } = memoryStore();
  const { fetchImpl, calls } = mockExtractFetch();
  const req = await signedRequest(email([
    attachment('photo.jpg', jpeg(), 'image/jpeg'),
    attachment('invoice.pdf', pdf),
    attachment('logo.png', png(500), 'image/png'),
  ]));
  const { response, body } = await run(req, store, fetchImpl);

  assertEquals(response.status, 200);
  assertEquals(body.receipts.map((r: { status: string }) => r.status), ['created', 'created']);
  assertEquals(body.rejected, [{ filename: 'logo.png', reason: 'too_small' }]);

  const [photoId, invoiceId] = body.receipts.map((r: { receipt_id: string }) => r.receipt_id);
  assertEquals(uploads, [
    { path: `${USER}/${photoId}/1.jpg`, size: 20_000, contentType: 'image/jpeg' },
    { path: `${USER}/${invoiceId}/1.pdf`, size: pdf.length, contentType: 'application/pdf' },
  ]);
  assertEquals(rows, [
    { id: photoId, user_id: USER, image_paths: [`${USER}/${photoId}/1.jpg`], source: 'email' },
    { id: invoiceId, user_id: USER, image_paths: [`${USER}/${invoiceId}/1.pdf`], source: 'email' },
  ]);

  // Service-role form of receipts-extract (contract §5).
  assertEquals(calls.length, 2);
  assertEquals(
    calls[0].url,
    'https://project.supabase.co/functions/v1/ai-gateway/receipts-extract',
  );
  assertEquals(calls[0].headers.get('authorization'), 'Bearer service-role-key');
  assertEquals(calls[0].headers.get('apikey'), 'service-role-key');
  assertEquals(calls[0].body, {
    receipt_id: photoId,
    user_id: USER,
    locale: 'en-GB',
    home_currency: 'GBP',
  });
  assertEquals(calls[1].body.receipt_id, invoiceId);
});

Deno.test('webhook: a retried or re-forwarded e-mail does not duplicate or rescan', async () => {
  const { store, rows, uploads } = memoryStore();
  const { fetchImpl, calls } = mockExtractFetch();
  const payload = email([attachment('photo.jpg', jpeg())]);
  await run(await signedRequest(payload), store, fetchImpl);
  const second = await run(await signedRequest(payload), store, fetchImpl);
  assertEquals(second.body.receipts[0].status, 'duplicate');
  assertEquals(rows.length, 1);
  assertEquals(uploads.length, 1);
  assertEquals(calls.length, 1);
});

Deno.test('webhook: nothing to read means no extraction call', async () => {
  const { store } = memoryStore();
  const { fetchImpl, calls } = mockExtractFetch();
  const { body, background } = await run(await signedRequest(email([])), store, fetchImpl);
  assertEquals(body.receipts, []);
  assertEquals(background.length, 0);
  assertEquals(calls.length, 0);
});

Deno.test('webhook: the scan limit stops further extraction calls', async () => {
  const { store } = memoryStore();
  const { fetchImpl, calls } = mockExtractFetch(() =>
    Response.json({ error: 'SCAN_LIMIT_REACHED', message: 'Monthly limit' }, { status: 402 })
  );
  const req = await signedRequest(email([
    attachment('a.jpg', jpeg(20_000, 2)),
    attachment('b.jpg', jpeg(20_000, 3)),
  ]));
  const { body } = await run(req, store, fetchImpl);
  assertEquals(body.receipts.length, 2, 'both receipts are still stored for later');
  assertEquals(calls.length, 1);
});

Deno.test('extract: gateway errors and network failures are reported, not thrown', async () => {
  assertEquals(
    extractUrl('https://p.supabase.co///'),
    'https://p.supabase.co/functions/v1/ai-gateway/receipts-extract',
  );
  const base = {
    supabaseUrl: 'https://p.supabase.co',
    serviceRoleKey: 'k',
    userId: USER,
    receiptId: 'r1',
    homeCurrency: 'EUR',
  };

  const unreadable = await requestExtraction({
    ...base,
    fetchImpl: mockExtractFetch(() =>
      Response.json({ error: 'UNREADABLE' }, { status: 422 })
    ).fetchImpl,
  });
  assertEquals(unreadable, { receipt_id: 'r1', ok: false, status: 422, error: 'UNREADABLE' });

  const plain = await requestExtraction({
    ...base,
    fetchImpl: mockExtractFetch(() => new Response('Bad gateway', { status: 502 })).fetchImpl,
  });
  assertEquals(plain.error, 'HTTP_502');

  const offline = await requestExtraction({
    ...base,
    fetchImpl: (() => Promise.reject(new TypeError('dns'))) as typeof fetch,
  });
  assertEquals(offline, { receipt_id: 'r1', ok: false, status: 0, error: 'NETWORK_ERROR' });

  const ok = await requestExtraction({ ...base, fetchImpl: mockExtractFetch().fetchImpl });
  assertEquals(ok, { receipt_id: 'r1', ok: true, status: 200 });
});

Deno.test('webhook: storage failure surfaces as an error so the provider retries', async () => {
  const { store } = memoryStore();
  store.uploadReceiptFile = () => Promise.reject(new Error('storage down'));
  let thrown: unknown;
  try {
    await run(await signedRequest(email([attachment('a.jpg', jpeg())])), store);
  } catch (error) {
    thrown = error;
  }
  assert(thrown instanceof Error && thrown.message === 'storage down');
});
