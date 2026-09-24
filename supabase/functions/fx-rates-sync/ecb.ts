// Parser for the ECB euro foreign exchange reference rates.
//
// The feed is a small, stable gesmes envelope:
//
//   <Cube>
//     <Cube time='2026-09-23'>
//       <Cube currency='USD' rate='1.1734'/>
//       ...
//     </Cube>
//     <Cube time='2026-09-22'> ... </Cube>      (history files only)
//   </Cube>
//
// A full XML parser would be a heavy dependency for three attributes, so this
// walks the <Cube> tags in document order instead: a tag with `time` opens a
// day, a tag with `currency` and `rate` belongs to the day most recently
// opened. It does not depend on attribute order, quote style or whitespace,
// which is where a hand-written parser usually breaks.

export const ECB_DAILY_URL = 'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml';
export const ECB_HISTORY_90D_URL =
  'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist-90d.xml';

/** One fx_rates row. `rate` stays a decimal string so no precision is lost on the way to numeric. */
export interface FxRateRow {
  rate_date: string;
  base: 'EUR';
  quote: string;
  rate: string;
  source: 'ecb';
}

export class EcbParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EcbParseError';
  }
}

const CUBE_TAG = /<Cube\b([^>]*?)\/?>/g;
const ATTRIBUTE = /([A-Za-z_][\w.-]*)\s*=\s*(['"])(.*?)\2/g;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const CURRENCY = /^[A-Z]{3}$/;
const RATE = /^\d+(\.\d+)?$/;

function attributes(source: string): Record<string, string> {
  const result: Record<string, string> = {};
  for (const match of source.matchAll(ATTRIBUTE)) result[match[1]] = match[3];
  return result;
}

function isRealDate(value: string): boolean {
  if (!DATE.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

/**
 * Every (day, currency) rate in an ECB daily or history document, base EUR.
 * Malformed entries are skipped rather than guessed at; a document with no
 * usable rate at all throws, so a changed feed or an HTML error page is
 * noticed instead of being "synced" as nothing.
 */
export function parseEcbRates(xml: string): FxRateRow[] {
  const rows: FxRateRow[] = [];
  const seen = new Set<string>();
  let day: string | null = null;

  for (const tag of xml.matchAll(CUBE_TAG)) {
    const attrs = attributes(tag[1]);
    if (attrs.time !== undefined) {
      day = isRealDate(attrs.time) ? attrs.time : null;
      continue;
    }
    if (attrs.currency === undefined || attrs.rate === undefined || day === null) continue;

    const quote = attrs.currency.trim();
    const rate = attrs.rate.trim();
    if (!CURRENCY.test(quote) || quote === 'EUR' || !RATE.test(rate) || Number(rate) <= 0) {
      continue;
    }
    const key = `${day}:${quote}`;
    if (seen.has(key)) continue;
    seen.add(key);
    rows.push({ rate_date: day, base: 'EUR', quote, rate, source: 'ecb' });
  }

  if (rows.length === 0) throw new EcbParseError('No exchange rates found in the ECB document.');
  return rows;
}
