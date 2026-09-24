// Fixed locale so server and client render identical strings, and negatives come out
// as "-€5.00" rather than "€-5.00".
const moneyFormatter = new Intl.NumberFormat('en-IE', { style: 'currency', currency: 'EUR' });

export function formatMoney(amount: number): string {
  return moneyFormatter.format(Number(amount) || 0);
}

const currencyFormatters = new Map<string, Intl.NumberFormat>();

/**
 * Like `formatMoney`, in any ISO currency. Transactions carry their own
 * currency now (receipts from abroad), so the original is shown as-is.
 * An unknown code falls back to "12.50 XYZ" instead of throwing mid-render.
 */
export function formatCurrency(amount: number, currency: string): string {
  let formatter = currencyFormatters.get(currency);
  if (!formatter) {
    try {
      formatter = new Intl.NumberFormat('en-IE', { style: 'currency', currency });
    } catch {
      return `${(Number(amount) || 0).toFixed(2)} ${currency}`;
    }
    currencyFormatters.set(currency, formatter);
  }
  return formatter.format(Number(amount) || 0);
}

/**
 * Short axis-tick form: "€350", "€1.2K", "€2K". Built by hand rather than
 * with `notation: 'compact'`, whose output differs between ICU versions.
 */
export function formatCurrencyCompact(amount: number, currency: string): string {
  const value = Number(amount) || 0;
  if (Math.abs(value) < 1000)
    return formatCurrency(Math.round(value), currency).replace(/\.00$/, '');
  const thousands = Math.round((value / 1000) * 10) / 10;
  const text = formatCurrency(thousands, currency)
    .replace(/\.00$/, '')
    .replace(/(\.\d)0$/, '$1');
  return `${text}K`;
}

/** Whole days between today (local, midnight) and an ISO date string. Negative means overdue. */
export function daysUntil(dateStr: string | null): number | null {
  if (!dateStr) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(`${dateStr}T00:00:00`);
  return Math.round((target.getTime() - today.getTime()) / 86400000);
}
