import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { apnsPayload, jobFailurePatch, nextBackoffAt, signApnsJwt } from '../_shared/notification.ts';

function base64UrlDecode(input: string): Uint8Array {
  const normalized = input.replaceAll('-', '+').replaceAll('_', '/').padEnd(Math.ceil(input.length / 4) * 4, '=');
  const binary = atob(normalized);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}

function toArrayBuffer(value: Uint8Array): ArrayBuffer {
  return value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength) as ArrayBuffer;
}

function pem(label: string, bytes: ArrayBuffer) {
  const data = btoa(String.fromCharCode(...new Uint8Array(bytes)));
  return `-----BEGIN ${label}-----\n${data.match(/.{1,64}/g)?.join('\n')}\n-----END ${label}-----`;
}

Deno.test('backoff calculation doubles and caps', () => {
  const now = new Date('2026-09-01T00:00:00Z');
  assertEquals(nextBackoffAt(1, now).toISOString(), '2026-09-01T00:01:00.000Z');
  assertEquals(nextBackoffAt(2, now).toISOString(), '2026-09-01T00:02:00.000Z');
  assertEquals(nextBackoffAt(20, now).toISOString(), '2026-09-01T01:00:00.000Z');
});

Deno.test('failure patch retries then dead-letters at max attempts', () => {
  const now = new Date('2026-09-01T00:00:00Z');
  assertEquals(jobFailurePatch({ attempts: 0, max_attempts: 3 }, 'boom', now).status, 'failed');
  const dead = jobFailurePatch({ attempts: 2, max_attempts: 3 }, 'boom', now);
  assertEquals(dead.status, 'dead_letter');
  assertEquals(dead.attempts, 3);
});

Deno.test('claim-batch mock is idempotent and skips processing rows', () => {
  const jobs = [
    { id: 'a', status: 'pending', next_attempt_at: 0 },
    { id: 'b', status: 'processing', next_attempt_at: 0 },
  ];
  const claim = () => {
    const job = jobs.find((j) => j.status === 'pending' && j.next_attempt_at <= 0);
    if (!job) return [];
    job.status = 'processing';
    return [job.id];
  };
  assertEquals(claim(), ['a']);
  assertEquals(claim(), []);
});

Deno.test('APNs JWT signing creates a verifiable ES256 JWT', async () => {
  const keyPair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const privateKeyPem = pem('PRIVATE KEY', await crypto.subtle.exportKey('pkcs8', keyPair.privateKey));
  const jwt = await signApnsJwt({ teamId: 'TEAMID1234', keyId: 'KEYID1234', privateKeyPem, issuedAt: 1_700_000_000 });
  const [header, payload, signature] = jwt.split('.');
  assertEquals(JSON.parse(new TextDecoder().decode(base64UrlDecode(header))).kid, 'KEYID1234');
  assertEquals(JSON.parse(new TextDecoder().decode(base64UrlDecode(payload))).iss, 'TEAMID1234');
  const ok = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, keyPair.publicKey, toArrayBuffer(base64UrlDecode(signature)), toArrayBuffer(new TextEncoder().encode(`${header}.${payload}`)));
  assert(ok);
});

Deno.test('APNs payload includes alert and custom data', () => {
  assertEquals(apnsPayload({ title: 'T', body: 'B', data: { route: '/x' } }) as Record<string, unknown>, { aps: { alert: { title: 'T', body: 'B' }, sound: 'default' }, route: '/x' });
});
