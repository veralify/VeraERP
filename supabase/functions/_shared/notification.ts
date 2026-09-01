function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const binary = atob(body);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out.buffer;
}

export async function signApnsJwt(params: { teamId: string; keyId: string; privateKeyPem: string; issuedAt?: number }): Promise<string> {
  const header = base64Url(new TextEncoder().encode(JSON.stringify({ alg: 'ES256', kid: params.keyId })));
  const payload = base64Url(new TextEncoder().encode(JSON.stringify({ iss: params.teamId, iat: params.issuedAt ?? Math.floor(Date.now() / 1000) })));
  const key = await crypto.subtle.importKey('pkcs8', pemToPkcs8(params.privateKeyPem), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(`${header}.${payload}`)));
  return `${header}.${payload}.${base64Url(sig)}`;
}

export function nextBackoffAt(attemptsAfterFailure: number, now = new Date()): Date {
  const seconds = Math.min(3600, 2 ** Math.max(0, attemptsAfterFailure - 1) * 60);
  return new Date(now.getTime() + seconds * 1000);
}

export function jobFailurePatch(job: { attempts: number; max_attempts: number }, error: string, now = new Date()) {
  const attempts = job.attempts + 1;
  if (attempts >= job.max_attempts) {
    return { status: 'dead_letter', attempts, failed_at: now.toISOString(), dead_letter_at: now.toISOString(), dead_letter_reason: error, last_error: error };
  }
  return { status: 'failed', attempts, failed_at: now.toISOString(), next_attempt_at: nextBackoffAt(attempts, now).toISOString(), last_error: error };
}

export function apnsPayload(notification: { title: string; body: string; data?: Record<string, unknown> }) {
  return { aps: { alert: { title: notification.title, body: notification.body }, sound: 'default' }, ...(notification.data ?? {}) };
}
