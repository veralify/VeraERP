const encoder = new TextEncoder();

export type AgoraRtcRole = 'listener' | 'speaker';
export type ParticipantState = { role: string; speak_state: string } | null;

function base64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function concatBytes(chunks: Uint8Array[]): Uint8Array {
  const total = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.length;
  }
  return out;
}

function u16(value: number): Uint8Array {
  const out = new Uint8Array(2);
  new DataView(out.buffer).setUint16(0, value, true);
  return out;
}

function u32(value: number): Uint8Array {
  const out = new Uint8Array(4);
  new DataView(out.buffer).setUint32(0, value >>> 0, true);
  return out;
}

function str(value: string): Uint8Array {
  const bytes = encoder.encode(value);
  return concatBytes([u16(bytes.length), bytes]);
}

function bytes(value: Uint8Array): Uint8Array {
  return concatBytes([u16(value.length), value]);
}

function toArrayBuffer(value: Uint8Array): ArrayBuffer {
  return value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength) as ArrayBuffer;
}

async function hmacSha1(secret: string, payload: Uint8Array): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-1' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, toArrayBuffer(payload)));
}

export function crc32(input: string): number {
  let crc = 0xffffffff;
  for (const byte of encoder.encode(input)) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function packMessage(salt: number, timestamp: number, privileges: Record<number, number>): Uint8Array {
  const entries = Object.entries(privileges).map(([k, v]) => [Number(k), v] as const);
  return concatBytes([
    u32(salt),
    u32(timestamp),
    u16(entries.length),
    ...entries.flatMap(([key, value]) => [u16(key), u32(value)]),
  ]);
}

export async function buildAgoraRtcToken(params: {
  appId: string;
  appCertificate: string;
  channelName: string;
  uid: string | number;
  role: AgoraRtcRole;
  expireAt: number;
  issuedAt?: number;
  salt?: number;
}): Promise<string> {
  if (!/^[0-9a-fA-F]{32}$/.test(params.appId)) throw new Error('AGORA_APP_ID must be a 32-character hex string');
  if (!/^[0-9a-fA-F]{32}$/.test(params.appCertificate)) throw new Error('AGORA_APP_CERTIFICATE must be a 32-character hex string');
  const uid = String(params.uid);
  const salt = params.salt ?? crypto.getRandomValues(new Uint32Array(1))[0];
  const issuedAt = params.issuedAt ?? Math.floor(Date.now() / 1000);
  const privileges: Record<number, number> = { 1: params.expireAt };
  if (params.role === 'speaker') {
    privileges[2] = params.expireAt;
    privileges[3] = params.expireAt;
  }
  const message = packMessage(salt, issuedAt, privileges);
  const signPayload = concatBytes([encoder.encode(params.appId), encoder.encode(params.channelName), encoder.encode(uid), message]);
  const signature = await hmacSha1(params.appCertificate, signPayload);
  const content = concatBytes([
    bytes(signature),
    u32(crc32(params.channelName)),
    u32(crc32(uid)),
    bytes(message),
  ]);
  return `006${params.appId}${base64(content)}`;
}

export function agoraUidForUserId(userId: string): number {
  return crc32(userId) || 1;
}

export function resolveAgoraRole(requestedRole: unknown, participant: ParticipantState): AgoraRtcRole {
  if (requestedRole === 'speaker') {
    if (!participant || !['speaker', 'host', 'moderator'].includes(participant.role) || !['approved_speaker', 'speaking'].includes(participant.speak_state)) {
      throw new Error('Speaker role requires server-approved speaker state');
    }
    return 'speaker';
  }
  return 'listener';
}

export function isModeratorParticipant(participant: ParticipantState): boolean {
  return Boolean(participant && ['host', 'moderator'].includes(participant.role) && ['approved_speaker', 'speaking'].includes(participant.speak_state));
}
