import {
  checkAttachments,
  FILE_TYPES,
  receiptIdFor,
  receiptPath,
  type RejectReason,
} from './attachments.ts';
import { type ExtractOutcome, requestExtraction } from './extract.ts';
import { inboundToken, parseInboundEmail, PayloadError } from './payload.ts';
import { SIGNATURE_HEADER, verifySignature } from './signature.ts';

/** The database and storage side of the webhook, so the flow can be tested without Supabase. */
export interface InboundStore {
  findAddress(token: string): Promise<{ userId: string; enabled: boolean } | null>;
  homeCurrency(userId: string): Promise<string>;
  receiptExists(receiptId: string): Promise<boolean>;
  uploadReceiptFile(path: string, bytes: Uint8Array, contentType: string): Promise<void>;
  /** Inserts the money_receipts row; 'duplicate' when the id already exists. */
  insertReceipt(row: {
    id: string;
    user_id: string;
    image_paths: string[];
    source: 'email';
  }): Promise<'inserted' | 'duplicate'>;
}

export interface InboundDeps {
  secret: string;
  domain: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  store: InboundStore;
  fetchImpl?: typeof fetch;
  /**
   * Keeps work going after the response is sent (EdgeRuntime.waitUntil in
   * production). Reading a receipt takes longer than most providers wait for
   * a webhook, and a provider that times out retries the whole e-mail.
   */
  background: (work: Promise<unknown>) => void;
  log?: (event: Record<string, unknown>) => void;
}

// Mail providers cap a whole message at 25–35 MB, and base64 inflates the
// attachments by a third, so a genuine e-mail fits comfortably. The cap keeps
// one request from taking the function's memory.
export const MAX_BODY_BYTES = 40 * 1024 * 1024;

export interface InboundResult {
  ok: true;
  ignored?: 'no_recipient' | 'unknown_recipient' | 'disabled';
  receipts: { receipt_id: string; filename: string; status: 'created' | 'duplicate' }[];
  rejected: { filename: string; reason: RejectReason }[];
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function readBody(req: Request): Promise<Uint8Array | null> {
  const declared = Number(req.headers.get('content-length') ?? '0');
  if (declared > MAX_BODY_BYTES) return null;
  const body = new Uint8Array(await req.arrayBuffer());
  return body.length > MAX_BODY_BYTES ? null : body;
}

/**
 * Status codes follow what webhook senders do with them: 2xx for anything
 * that will never succeed (unknown address, nothing usable attached), so the
 * provider does not retry it for days; 5xx only for our own transient
 * failures, where a retry is wanted and — because receipt ids are derived from
 * the file — safe.
 */
export async function handleInbound(req: Request, deps: InboundDeps): Promise<Response> {
  const log = deps.log ?? ((event) => console.log(JSON.stringify(event)));
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);
  if (!deps.secret || !deps.domain) {
    log({ event: 'inbound_receipts_misconfigured' });
    return json({ error: 'NOT_CONFIGURED' }, 500);
  }

  const raw = await readBody(req);
  if (raw === null) return json({ error: 'PAYLOAD_TOO_LARGE' }, 413);
  if (!(await verifySignature(deps.secret, raw, req.headers.get(SIGNATURE_HEADER)))) {
    return json({ error: 'INVALID_SIGNATURE' }, 401);
  }

  let email;
  try {
    email = parseInboundEmail(JSON.parse(new TextDecoder().decode(raw)));
  } catch (error) {
    const message = error instanceof PayloadError ? error.message : 'Body must be valid JSON.';
    return json({ error: 'INVALID_PAYLOAD', message }, 400);
  }

  const result: InboundResult = { ok: true, receipts: [], rejected: [] };
  const token = inboundToken(email.to, deps.domain);
  if (token === null) return json({ ...result, ignored: 'no_recipient' });

  const address = await deps.store.findAddress(token);
  if (address === null) return json({ ...result, ignored: 'unknown_recipient' });
  if (!address.enabled) return json({ ...result, ignored: 'disabled' });
  const userId = address.userId;

  const created: string[] = [];
  for (const attachment of checkAttachments(email.attachments)) {
    if (!attachment.ok) {
      result.rejected.push({ filename: attachment.filename, reason: attachment.reason });
      continue;
    }
    const receiptId = await receiptIdFor(userId, attachment.bytes);
    if (await deps.store.receiptExists(receiptId)) {
      result.receipts.push({
        receipt_id: receiptId,
        filename: attachment.filename,
        status: 'duplicate',
      });
      continue;
    }
    const path = receiptPath(userId, receiptId, attachment.kind);
    // File first, row second: a row must never point at a file that is not
    // there, while a file without a row is simply overwritten on retry.
    await deps.store.uploadReceiptFile(
      path,
      attachment.bytes,
      FILE_TYPES[attachment.kind].contentType,
    );
    const inserted = await deps.store.insertReceipt({
      id: receiptId,
      user_id: userId,
      image_paths: [path],
      source: 'email',
    });
    result.receipts.push({
      receipt_id: receiptId,
      filename: attachment.filename,
      status: inserted === 'inserted' ? 'created' : 'duplicate',
    });
    if (inserted === 'inserted') created.push(receiptId);
  }

  log({
    event: 'inbound_receipts_received',
    user_id: userId,
    created: created.length,
    duplicates: result.receipts.length - created.length,
    rejected: result.rejected.map((item) => item.reason),
  });

  if (created.length > 0) {
    deps.background(extractAll(deps, userId, created, log));
  }
  return json(result);
}

/**
 * One at a time: the scan limit is counted per call, and parallel calls for
 * one user would race each other past it. A failed read leaves the receipt
 * as 'uploaded', where the app offers to try again.
 */
async function extractAll(
  deps: InboundDeps,
  userId: string,
  receiptIds: string[],
  log: (event: Record<string, unknown>) => void,
): Promise<ExtractOutcome[]> {
  const homeCurrency = await deps.store.homeCurrency(userId).catch(() => 'EUR');
  const outcomes: ExtractOutcome[] = [];
  for (const receiptId of receiptIds) {
    const outcome = await requestExtraction({
      supabaseUrl: deps.supabaseUrl,
      serviceRoleKey: deps.serviceRoleKey,
      userId,
      receiptId,
      homeCurrency,
      fetchImpl: deps.fetchImpl,
    });
    outcomes.push(outcome);
    log({ event: 'inbound_receipt_extract', user_id: userId, ...outcome });
    // Every further call would be refused the same way.
    if (outcome.error === 'SCAN_LIMIT_REACHED') break;
  }
  return outcomes;
}
