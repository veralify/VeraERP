/** Constant-time string comparison, so a wrong key cannot be found byte by byte from timings. */
export function timingSafeEqual(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  let diff = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i++) diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  return diff === 0;
}

/**
 * Only the scheduler (pg_cron with the service role key) may run a sync. The
 * platform's JWT check alone would also let any signed-in user trigger ECB
 * downloads and table writes.
 */
export function isServiceRoleRequest(req: Request, serviceRoleKey: string): boolean {
  const header = req.headers.get('authorization') ?? '';
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match !== null && serviceRoleKey.length > 0 && timingSafeEqual(match[1], serviceRoleKey);
}
