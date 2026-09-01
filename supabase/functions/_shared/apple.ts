export type AppleIapStatus = 'active' | 'expired' | 'revoked' | 'grace_period';

export function base64UrlDecode(input: string): Uint8Array {
  const normalized = input.replaceAll('-', '+').replaceAll('_', '/').padEnd(Math.ceil(input.length / 4) * 4, '=');
  const binary = atob(normalized);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}

export function decodeJwtPayload<T = Record<string, unknown>>(jws: string): T {
  const parts = jws.split('.');
  if (parts.length !== 3) throw new Error('Invalid JWS compact serialization');
  return JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[1]))) as T;
}

function readLength(bytes: Uint8Array, offset: number): { length: number; offset: number } {
  let length = bytes[offset++];
  if ((length & 0x80) === 0) return { length, offset };
  const count = length & 0x7f;
  length = 0;
  for (let i = 0; i < count; i++) length = (length << 8) | bytes[offset++];
  return { length, offset };
}

function readTlv(bytes: Uint8Array, offset: number): { tag: number; start: number; headerEnd: number; end: number } {
  const start = offset;
  const tag = bytes[offset++];
  const parsed = readLength(bytes, offset);
  return { tag, start, headerEnd: parsed.offset, end: parsed.offset + parsed.length };
}

function children(bytes: Uint8Array, tlv: { headerEnd: number; end: number }) {
  const out: Array<{ tag: number; start: number; headerEnd: number; end: number }> = [];
  for (let offset = tlv.headerEnd; offset < tlv.end;) {
    const child = readTlv(bytes, offset);
    out.push(child);
    offset = child.end;
  }
  return out;
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

export function extractSpkiFromCertificateDer(certDer: Uint8Array): Uint8Array {
  const cert = readTlv(certDer, 0);
  const certChildren = children(certDer, cert);
  const tbs = certChildren[0];
  const tbsChildren = children(certDer, tbs);
  let index = tbsChildren[0].tag === 0xa0 ? 1 : 0;
  index += 5; // serial, signature, issuer, validity, subject
  const spki = tbsChildren[index];
  if (!spki || spki.tag !== 0x30) throw new Error('Unable to locate certificate subjectPublicKeyInfo');
  return certDer.slice(spki.start, spki.end);
}

function derToRawEcdsaSignature(der: Uint8Array): Uint8Array {
  const seq = readTlv(der, 0);
  const ints = children(der, seq);
  if (ints.length !== 2) throw new Error('Invalid ECDSA signature');
  const out = new Uint8Array(64);
  for (let i = 0; i < 2; i++) {
    let v = der.slice(ints[i].headerEnd, ints[i].end);
    while (v.length > 32 && v[0] === 0) v = v.slice(1);
    out.set(v, (i + 1) * 32 - v.length);
  }
  return out;
}

export async function verifyAppleJws(jws: string, appleRootCaPem: string): Promise<Record<string, unknown>> {
  const [encodedHeader, encodedPayload, encodedSignature] = jws.split('.');
  if (!encodedHeader || !encodedPayload || !encodedSignature) throw new Error('Invalid JWS compact serialization');
  const header = JSON.parse(new TextDecoder().decode(base64UrlDecode(encodedHeader))) as { alg?: string; x5c?: string[] };
  if (header.alg !== 'ES256') throw new Error('Unsupported Apple JWS algorithm');
  if (!header.x5c || header.x5c.length === 0) throw new Error('Apple JWS x5c chain is required');
  const rootBody = appleRootCaPem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  if (header.x5c.length > 1 && header.x5c[header.x5c.length - 1] !== rootBody) throw new Error('Apple JWS chain does not terminate at configured root');
  const leafDer = Uint8Array.from(atob(header.x5c[0]), (c) => c.charCodeAt(0));
  const spki = extractSpkiFromCertificateDer(leafDer);
  const key = await crypto.subtle.importKey('spki', toArrayBuffer(spki), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
  const sig = derToRawEcdsaSignature(base64UrlDecode(encodedSignature));
  const signedData = new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`);
  const ok = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, toArrayBuffer(sig), toArrayBuffer(signedData));
  if (!ok) throw new Error('Invalid Apple JWS signature');
  return decodeJwtPayload(jws);
}

export function mapAppleNotificationToStatus(notificationType: string, subtype?: string): AppleIapStatus {
  switch (notificationType) {
    case 'SUBSCRIBED':
    case 'DID_RENEW':
      return 'active';
    case 'DID_FAIL_TO_RENEW':
      return subtype === 'GRACE_PERIOD' ? 'grace_period' : 'expired';
    case 'EXPIRED':
    case 'GRACE_PERIOD_EXPIRED':
      return 'expired';
    case 'REFUND':
    case 'REVOKE':
      return 'revoked';
    default:
      return 'expired';
  }
}

export function transactionStatus(transaction: Record<string, unknown>, notificationType?: string, subtype?: string): AppleIapStatus {
  if (transaction.revocationDate) return 'revoked';
  if (notificationType) return mapAppleNotificationToStatus(notificationType, subtype);
  const expires = Number(transaction.expiresDate ?? 0);
  return expires === 0 || expires > Date.now() ? 'active' : 'expired';
}

export function assertAppAccountTokenMatches(appAccountToken: unknown, userId: string) {
  if (typeof appAccountToken !== 'string' || appAccountToken.toLowerCase() !== userId.toLowerCase()) {
    throw new Error('appAccountToken does not match authenticated user');
  }
}

export function millisToIso(value: unknown): string | null {
  const millis = typeof value === 'number' ? value : Number(value ?? 0);
  return Number.isFinite(millis) && millis > 0 ? new Date(millis).toISOString() : null;
}
