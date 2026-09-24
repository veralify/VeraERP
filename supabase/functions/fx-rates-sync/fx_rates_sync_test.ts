// deno-lint-ignore no-import-prefix -- CI runs from the repo root, where this folder's deno.json is not read.
import { assert, assertEquals, assertRejects, assertThrows } from 'jsr:@std/assert@1';
import { isServiceRoleRequest, timingSafeEqual } from './auth.ts';
import {
  ECB_DAILY_URL,
  ECB_HISTORY_90D_URL,
  EcbParseError,
  type FxRateRow,
  parseEcbRates,
} from './ecb.ts';
import { type RatesStore, syncRates, UpstreamError } from './sync.ts';

const daily = await Deno.readTextFile(new URL('./testdata/eurofxref-daily.xml', import.meta.url));
const history = await Deno.readTextFile(
  new URL('./testdata/eurofxref-hist-90d.xml', import.meta.url),
);

function memoryStore(existing = true) {
  const upserts: FxRateRow[][] = [];
  let backfills = 0;
  const store: RatesStore = {
    hasAnyRates: () => Promise.resolve(existing),
    upsertRates: (rows) => {
      upserts.push(rows);
      return Promise.resolve();
    },
    backfillHomeAmounts: () => {
      backfills++;
      return Promise.resolve(3);
    },
  };
  return { store, upserts, backfills: () => backfills };
}

function mockFetch(body: string, status = 200) {
  const calls: string[] = [];
  const fetchImpl = ((input: RequestInfo | URL) => {
    calls.push(String(input));
    return Promise.resolve(new Response(body, { status }));
  }) as typeof fetch;
  return { fetchImpl, calls };
}

Deno.test('parses the ECB daily document into EUR-based rows', () => {
  const rows = parseEcbRates(daily);
  assertEquals(rows.length, 29);
  assertEquals(rows[0], {
    rate_date: '2026-09-23',
    base: 'EUR',
    quote: 'USD',
    rate: '1.1734',
    source: 'ecb',
  });
  const gbp = rows.find((row) => row.quote === 'GBP');
  assertEquals(gbp?.rate, '0.87115', 'rate keeps every published digit as a string');
  assert(rows.every((row) => row.rate_date === '2026-09-23'));
});

Deno.test('parses every day of the history document, double-quoted attributes included', () => {
  const rows = parseEcbRates(history);
  assertEquals(rows.length, 12);
  assertEquals([...new Set(rows.map((row) => row.rate_date))], [
    '2026-09-23',
    '2026-09-22',
    '2026-09-19',
  ]);
  assertEquals(
    rows.find((row) => row.rate_date === '2026-09-19' && row.quote === 'JPY')?.rate,
    '172.98',
  );
});

Deno.test('attribute order and whitespace do not matter', () => {
  const xml = `<Cube><Cube  time = "2026-01-02" ><Cube rate="0.9" currency="CHF" /></Cube></Cube>`;
  assertEquals(parseEcbRates(xml), [
    { rate_date: '2026-01-02', base: 'EUR', quote: 'CHF', rate: '0.9', source: 'ecb' },
  ]);
});

Deno.test('malformed entries are skipped, never guessed', () => {
  const xml = `<Cube>
    <Cube time='2026-02-30'><Cube currency='USD' rate='1.1'/></Cube>
    <Cube time='2026-03-02'>
      <Cube currency='usd' rate='1.1'/>
      <Cube currency='GBP' rate='-0.8'/>
      <Cube currency='JPY' rate='1e3'/>
      <Cube currency='CHF' rate='0'/>
      <Cube currency='EUR' rate='1'/>
      <Cube currency='SEK' rate='11.2'/>
      <Cube currency='SEK' rate='99'/>
    </Cube>
  </Cube>`;
  assertEquals(parseEcbRates(xml), [
    { rate_date: '2026-03-02', base: 'EUR', quote: 'SEK', rate: '11.2', source: 'ecb' },
  ]);
});

