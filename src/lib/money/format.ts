// Fixed locale so server and client render identical strings, and negatives come out
// as "-€5.00" rather than "€-5.00".
const moneyFormatter = new Intl.NumberFormat('en-IE', { style: 'currency', currency: 'EUR' });

export function formatMoney(amount: number): string {
  return moneyFormatter.format(Number(amount) || 0);
}

/** Whole days between today (local, midnight) and an ISO date string. Negative means overdue. */
export function daysUntil(dateStr: string | null): number | null {
  if (!dateStr) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(`${dateStr}T00:00:00`);
  return Math.round((target.getTime() - today.getTime()) / 86400000);
}
