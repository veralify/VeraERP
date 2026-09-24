import { ECB_DAILY_URL, ECB_HISTORY_90D_URL, type FxRateRow, parseEcbRates } from './ecb.ts';

/** The database side of a sync, so the flow can be tested without Postgres. */
export interface RatesStore {
  hasAnyRates(): Promise<boolean>;
  upsertRates(rows: FxRateRow[]): Promise<void>;
  /** Fills home_amount on transactions that had no rate when saved; returns rows updated. */
  backfillHomeAmounts(): Promise<number>;
}

export interface SyncOptions {
  store: RatesStore;
  /** Load the 90-day history instead of today's rates. Forced when the table is empty. */
  backfill?: boolean;
  fetchImpl?: typeof fetch;
  timeoutMs?: number;
}

export interface SyncResult {
  source: 'daily' | 'history';
  days: number;
  rows: number;
  latest_date: string;
  home_amounts_filled: number;
}

export class UpstreamError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UpstreamError';
  }
}

// PostgREST takes large bodies, but a history upsert is ~2,000 rows; chunks
// keep each statement short and an error message pointing at one batch.
const UPSERT_CHUNK = 500;

export async function syncRates(options: SyncOptions): Promise<SyncResult> {
  const { store, fetchImpl = fetch, timeoutMs = 20_000 } = options;
  const history = options.backfill === true || !(await store.hasAnyRates());
  const url = history ? ECB_HISTORY_90D_URL : ECB_DAILY_URL;

  let response: Response;
  try {
    response = await fetchImpl(url, {
      headers: { Accept: 'application/xml, text/xml' },
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    throw new UpstreamError(`ECB request failed: ${(error as Error).message}`);
  }
  if (!response.ok) {
    await response.body?.cancel();
    throw new UpstreamError(`ECB responded ${response.status}.`);
  }

  const rows = parseEcbRates(await response.text());
  for (let start = 0; start < rows.length; start += UPSERT_CHUNK) {
    await store.upsertRates(rows.slice(start, start + UPSERT_CHUNK));
  }
  const filled = await store.backfillHomeAmounts();

  const days = [...new Set(rows.map((row) => row.rate_date))].sort();
  return {
    source: history ? 'history' : 'daily',
    days: days.length,
    rows: rows.length,
    latest_date: days[days.length - 1],
    home_amounts_filled: filled,
  };
}
