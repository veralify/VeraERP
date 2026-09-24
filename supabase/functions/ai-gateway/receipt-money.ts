// Money and number normalisation for receipt reading.
//
// The contract sends money as a decimal string ("12.50"), never a float, so
// a figure survives JSON, Postgres `numeric` and Swift `Decimal` unchanged.
// Models are told to answer that way but do not always: Italian receipts print
// "1.234,50", some answers come back as JSON numbers, and a discount may carry
// a trailing minus ("1,00-"). Everything the model says about an amount goes
// through here before it is stored. The Swift twin is `ReceiptMoney` in
// VeralifyCore, used when the user edits a figure on the review screen.

/** Digits after the decimal point for currencies that do not use two. */
const MINOR_UNITS: Record<string, number> = {
  BHD: 3,
  CLP: 0,
  ISK: 0,
  JOD: 3,
  JPY: 0,
  KRW: 0,
  KWD: 3,
  OMR: 3,
  TND: 3,
  UGX: 0,
  VND: 0,
};

export function minorUnits(currency: string | null | undefined): number {
  return currency ? MINOR_UNITS[currency.toUpperCase()] ?? 2 : 2;
}

/** An exact decimal: `units / 10^scale`. BigInt so no amount ever passes through a double. */
type Exact = { units: bigint; scale: number };

/**
 * How to read a lone separator followed by exactly three digits: "1.234".
 *
 * - `money`: as grouping (1234). Amounts are printed to the cent, so three
 *   decimals on a receipt are almost always thousands.
 * - `decimal`: as a decimal point (1.234). Right for quantities, where
 *   "1,234 kg" is a weight, not a thousand kilos.
 */
type Mode = 'money' | 'decimal';

function parseExact(input: unknown, mode: Mode): Exact | null {
  if (typeof input === 'number') {
    if (!Number.isFinite(input)) return null;
    // `String` gives the shortest round-trip form, so 12.5 stays "12.5"
    // rather than 12.4999…; rounding to the currency's precision follows.
    input = String(input);
  }
  if (typeof input !== 'string') return null;

  let text = input.trim().replace(/−/g, '-');
  if (!text) return null;

  let negative = false;
  if (/^\(.*\)$/.test(text)) {
    negative = true;
    text = text.slice(1, -1);
  }
  // A leading or trailing minus, with any currency sign or code around it
  // ("-€2,00", "€ -2,00", "2,00-", "2.00 EUR-").
  const stripped = text.replace(/[^\d.,-]/g, '');
  if (/^-/.test(stripped) || /-$/.test(stripped)) negative = true;
  let digits = stripped.replace(/^-+|-+$/g, '');
  // A minus anywhere else ("12-05") means this was never an amount.
  if (!/\d/.test(digits) || /[^\d.,]/.test(digits)) return null;

  const lastComma = digits.lastIndexOf(',');
  const lastPeriod = digits.lastIndexOf('.');
  let decimalMark: string | null = null;
  if (lastComma >= 0 && lastPeriod >= 0) {
    // Both present: whichever comes last is the decimal point.
    decimalMark = lastComma > lastPeriod ? ',' : '.';
  } else if (lastComma >= 0 || lastPeriod >= 0) {
    const mark = lastComma >= 0 ? ',' : '.';
    const count = digits.split(mark).length - 1;
    if (count > 1) {
      decimalMark = null; // "1.250.000": grouping only
    } else {
      const [whole, fraction] = digits.split(mark);
      const looksGrouped = mode === 'money' && fraction.length === 3 &&
        /^[1-9]\d{0,2}$/.test(whole);
      decimalMark = looksGrouped ? null : mark;
    }
  }

  let whole = digits;
  let fraction = '';
  if (decimalMark) {
    const at = digits.lastIndexOf(decimalMark);
    whole = digits.slice(0, at);
    fraction = digits.slice(at + 1);
  }
  // Grouping marks only ever separate thousands, so "1,2,3.45" is a misread,
  // not 123.45.
  const groups = whole.split(/[.,]/);
  if (
    groups.length > 1 &&
    (!/^\d{1,3}$/.test(groups[0]) || groups.slice(1).some((g) => !/^\d{3}$/.test(g)))
  ) {
    return null;
  }
  whole = groups.join('');
  if (/[.,]/.test(fraction)) return null;
  digits = (whole || '0') + fraction;
  if (!/^\d+$/.test(digits)) return null;

  const units = BigInt(digits);
  return { units: negative ? -units : units, scale: fraction.length };
}

/** Rounds half away from zero, the way receipts and tills round. */
function rescale(value: Exact, scale: number): Exact {
  if (value.scale === scale) return value;
  if (value.scale < scale) {
    return { units: value.units * 10n ** BigInt(scale - value.scale), scale };
  }
  const divisor = 10n ** BigInt(value.scale - scale);
  const negative = value.units < 0n;
  const magnitude = negative ? -value.units : value.units;
  let quotient = magnitude / divisor;
  if ((magnitude % divisor) * 2n >= divisor) quotient += 1n;
  return { units: negative ? -quotient : quotient, scale };
}

function format(value: Exact): string {
  const negative = value.units < 0n;
  const digits = (negative ? -value.units : value.units).toString().padStart(value.scale + 1, '0');
  const body = value.scale === 0
    ? digits
    : `${digits.slice(0, -value.scale)}.${digits.slice(-value.scale)}`;
  return negative && /[1-9]/.test(body) ? `-${body}` : body;
}

/**
 * A money amount as a canonical decimal string in the currency's precision:
 * `"1.234,5"` → `"1234.50"`, `12.5` → `"12.50"`, `"2,00-"` → `"-2.00"`.
 * Null when the input is not a readable amount.
 */
export function normaliseMoney(input: unknown, currency?: string | null): string | null {
  const exact = parseExact(input, 'money');
  return exact ? format(rescale(exact, minorUnits(currency))) : null;
}

/**
 * A plain decimal with trailing zeros removed, for quantities and tax rates:
 * `"22,00 %"` → `"22"`, `"0,500"` → `"0.5"`.
 */
export function normaliseDecimal(input: unknown): string | null {
  const exact = parseExact(input, 'decimal');
  if (!exact) return null;
  let { units, scale } = exact;
  while (scale > 0 && units % 10n === 0n) {
    units /= 10n;
    scale -= 1;
  }
  return format({ units, scale });
}

/** Exact comparison helpers over canonical strings, for the total checks. */
export function moneyToMinor(amount: string, currency?: string | null): bigint | null {
  const exact = parseExact(amount, 'decimal');
  return exact ? rescale(exact, minorUnits(currency)).units : null;
}

export function absMoney(amount: string | null): string | null {
  return amount && amount.startsWith('-') ? amount.slice(1) : amount;
}
