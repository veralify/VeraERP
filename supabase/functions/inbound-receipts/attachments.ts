import type { InboundAttachment } from './payload.ts';

// The receipts bucket takes 10 MiB per object (foundation migration).
export const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;
// E-mail signatures and HTML bodies carry logos, social icons and tracking
// pixels as image attachments. None of them is a receipt, and each would
// otherwise cost an AI scan. A phone photo or a screenshot of a receipt is
// far larger than this; PDFs are exempt because a text-only PDF can be tiny.
export const MIN_IMAGE_BYTES = 10 * 1024;
// A forwarded thread can carry dozens of images; beyond this the rest are
// reported as rejected rather than silently spending the user's scan quota.
export const MAX_ATTACHMENTS = 10;

export type ReceiptFileKind = 'jpeg' | 'png' | 'pdf';

export const FILE_TYPES: Record<ReceiptFileKind, { extension: string; contentType: string }> = {
  jpeg: { extension: 'jpg', contentType: 'image/jpeg' },
  png: { extension: 'png', contentType: 'image/png' },
  pdf: { extension: 'pdf', contentType: 'application/pdf' },
};

export type RejectReason =
  | 'unsupported_type'
  | 'too_large'
  | 'too_small'
  | 'invalid_base64'
  | 'too_many_attachments';

export type CheckedAttachment =
  | { ok: true; filename: string; kind: ReceiptFileKind; bytes: Uint8Array }
  | { ok: false; filename: string; reason: RejectReason };

/**
 * What the bytes are, from their signature. The declared content type is
 * not trusted: mail clients send receipts as application/octet-stream, and
 * a file named receipt.pdf can be anything.
 *
 * HEIC is not accepted even though the bucket allows it: the vision models
 * behind receipts-extract do not read it, and the phone converts to JPEG
 * before uploading, so an e-mailed HEIC would only ever fail later.
 */
export function sniffKind(bytes: Uint8Array): ReceiptFileKind | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'jpeg';
  }
  if (
    bytes.length >= 8 &&
    [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].every((byte, i) => bytes[i] === byte)
  ) {
    return 'png';
  }
  // "%PDF-" may follow a few bytes of junk; readers accept it within the first 1 KiB.
  const head = new TextDecoder('latin1').decode(bytes.subarray(0, 1024));
  if (head.includes('%PDF-')) return 'pdf';
  return null;
}

/** Decoded size of a base64 string without decoding it, so a huge attachment is refused cheaply. */
export function base64DecodedLength(clean: string): number {
  const padding = clean.endsWith('==') ? 2 : clean.endsWith('=') ? 1 : 0;
  return Math.floor((clean.length * 3) / 4) - padding;
}

function decodeBase64(clean: string): Uint8Array | null {
  if (clean.length === 0 || clean.length % 4 === 1 || !/^[A-Za-z0-9+/]*={0,2}$/.test(clean)) {
    return null;
  }
  try {
    const binary = atob(clean);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  } catch {
    return null;
  }
}

/** Decodes and checks each attachment, in order, keeping at most MAX_ATTACHMENTS. */
export function checkAttachments(attachments: InboundAttachment[]): CheckedAttachment[] {
  let accepted = 0;
  return attachments.map((attachment): CheckedAttachment => {
    const filename = attachment.filename || 'attachment';
    // MIME base64 is wrapped at 76 columns; some relays keep the line breaks.
    const clean = attachment.contentBase64.replace(/\s+/g, '');
    if (base64DecodedLength(clean) > MAX_ATTACHMENT_BYTES) {
      return { ok: false, filename, reason: 'too_large' };
    }
    const bytes = decodeBase64(clean);
    if (bytes === null) return { ok: false, filename, reason: 'invalid_base64' };
    if (bytes.length > MAX_ATTACHMENT_BYTES) return { ok: false, filename, reason: 'too_large' };

    const kind = sniffKind(bytes);
    if (kind === null) return { ok: false, filename, reason: 'unsupported_type' };
    if (kind !== 'pdf' && bytes.length < MIN_IMAGE_BYTES) {
      return { ok: false, filename, reason: 'too_small' };
    }
    if (accepted >= MAX_ATTACHMENTS) {
      return { ok: false, filename, reason: 'too_many_attachments' };
    }
    accepted++;
    return { ok: true, filename, kind, bytes };
  });
}

/**
 * The receipt id for this file and user: a UUID (version 8, RFC 9562) made
 * from a SHA-256 of the user id and the file's own hash.
 *
 * Deterministic on purpose. A provider that retries a webhook after a
 * timeout, or a user who forwards the same e-mail twice, lands on the same
 * id, finds the row already there, and does not pay for a second scan.
 */
export async function receiptIdFor(userId: string, bytes: Uint8Array): Promise<string> {
  const fileHash = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes as BufferSource));
  const seed = new TextEncoder().encode(
    `${userId}:${Array.from(fileHash, (b) => b.toString(16).padStart(2, '0')).join('')}`,
  );
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', seed)).slice(0, 16);
  digest[6] = (digest[6] & 0x0f) | 0x80; // version 8
  digest[8] = (digest[8] & 0x3f) | 0x80; // RFC 9562 variant
  const hex = Array.from(digest, (b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${
    hex.slice(20)
  }`;
}

/** Object path in the receipts bucket: {user_id}/{receipt_id}/1.{ext} (contract §5). */
export function receiptPath(userId: string, receiptId: string, kind: ReceiptFileKind): string {
  return `${userId}/${receiptId}/1.${FILE_TYPES[kind].extension}`;
}