Deno.test('a document without rates is an error, not an empty sync', () => {
  assertThrows(() => parseEcbRates('<html><body>Service unavailable</body></html>'), EcbParseError);
});

Deno.test('daily run fetches today, upserts and backfills home amounts', async () => {
  const { store, upserts, backfills } = memoryStore(true);
  const { fetchImpl, calls } = mockFetch(daily);
  const result = await syncRates({ store, fetchImpl });
  assertEquals(calls, [ECB_DAILY_URL]);
  assertEquals(upserts.flat().length, 29);
  assertEquals(backfills(), 1);
  assertEquals(result, {
    source: 'daily',
    days: 1,
    rows: 29,
    latest_date: '2026-09-23',
    home_amounts_filled: 3,
  });
});

Deno.test('an empty table loads the 90-day history first', async () => {
  const { store, upserts } = memoryStore(false);
  const { fetchImpl, calls } = mockFetch(history);
  const result = await syncRates({ store, fetchImpl });
  assertEquals(calls, [ECB_HISTORY_90D_URL]);
  assertEquals(result.source, 'history');
  assertEquals(result.days, 3);
  assertEquals(result.latest_date, '2026-09-23');
  assertEquals(upserts.flat().length, 12);
});

Deno.test('backfill can be forced on a populated table', async () => {
  const { store } = memoryStore(true);
  const { fetchImpl, calls } = mockFetch(history);
  await syncRates({ store, fetchImpl, backfill: true });
  assertEquals(calls, [ECB_HISTORY_90D_URL]);
});

Deno.test('large documents are upserted in chunks', async () => {
  const days = Array.from({ length: 40 }, (_, i) => {
    const date = new Date(Date.UTC(2026, 0, 1 + i)).toISOString().slice(0, 10);
    const cubes = Array.from({ length: 30 }, (_, j) => {
      const code = `A${String.fromCharCode(65 + (j % 26))}${
        String.fromCharCode(65 + Math.floor(j / 26))
      }`;
      return `<Cube currency='${code}' rate='1.${j}'/>`;
    }).join('');
    return `<Cube time='${date}'>${cubes}</Cube>`;
  }).join('');
  const { store, upserts } = memoryStore(true);
  const { fetchImpl } = mockFetch(`<Cube>${days}</Cube>`);
  const result = await syncRates({ store, fetchImpl, backfill: true });
  assertEquals(result.rows, 1200);
  assertEquals(upserts.map((batch) => batch.length), [500, 500, 200]);
});

Deno.test('an ECB error status is an upstream failure and writes nothing', async () => {
  const { store, upserts, backfills } = memoryStore(true);
  const { fetchImpl } = mockFetch('Service Unavailable', 503);
  await assertRejects(() => syncRates({ store, fetchImpl }), UpstreamError, '503');
  assertEquals(upserts.length, 0);
  assertEquals(backfills(), 0);
});

Deno.test('a network failure is an upstream failure', async () => {
  const { store } = memoryStore(true);
  const fetchImpl = (() => Promise.reject(new TypeError('connection reset'))) as typeof fetch;
  await assertRejects(() => syncRates({ store, fetchImpl }), UpstreamError, 'connection reset');
});

Deno.test('only the service role key may run a sync', () => {
  const request = (auth?: string) =>
    new Request('https://example.test/functions/v1/fx-rates-sync', {
      method: 'POST',
      headers: auth ? { Authorization: auth } : {},
    });
  assertEquals(isServiceRoleRequest(request('Bearer service-key'), 'service-key'), true);
  assertEquals(isServiceRoleRequest(request('bearer service-key'), 'service-key'), true);
  assertEquals(isServiceRoleRequest(request('Bearer user-jwt'), 'service-key'), false);
  assertEquals(isServiceRoleRequest(request(), 'service-key'), false);
  assertEquals(isServiceRoleRequest(request('Bearer '), ''), false);
  assertEquals(timingSafeEqual('abc', 'abcd'), false);
});
