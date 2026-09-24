// Two small assertions rather than @std/assert: CI runs `deno test` from the
// repository root, where a function's own import map is not in effect, and
// inline jsr:/https: imports fail `deno lint`.
function assert(condition: unknown, message = 'assertion failed'): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown, message?: string): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${message ?? 'values differ'}\n  actual:   ${a}\n  expected: ${e}`);
}

import { type AccountDeleteConfig, bearerToken, configFromEnv, createHandler, listObjects } from './handler.ts';

const USER = '95000000-0000-0000-0000-000000000001';
const URL_BASE = 'https://project.supabase.test';
const SERVICE = 'service-role-key';
const ANON = 'anon-key';
const TOKEN = 'user.jwt.token';

interface Call {
  method: string;
  url: string;
  auth: string | null;
  body: unknown;
}

type Route = (call: Call) => Response | Promise<Response>;

/** A fake network: records every request and answers from `routes`, keyed "METHOD path". */
function fakeNetwork(routes: Record<string, Route>) {
  const calls: Call[] = [];
  const fetcher = async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const url = new URL(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url);
    const method = init?.method ?? 'GET';
    const headers = new Headers(init?.headers);
    const call: Call = {
      method,
      url: url.pathname,
      auth: headers.get('authorization'),
      body: typeof init?.body === 'string' ? JSON.parse(init.body) : undefined,
    };
    calls.push(call);
    const route = routes[`${method} ${url.pathname}`];
    if (!route) return new Response(`no route for ${method} ${url.pathname}`, { status: 599 });
    return await route(call);
  };
  const config: AccountDeleteConfig = {
    supabaseUrl: URL_BASE,
    anonKey: ANON,
    serviceRoleKey: SERVICE,
    fetch: fetcher as typeof fetch,
  };
  return { calls, config };
}

const ok = (body: unknown = {}) => () => Response.json(body);

/** A user with two receipts: one of two pages, one of one. */
function happyRoutes(overrides: Record<string, Route> = {}): Record<string, Route> {
  return {
    'GET /auth/v1/user': (call) =>
      call.auth === `Bearer ${TOKEN}` ? Response.json({ id: USER }) : new Response('bad jwt', { status: 401 }),
    'POST /rest/v1/rpc/account_delete_vault_secrets': ok(1),
    'POST /storage/v1/object/list/receipts': (call) => {
      const { prefix } = call.body as { prefix: string };
      if (prefix === USER) return Response.json([{ name: 'r1', id: null }, { name: 'r2', id: null }]);
      if (prefix === `${USER}/r1`) return Response.json([{ name: '1.jpg', id: 'a' }, { name: '2.jpg', id: 'b' }]);
      if (prefix === `${USER}/r2`) return Response.json([{ name: '1.jpg', id: 'c' }]);
      return Response.json([]);
    },
    'DELETE /storage/v1/object/receipts': ok([]),
    [`DELETE /auth/v1/admin/users/${USER}`]: ok({}),
    ...overrides,
  };
}

function request(options: { method?: string; auth?: string | null; body?: string } = {}): Request {
  const headers = new Headers({ 'content-type': 'application/json' });
  const auth = options.auth === undefined ? `Bearer ${TOKEN}` : options.auth;
  if (auth !== null) headers.set('authorization', auth);
  const method = options.method ?? 'POST';
  return new Request(`${URL_BASE}/functions/v1/account-delete`, {
    method,
    headers,
    body: method === 'GET' || method === 'OPTIONS' ? undefined : options.body ?? JSON.stringify({ confirm: true }),
  });
}

async function errorCode(response: Response): Promise<string> {
  return (await response.json()).error;
}

Deno.test('answers a CORS preflight without touching the network', async () => {
  const { calls, config } = fakeNetwork({});
  const response = await createHandler(() => config)(request({ method: 'OPTIONS' }));
  assertEquals(response.status, 200);
  assert(response.headers.get('access-control-allow-headers')?.includes('authorization'));
  assertEquals(calls.length, 0);
});

Deno.test('refuses anything but POST', async () => {
  const { calls, config } = fakeNetwork({});
  const response = await createHandler(() => config)(request({ method: 'GET' }));
  assertEquals(response.status, 405);
  assertEquals(await errorCode(response), 'METHOD_NOT_ALLOWED');
  assertEquals(calls.length, 0);
});

Deno.test('refuses a request without a bearer token before any call', async () => {
  const { calls, config } = fakeNetwork(happyRoutes());
  for (const auth of [null, '', 'Basic abc', 'Bearer', 'Bearer  ']) {
    const response = await createHandler(() => config)(request({ auth }));
    assertEquals(response.status, 401, `auth header ${JSON.stringify(auth)}`);
    assertEquals(await errorCode(response), 'UNAUTHENTICATED');
  }
  assertEquals(calls.length, 0);
});

Deno.test('requires an explicit confirmation in the body', async () => {
  const { calls, config } = fakeNetwork(happyRoutes());
  for (const body of ['', 'not json', '{}', '{"confirm":"true"}', '{"confirm":1}', '[true]', 'null']) {
    const response = await createHandler(() => config)(request({ body }));
    assertEquals(response.status, 400, `body ${body}`);
    assertEquals(await errorCode(response), 'CONFIRMATION_REQUIRED');
  }
  assertEquals(calls.length, 0);
});

Deno.test('refuses a token the auth server does not accept, and deletes nothing', async () => {
  const { calls, config } = fakeNetwork(happyRoutes());
  const response = await createHandler(() => config)(request({ auth: 'Bearer forged.token' }));
  assertEquals(response.status, 401);
  assertEquals(await errorCode(response), 'UNAUTHENTICATED');
  assertEquals(calls.map((c) => `${c.method} ${c.url}`), ['GET /auth/v1/user']);
});

Deno.test('refuses a token that verifies but names no user (the service role key)', async () => {
  const { calls, config } = fakeNetwork(happyRoutes({ 'GET /auth/v1/user': ok({}) }));
  const response = await createHandler(() => config)(request());
  assertEquals(response.status, 401);
  assertEquals(calls.length, 1);
});

Deno.test('deletes tokens, then receipt files, then the user — as the service role', async () => {
  const { calls, config } = fakeNetwork(happyRoutes());
  const response = await createHandler(() => config)(request());
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { ok: true });

  const steps = calls.map((c) => `${c.method} ${c.url}`);
  assertEquals(steps, [
    'GET /auth/v1/user',
    'POST /rest/v1/rpc/account_delete_vault_secrets',
    'POST /storage/v1/object/list/receipts',
    'POST /storage/v1/object/list/receipts',
    'POST /storage/v1/object/list/receipts',
    'DELETE /storage/v1/object/receipts',
    `DELETE /auth/v1/admin/users/${USER}`,
  ]);
  assertEquals(calls[1].body, { p_user_id: USER });
  assertEquals((calls[5].body as { prefixes: string[] }).prefixes, [
    `${USER}/r1/1.jpg`,
    `${USER}/r1/2.jpg`,
    `${USER}/r2/1.jpg`,
  ]);
  assertEquals(calls[6].body, { should_soft_delete: false });
  // The user's token is only ever used to identify them.
  for (const call of calls.slice(1)) assertEquals(call.auth, `Bearer ${SERVICE}`);
});

Deno.test("only ever touches the caller's own folder", async () => {
  const { calls, config } = fakeNetwork(happyRoutes());
  await createHandler(() => config)(request());
  const prefixes = calls
    .filter((c) => c.url.startsWith('/storage/v1/object/list/'))
    .map((c) => (c.body as { prefix: string }).prefix);
  assert(prefixes.every((p) => p === USER || p.startsWith(`${USER}/`)));
});

Deno.test('keeps the account when removing files fails, so the app can retry', async () => {
  const { calls, config } = fakeNetwork(
    happyRoutes({ 'DELETE /storage/v1/object/receipts': () => new Response('storage down', { status: 503 }) }),
  );
  const response = await createHandler(() => config)(request());
  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), 'DELETE_FAILED');
  assert(!calls.some((c) => c.url.startsWith('/auth/v1/admin/users/')));
});

Deno.test('keeps the account when the Vault clean-up fails', async () => {
  const { calls, config } = fakeNetwork(
    happyRoutes({ 'POST /rest/v1/rpc/account_delete_vault_secrets': () => new Response('no', { status: 500 }) }),
  );
  const response = await createHandler(() => config)(request());
  assertEquals(response.status, 500);
  assert(!calls.some((c) => c.url.startsWith('/storage/') || c.url.startsWith('/auth/v1/admin/')));
});

Deno.test('a user already deleted by an earlier attempt counts as done', async () => {
  const { config } = fakeNetwork(
    happyRoutes({ [`DELETE /auth/v1/admin/users/${USER}`]: () => new Response('not found', { status: 404 }) }),
  );
  const response = await createHandler(() => config)(request());
  assertEquals(response.status, 200);
});

Deno.test('an account with no receipts skips the remove call', async () => {
  const { calls, config } = fakeNetwork(
    happyRoutes({ 'POST /storage/v1/object/list/receipts': ok([]) }),
  );
  const response = await createHandler(() => config)(request());
  assertEquals(response.status, 200);
  assert(!calls.some((c) => c.method === 'DELETE' && c.url.startsWith('/storage/')));
});

Deno.test('lists past the first page of a large folder', async () => {
  const page = (from: number, count: number) =>
    Array.from({ length: count }, (_, i) => ({ name: `${from + i}.jpg`, id: `id-${from + i}` }));
  const { config } = fakeNetwork({
    'POST /storage/v1/object/list/receipts': (call) => {
      const { offset } = call.body as { offset: number };
      return Response.json(offset === 0 ? page(0, 1000) : page(1000, 3));
    },
  });
  const paths = await listObjects(config, USER);
  assertEquals(paths.length, 1003);
  assertEquals(paths[1002], `${USER}/1002.jpg`);
});

Deno.test('an unreachable auth server is a retryable 503, not a 401', async () => {
  const { config } = fakeNetwork({
    'GET /auth/v1/user': () => {
      throw new TypeError('network down');
    },
  });
  const response = await createHandler(() => config)(request());
  assertEquals(response.status, 503);
  assertEquals(await errorCode(response), 'AUTH_UNAVAILABLE');
});

Deno.test('reports missing configuration instead of throwing', async () => {
  const response = await createHandler(() => {
    throw new Error('missing env');
  })(request());
  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), 'NOT_CONFIGURED');
});

Deno.test('reads its configuration from the function environment', () => {
  const saved = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_ANON_KEY'].map((k) => [k, Deno.env.get(k)]);
  try {
    Deno.env.set('SUPABASE_URL', `${URL_BASE}/`);
    Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', SERVICE);
    Deno.env.delete('SUPABASE_ANON_KEY');
    const config = configFromEnv();
    assertEquals(config.supabaseUrl, URL_BASE);
    assertEquals(config.anonKey, SERVICE);
    Deno.env.delete('SUPABASE_SERVICE_ROLE_KEY');
    let threw = false;
    try {
      configFromEnv();
    } catch {
      threw = true;
    }
    assert(threw);
  } finally {
    for (const [key, value] of saved) {
      if (value === undefined) Deno.env.delete(key!);
      else Deno.env.set(key!, value);
    }
  }
});

Deno.test('parses bearer tokens strictly', () => {
  assertEquals(bearerToken('Bearer abc.def'), 'abc.def');
  assertEquals(bearerToken('bearer abc'), 'abc');
  assertEquals(bearerToken('Bearer a b'), null);
  assertEquals(bearerToken(null), null);
});
