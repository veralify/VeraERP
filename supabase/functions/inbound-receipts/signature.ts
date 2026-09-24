// HMAC-SHA256 over the raw request body.
//
// The signature must be checked against the exact bytes received: parsing the
// JSON first and re-serialising it would change whitespace and key order, and
// a valid signature would stop matching (or, worse, a check written that way
// ends up verifying something other than what was sent).

export const SIGNATURE_HEADER = 'x-inbound-signature';

const encoder = new TextEncoder();

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function hmacSha256Hex(secret: string, body: Uint8Array): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return toHex(new Uint8Array(await crypto.subtle.sign('HMAC', key, body as BufferSource)));
}

/** Constant-time comparison, so the right signature cannot be found byte by byte from timings. */
export function timingSafeEqual(a: string, b: string): boolean {
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  let diff = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i++) diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  return diff === 0;
}

/**
 * True when `header` is the hex HMAC-SHA256 of `body` under `secret`,
 * written either bare or as `sha256=<hex>` (the GitHub-style form most relays
 * produce). Hex case is ignored.
 */
export async function verifySignature(
  secret: string,
  body: Uint8Array,
  header: string | null,
): Promise<boolean> {
  if (!secret || !header) return false;
  const provided = header.trim().replace(/^sha256=/i, '').toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(provided)) return false;
  return timingSafeEqual(provided, await hmacSha256Hex(secret, body));
}
