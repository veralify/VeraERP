/** Offset (ms) of `timeZone` from UTC at the given instant. */
function zoneOffsetMs(instant: number, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(new Date(instant));
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value);
  const asUtc = Date.UTC(
    get('year'),
    get('month') - 1,
    get('day'),
    get('hour'),
    get('minute'),
    get('second'),
  );
  return asUtc - Math.floor(instant / 1000) * 1000;
}

/**
 * Converts a `datetime-local` value ("YYYY-MM-DDTHH:mm"), which carries no zone,
 * into the real instant it denotes in `timeZone`. Parsing it with `new Date()` on
 * the server would silently use the server's zone (UTC on Vercel) instead.
 * Returns null for malformed input or an unknown zone.
 */
export function zonedLocalToDate(local: string, timeZone: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(local);
  if (!match) return null;
  const [, y, mo, d, h, mi] = match.map(Number);
  const wallAsUtc = Date.UTC(y, mo - 1, d, h, mi);
  try {
    // Two passes settle the offset when the first guess lands across a DST change.
    let instant = wallAsUtc - zoneOffsetMs(wallAsUtc, timeZone);
    instant = wallAsUtc - zoneOffsetMs(instant, timeZone);
    return new Date(instant);
  } catch {
    return null;
  }
}
