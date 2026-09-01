const encoder = new TextEncoder();

function hex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

export function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

export async function hmacSha256Hex(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return hex(await crypto.subtle.sign('HMAC', key, encoder.encode(payload)));
}

export async function verifyStripeSignature(body: string, signatureHeader: string | null, secret: string, nowSeconds = Math.floor(Date.now() / 1000), toleranceSeconds = 300): Promise<boolean> {
  if (!signatureHeader || !secret) return false;
  const parts = new Map<string, string[]>();
  for (const part of signatureHeader.split(',')) {
    const [key, value] = part.split('=', 2);
    if (!key || !value) continue;
    const values = parts.get(key) ?? [];
    values.push(value);
    parts.set(key, values);
  }
  const timestamp = Number(parts.get('t')?.[0]);
  const signatures = parts.get('v1') ?? [];
  if (!Number.isFinite(timestamp) || signatures.length === 0) return false;
  if (Math.abs(nowSeconds - timestamp) > toleranceSeconds) return false;
  const expected = await hmacSha256Hex(secret, `${timestamp}.${body}`);
  return signatures.some((signature) => timingSafeEqualHex(signature, expected));
}

export function mapStripeSubscriptionStatus(status: string): string {
  switch (status) {
    case 'trialing':
    case 'active':
    case 'past_due':
    case 'canceled':
    case 'incomplete':
    case 'incomplete_expired':
    case 'unpaid':
      return status;
    default:
      return 'incomplete';
  }
}

export function secondsToIso(value: unknown): string {
  const seconds = typeof value === 'number' ? value : Number(value ?? 0);
  return new Date(seconds * 1000).toISOString();
}
