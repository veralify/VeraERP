// `POST /ai-gateway/receipts-extract` — reads a receipt the app (or the
// inbound e-mail function) has uploaded, and files it.
//
// Contract: money-manager-ios/docs/RECEIPTS_CONTRACTS.md §5. In order:
//   1. who is asking — a user token, or the service role acting for `user_id`
//   2. the receipt is theirs, and its pages sit in their own storage folder
//   3. one scan is claimed from the monthly allowance (atomically, in SQL)
//   4. the pages go to the `multimodal_primary` role with a strict schema
//   5. the answer is normalised, the user's merchant rule applied, the
//      category checked against their own list, duplicates looked for
//   6. the assembled ReceiptExtraction v1 is validated, then written with the
//      service role (the client cannot write these columns — see the
//      foundation migration's column grants)
//
// Everything outside the request is injected (`ReceiptsDeps`), so the tests
// drive the whole route with an in-memory database and a fake model.

import { loadModelPolicy, type ModelPolicy } from './registry.ts';
import { OpenRouterClient, OpenRouterError } from './openrouter.ts';
import { runStructured } from './router.ts';
import { responseFormat } from './schemas.ts';
import { completeAiRequest, createAiRequest } from './logging.ts';
import { enforceRateLimit } from './ratelimit.ts';
import { SAFETY_POLICY_VERSION } from './safety.ts';
import { TOOL_SCHEMA_VERSION } from './tools.ts';
import { type AiMessage, GatewayError } from './types.ts';
import { merchantKey } from './merchant-key.ts';
import { absMoney, moneyToMinor, normaliseDecimal, normaliseMoney } from './receipt-money.ts';
import {
  DEFAULT_CATEGORY_KEYS,
  type Field,
  isUuid,
  type LineItem,
  modelOutputJsonSchema,
  type ModelReceipt,
  parseModelReceipt,
  parseReceiptExtraction,
  RECEIPT_PROMPT_VERSION,
  type ReceiptExtraction,
  type ReceiptWarning,
  type Scope,
  type TaxLine,
} from './receipt-schema.ts';

// ---------------------------------------------------------------------------
// Tunables
// ---------------------------------------------------------------------------

/** Below this a field is flagged for the user to check (the app uses the same line). */
export const LOW_CONFIDENCE = 0.75;
/** Scans per user per calendar month (UTC) when RECEIPTS_MONTHLY_SCAN_LIMIT is unset. */
export const DEFAULT_MONTHLY_SCAN_LIMIT = 100;
/** A long receipt photographed in parts; more than this is not one receipt. */
export const MAX_PAGES = 10;
/**
 * A row left in `processing` longer than this is treated as abandoned (the
 * function was killed mid-read) and may be read again.
 */
const PROCESSING_STALE_MS = 2 * 60_000;

// ---------------------------------------------------------------------------
// Dependencies
// ---------------------------------------------------------------------------

export type DbError = { message: string } | null;
export type DbResult = { data: unknown; error: DbError };

/** The slice of the supabase-js query builder this route uses. */
export interface DbQuery extends PromiseLike<DbResult> {
  select(columns?: string): DbQuery;
  update(values: Record<string, unknown>): DbQuery;
  eq(column: string, value: unknown): DbQuery;
  neq(column: string, value: unknown): DbQuery;
  is(column: string, value: null): DbQuery;
  limit(count: number): DbQuery;
  maybeSingle(): PromiseLike<DbResult>;
}

export interface ReceiptsDb {
  from(table: string): DbQuery;
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<DbResult>;
  storage: {
    from(bucket: string): {
      download(path: string): Promise<{ data: Blob | null; error: DbError }>;
    };
  };
}

export type ReceiptsDeps = {
  /** A service-role client: every read and write here bypasses RLS, so every query filters by user. */
  db: ReceiptsDb;
  serviceRoleKey: string;
  /** The user id a bearer token belongs to, or null when it is not a valid session. */
  userIdForToken(token: string): Promise<string | null>;
  policy: ModelPolicy;
  /** Lazy: a missing OPENROUTER_API_KEY is an AI outage (503), not a failure to authenticate. */
  openRouter(): OpenRouterClient;
  scanLimit: number;
  /** prompts/receipts-extraction.md */
  prompt: string;
  now?: () => Date;
  newRequestId?: () => string;
};

type SupabaseFactory = (
  url: string,
  key: string,
  options: Record<string, unknown>,
) => ReceiptsDb & {
  auth: {
    getUser(
      token: string,
    ): Promise<{ data: { user: { id: string } | null } | null; error: unknown }>;
  };
};

export function scanLimitFromEnv(raw = Deno.env.get('RECEIPTS_MONTHLY_SCAN_LIMIT')): number {
  const value = raw === undefined ? NaN : Number(raw);
  return Number.isInteger(value) && value >= 0 ? value : DEFAULT_MONTHLY_SCAN_LIMIT;
}

/** Production wiring, from the function's environment. */
export async function receiptsDepsFromEnv(createClient: SupabaseFactory): Promise<ReceiptsDeps> {
  const url = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceRoleKey) {
    throw new ReceiptError(
      500,
      'INTERNAL_ERROR',
      'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.',
    );
  }
  const client = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return {
    db: client,
    serviceRoleKey,
    userIdForToken: async (token) => {
      const { data, error } = await client.auth.getUser(token);
      return error ? null : data?.user?.id ?? null;
    },
    policy: await loadModelPolicy(),
    openRouter: () => new OpenRouterClient(),
    scanLimit: scanLimitFromEnv(),
    prompt: await Deno.readTextFile(new URL('./prompts/receipts-extraction.md', import.meta.url)),
  };
}

// ---------------------------------------------------------------------------
// HTTP
// ---------------------------------------------------------------------------

/** Errors in the contract's flat shape: `{ "error": CODE, "message": "…" }`. */
export class ReceiptError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

export async function handleReceiptsExtract(
  req: Request,
  loadDeps: () => Promise<ReceiptsDeps>,
): Promise<Response> {
  try {
    return json(await extractReceipt(req, await loadDeps()));
  } catch (e) {
    if (e instanceof ReceiptError) return json({ error: e.code, message: e.message }, e.status);
    if (e instanceof GatewayError && e.code === 'RATE_LIMITED') {
      return json({ error: 'RATE_LIMITED', message: e.message }, 429);
    }
    console.error('receipts-extract internal error', e);
    return json({ error: 'INTERNAL_ERROR', message: 'Unexpected error reading the receipt.' }, 500);
  }
}

type RequestBody = {
  receiptId: string;
  locale: string;
  homeCurrency: string;
  force: boolean;
  userId: unknown;
};

function bearer(req: Request): string | null {
  const [scheme, token] = (req.headers.get('authorization') ?? '').split(' ');
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
}

/** Constant-time, so the service key cannot be guessed a character at a time. */
function sameSecret(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

async function readBody(req: Request): Promise<RequestBody> {
  const raw = await req.json().catch(() => null);
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new ReceiptError(400, 'BAD_REQUEST', 'Body must be a JSON object.');
  }
  const body = raw as Record<string, unknown>;
  if (!isUuid(body.receipt_id)) {
    throw new ReceiptError(400, 'BAD_REQUEST', 'receipt_id must be a uuid.');
  }
  const locale =
    typeof body.locale === 'string' && /^[A-Za-z]{2,3}([-_][A-Za-z0-9]{2,8})*$/.test(body.locale)
      ? body.locale
      : 'en-GB';
  const homeCurrency =
    typeof body.home_currency === 'string' && /^[A-Z]{3}$/.test(body.home_currency)
      ? body.home_currency
      : 'EUR';
  return {
    receiptId: body.receipt_id.toLowerCase(),
    locale,
    homeCurrency,
    force: body.force === true,
    userId: body.user_id,
  };
}

/**
 * The user this call acts for. `user_id` in the body is honoured only with
 * the service role key (the inbound e-mail function has no user token);
 * from anyone else it is ignored and the token decides.
 */
async function resolveUser(token: string, body: RequestBody, deps: ReceiptsDeps): Promise<string> {
  if (deps.serviceRoleKey && sameSecret(token, deps.serviceRoleKey)) {
    if (!isUuid(body.userId)) {
      throw new ReceiptError(
        400,
        'BAD_REQUEST',
        'user_id is required when calling with the service role.',
      );
    }
    return body.userId.toLowerCase();
  }
  const userId = await deps.userIdForToken(token).catch(() => null);
  if (!userId) throw new ReceiptError(401, 'UNAUTHENTICATED', 'Invalid or expired access token.');
  return userId;
}

// ---------------------------------------------------------------------------
// The route
// ---------------------------------------------------------------------------

type ReceiptRow = {
  id: string;
  status: string;
  image_paths: string[] | null;
  extraction: unknown;
  updated_at: string | null;
};

type Page = { mime: string; base64: string };

async function extractReceipt(req: Request, deps: ReceiptsDeps): Promise<ReceiptExtraction> {
  const token = bearer(req);
  if (!token) throw new ReceiptError(401, 'UNAUTHENTICATED', 'Bearer token required.');
  const body = await readBody(req);
  const userId = await resolveUser(token, body, deps);
  const { db } = deps;
  const now = deps.now?.() ?? new Date();

  const receipt = await loadReceipt(db, userId, body.receiptId);

  // Idempotent: the app retries after a timeout, and the first call may
  // have finished. Returning what is stored costs no scan and cannot
  // overwrite a confirmed receipt. `force` asks for a fresh read.
  const stored = storedExtraction(receipt);
  if (receipt.status === 'confirmed') {
    if (stored) return stored;
    throw new ReceiptError(409, 'RECEIPT_CONFIRMED', 'This receipt is already confirmed.');
  }
  if (receipt.status === 'extracted' && stored && !body.force) return stored;
  if (receipt.status === 'processing' && receipt.updated_at) {
    const age = now.getTime() - Date.parse(receipt.updated_at);
    if (age >= 0 && age < PROCESSING_STALE_MS) {
      throw new ReceiptError(409, 'RECEIPT_BUSY', 'This receipt is already being read.');
    }
  }

  const paths = checkedImagePaths(receipt, userId);
  await enforceRateLimit(userId, deps.policy);

  const month = await claimScan(db, userId, deps.scanLimit);
  // From here the claim must be settled whatever happens: kept when a model
  // answered (even "this is not a receipt" — the call cost the same), handed
  // back when none could be reached.
  let counted = false;
  let costUsd = 0;
  try {
    await updateReceipt(db, userId, body.receiptId, {
      status: 'processing',
      error_code: null,
      error_message: null,
    });

    const pages = await downloadPages(db, paths);
    if (!pages) {
      // The row says pages exist that storage does not have: an upload that
      // never finished. Back to `uploaded` so the app uploads again.
      await updateReceipt(db, userId, body.receiptId, {
        status: 'uploaded',
        error_code: 'IMAGES_MISSING',
        error_message: 'A page image is missing from storage.',
      });
      throw new ReceiptError(
        400,
        'IMAGES_MISSING',
        'A page image is missing from storage; upload it again.',
      );
    }

    const categoryKeys = await loadCategoryKeys(db, userId);
    const read = await readWithModel(deps, {
      userId,
      pages,
      categoryKeys,
      locale: body.locale,
      homeCurrency: body.homeCurrency,
    });
    costUsd = read.costUsd;

    if (!read.parsed && read.inputRejected && pages.some((p) => p.mime === 'application/pdf')) {
      // No model in the role would take the PDF, and there is no way to
      // rasterise it here. Retrying cannot help, so this is UNREADABLE with a
      // way forward, not an outage. The scan is not counted.
      // VERIFY: which multimodal_primary models accept PDF input through
      // OpenRouter; if none do, e-mailed PDFs always end here.
      const message =
        'This PDF could not be read. Send a photo or screenshot of the receipt instead.';
      await updateReceipt(db, userId, body.receiptId, {
        status: 'failed',
        error_code: 'UNREADABLE',
        error_message: message,
      });
      throw new ReceiptError(422, 'UNREADABLE', message);
    }
    if (!read.parsed) {
      await updateReceipt(db, userId, body.receiptId, {
        status: 'failed',
        error_code: 'AI_UNAVAILABLE',
        error_message: read.error,
      });
      throw new ReceiptError(
        503,
        'AI_UNAVAILABLE',
        'The receipt could not be read right now. Try again shortly.',
      );
    }
    counted = true;
    const parsed = read.parsed;

    if (isUnreadable(parsed)) {
      await updateReceipt(db, userId, body.receiptId, {
        status: 'failed',
        error_code: 'UNREADABLE',
        error_message: 'No receipt could be read in the image.',
        model: read.model,
        model_version: deps.policy.model_policy_version,
        prompt_version: RECEIPT_PROMPT_VERSION,
      });
      throw new ReceiptError(422, 'UNREADABLE', 'No receipt could be read in the image.');
    }

    const key = merchantKey(parsed.merchant.name.value ?? '');
    const rule = key ? await loadRule(db, userId, key) : null;
    const extraction = assembleExtraction({
      receiptId: body.receiptId,
      parsed,
      model: read.model,
      categoryKeys,
      rule,
      homeCurrency: body.homeCurrency,
    });
    extraction.duplicate_of = await findDuplicate(db, userId, body.receiptId, extraction);

    // The last gate before storage: a document the apps cannot decode is
    // never written. A failure here is a bug in this file, hence a 500.
    const valid = parseReceiptExtraction(extraction, categoryKeys);

    await updateReceipt(db, userId, body.receiptId, {
      status: 'extracted',
      extraction: valid,
      model: valid.model,
      model_version: deps.policy.model_policy_version,
      prompt_version: RECEIPT_PROMPT_VERSION,
      merchant_key: valid.merchant_key || null,
      receipt_date: valid.date.value,
      total: valid.total.value,
      currency: valid.currency.value,
      error_code: null,
      error_message: null,
    });
    await completeAiRequest(db, read.aiRequestId, 'succeeded', read.model, read.fallbackUsed)
      .catch((e: unknown) => console.warn('ai_requests completion failed', e));
    return valid;
  } finally {
    await settleScan(db, userId, month, counted, costUsd);
  }
}

async function loadReceipt(db: ReceiptsDb, userId: string, receiptId: string): Promise<ReceiptRow> {
  const { data, error } = await db
    .from('money_receipts')
    .select('id,status,image_paths,extraction,updated_at')
    .eq('id', receiptId)
    .eq('user_id', userId)
    .is('deleted_at', null)
    .maybeSingle();
  if (error) throw new Error(`money_receipts read failed: ${error.message}`);
  // Someone else's receipt and no receipt at all look the same from outside.
  if (!data || typeof data !== 'object') {
    throw new ReceiptError(404, 'RECEIPT_NOT_FOUND', 'No such receipt.');
  }
  return data as ReceiptRow;
}

/** The stored reading, or null when there is none or it no longer validates (then it is read again). */
function storedExtraction(receipt: ReceiptRow): ReceiptExtraction | null {
  if (!receipt.extraction) return null;
  try {
    return parseReceiptExtraction(receipt.extraction);
  } catch {
    return null;
  }
}

/**
 * The client writes `image_paths` itself, and this function then reads them
 * with the service role — which can read every user's folder. So each path
 * must sit inside this user's folder for this receipt, or a crafted row
 * could have the model read somebody else's receipt.
 */
function checkedImagePaths(receipt: ReceiptRow, userId: string): string[] {
  const paths = Array.isArray(receipt.image_paths) ? receipt.image_paths : [];
  if (paths.length === 0) {
    throw new ReceiptError(400, 'BAD_REQUEST', 'The receipt has no uploaded pages yet.');
  }
  if (paths.length > MAX_PAGES) {
    throw new ReceiptError(400, 'BAD_REQUEST', `A receipt can have at most ${MAX_PAGES} pages.`);
  }
  const prefix = `${userId}/${receipt.id}/`;
  for (const path of paths) {
    if (
      typeof path !== 'string' || !path.startsWith(prefix) || path.includes('..') ||
      path.length <= prefix.length
    ) {
      throw new ReceiptError(400, 'BAD_REQUEST', "A page path is outside this receipt's folder.");
    }
  }
  return paths;
}

async function claimScan(db: ReceiptsDb, userId: string, limit: number): Promise<string> {
  const { data, error } = await db.rpc('money_claim_receipt_scan', {
    p_user_id: userId,
    p_limit: limit,
  });
  if (error) throw new Error(`scan allowance check failed: ${error.message}`);
  if (typeof data !== 'string') {
    throw new ReceiptError(
      402,
      'SCAN_LIMIT_REACHED',
      `You have used all ${limit} receipt scans for this month.`,
    );
  }
  return data;
}

async function settleScan(
  db: ReceiptsDb,
  userId: string,
  month: string,
  counted: boolean,
  costUsd: number,
) {
  try {
    const { error } = await db.rpc('money_settle_receipt_scan', {
      p_user_id: userId,
      p_month: month,
      p_counted: counted,
      p_cost_usd: Number(costUsd.toFixed(6)),
    });
    if (error) console.warn('scan settle failed', error.message);
  } catch (e) {
    // Never let bookkeeping turn a read into an error for the user.
    console.warn('scan settle failed', e);
  }
}

async function updateReceipt(
  db: ReceiptsDb,
  userId: string,
  receiptId: string,
  values: Record<string, unknown>,
) {
  const { error } = await db.from('money_receipts').update(values).eq('id', receiptId).eq(
    'user_id',
    userId,
  );
  if (error) throw new Error(`money_receipts update failed: ${error.message}`);
}

function mimeFor(path: string, blobType: string): string {
  if (blobType && blobType !== 'application/octet-stream') return blobType;
  const ext = path.split('.').pop()?.toLowerCase();
  if (ext === 'png') return 'image/png';
  if (ext === 'heic') return 'image/heic';
  if (ext === 'pdf') return 'application/pdf';
  return 'image/jpeg';
}

function toBase64(bytes: Uint8Array): string {
  let binary = '';
  // Chunked: spreading a whole 1 MB image into one call overflows the stack.
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

async function downloadPages(db: ReceiptsDb, paths: string[]): Promise<Page[] | null> {
  const pages: Page[] = [];
  for (const path of paths) {
    const { data, error } = await db.storage.from('receipts').download(path);
    if (error || !data) return null;
    pages.push({
      mime: mimeFor(path, data.type),
      base64: toBase64(new Uint8Array(await data.arrayBuffer())),
    });
  }
  return pages;
}

async function loadCategoryKeys(db: ReceiptsDb, userId: string): Promise<string[]> {
  const { data, error } = await db
    .from('money_categories')
    .select('key,kind,archived')
    .eq('user_id', userId)
    .is('deleted_at', null);
  if (error) throw new Error(`money_categories read failed: ${error.message}`);
  const rows = Array.isArray(data)
    ? data as Array<{ key?: unknown; kind?: unknown; archived?: unknown }>
    : [];
  const keys = rows
    .filter((r) => typeof r.key === 'string' && r.kind !== 'income' && r.archived !== true)
    .map((r) => r.key as string);
  // Before the first sync has seeded them, the contract's defaults stand in.
  const unique = [...new Set(keys.length ? keys : DEFAULT_CATEGORY_KEYS)];
  // "other" is the contract's fallback, so it is always a valid answer.
  if (!unique.includes('other')) unique.push('other');
  return unique;
}

type MerchantRule = { category_key: string; scope: Scope | null };

async function loadRule(db: ReceiptsDb, userId: string, key: string): Promise<MerchantRule | null> {
  const { data, error } = await db
    .from('money_merchant_rules')
    .select('category_key,scope')
    .eq('user_id', userId)
    .eq('merchant_key', key)
    .is('deleted_at', null)
    .maybeSingle();
  if (error) throw new Error(`money_merchant_rules read failed: ${error.message}`);
  if (!data || typeof data !== 'object') return null;
  const row = data as { category_key?: unknown; scope?: unknown };
  if (typeof row.category_key !== 'string') return null;
  return {
    category_key: row.category_key,
    scope: row.scope === 'business' || row.scope === 'personal' ? row.scope : null,
  };
}

type ModelRead =
  | {
    parsed: ModelReceipt;
    model: string;
    costUsd: number;
    fallbackUsed: boolean;
    aiRequestId: string | null;
  }
  | {
    parsed: null;
    error: string;
    costUsd: number;
    /** Every model refused the input itself (a 4xx), rather than being unreachable. */
    inputRejected: boolean;
    model?: undefined;
    aiRequestId: string | null;
  };

async function readWithModel(
  deps: ReceiptsDeps,
  input: {
    userId: string;
    pages: Page[];
    categoryKeys: string[];
    locale: string;
    homeCurrency: string;
  },
): Promise<ModelRead> {
  const requestId = deps.newRequestId?.() ?? crypto.randomUUID();
  const aiRequestId: string | null = await createAiRequest(deps.db, {
    userId: input.userId,
    task: 'receipt_extraction',
    requestId,
    modelRequested: 'policy:receipt_extraction',
  }).catch((e: unknown) => {
    console.warn('ai_requests insert failed; model runs will not be logged', e);
    return null;
  });

  const system = deps.prompt
    .replaceAll('{{locale}}', input.locale)
    .replaceAll('{{home_currency}}', input.homeCurrency)
    .replaceAll('{{categories}}', input.categoryKeys.join(', '));
  const content: Array<Record<string, unknown>> = [
    {
      type: 'text',
      text: `Read this receipt (${input.pages.length} page${
        input.pages.length === 1 ? '' : 's'
      }, in order).`,
    },
    ...input.pages.map((page, i) =>
      page.mime === 'application/pdf'
        // VERIFY: OpenRouter's PDF input part ({ type: 'file', file: { filename, file_data } })
        // is taken from its multimodal docs as last known; iOS always uploads JPEG, PDFs
        // only arrive from web upload or e-mail.
        ? {
          type: 'file',
          file: {
            filename: `page-${i + 1}.pdf`,
            file_data: `data:application/pdf;base64,${page.base64}`,
          },
        }
        : { type: 'image_url', image_url: { url: `data:${page.mime};base64,${page.base64}` } }
    ),
  ];
  const messages: AiMessage[] = [{ role: 'system', content: system }, { role: 'user', content }];
  const schema = {
    name: 'ReceiptReading',
    jsonSchema: modelOutputJsonSchema(input.categoryKeys),
    parse: (v: unknown) => parseModelReceipt(v),
  };

  // Records how each model answered, so a document every model refuses (a
  // PDF a vision-only model cannot take) can be told apart from an outage.
  const statuses: number[] = [];
  try {
    const inner = deps.openRouter();
    const client = {
      chat: async (params: Parameters<OpenRouterClient['chat']>[0]) => {
        try {
          return await inner.chat(params);
        } catch (e) {
          if (e instanceof OpenRouterError) statuses.push(e.status);
          throw e;
        }
      },
    } as unknown as OpenRouterClient;
    const result = await runStructured(
      deps.policy,
      client,
      {
        task: 'receipt_extraction',
        userId: input.userId,
        requestId,
        aiRequestId,
        promptVersion: RECEIPT_PROMPT_VERSION,
        toolSchemaVersion: TOOL_SCHEMA_VERSION,
        safetyPolicyVersion: SAFETY_POLICY_VERSION,
        supabase: deps.db,
        messages,
        responseFormat: responseFormat(schema),
      },
      (raw: string) => parseModelReceipt(JSON.parse(raw)),
    );
    return {
      parsed: result.parsed,
      model: String(result.model || result.requestedModel),
      costUsd: Number(result.estimatedCostUsd) || 0,
      fallbackUsed: !!result.fallbackUsed,
      aiRequestId,
    };
  } catch (e) {
    // Every model in the role failed, returned something unusable twice, or
    // no API key is configured. All of it is "try again later" to the user.
    const chain = e instanceof GatewayError && Array.isArray(e.details?.fallback_chain)
      ? e.details.fallback_chain as Array<{ estimated_cost_usd?: number }>
      : [];
    const costUsd = chain.reduce((sum, run) => sum + (Number(run.estimated_cost_usd) || 0), 0);
    console.warn('receipt read failed', e instanceof Error ? e.message : e);
    await completeAiRequest(deps.db, aiRequestId, 'failed').catch(() => {});
    const retryable = [408, 409, 425, 429];
    return {
      parsed: null,
      error: e instanceof Error ? e.message.slice(0, 500) : 'AI unavailable',
      costUsd,
      inputRejected: statuses.length > 0 &&
        statuses.every((s) => s >= 400 && s < 500 && !retryable.includes(s)),
      aiRequestId,
    };
  }
}

function isUnreadable(parsed: ModelReceipt): boolean {
  if (!parsed.is_receipt) return true;
  // "Not a receipt" with nothing read at all is the same answer, phrased differently.
  return parsed.warnings.includes('not_a_receipt') && parsed.total.value === null &&
    parsed.merchant.name.value === null;
}

// ---------------------------------------------------------------------------
// Assembly (pure)
// ---------------------------------------------------------------------------

const clampConfidence = (c: number) => Math.min(1, Math.max(0, Number.isFinite(c) ? c : 0));

/** A read value that failed normalisation is dropped, and so is the confidence in it. */
function normalised<T>(field: Field<string>, normalise: (value: string) => T | null): Field<T> {
  if (field.value === null) return { value: null, confidence: 0 };
  const value = normalise(field.value);
  return value === null
    ? { value: null, confidence: 0 }
    : { value, confidence: clampConfidence(field.confidence) };
}

const CURRENCY_SIGNS: Record<string, string> = { '€': 'EUR', '£': 'GBP', '$': 'USD', 'US$': 'USD' };

export function normaliseCurrency(value: string): string | null {
  const trimmed = value.trim();
  const code = CURRENCY_SIGNS[trimmed] ?? trimmed.toUpperCase();
  return /^[A-Z]{3}$/.test(code) ? code : null;
}

export function normaliseCountry(value: string): string | null {
  const code = value.trim().toUpperCase();
  if (code === 'UK') return 'GB';
  if (code === 'ITALIA' || code === 'ITALY') return 'IT';
  if (code === 'UNITED KINGDOM' || code === 'GREAT BRITAIN') return 'GB';
  return /^[A-Z]{2}$/.test(code) ? code : null;
}

function isRealDate(y: number, m: number, d: number): boolean {
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}

const pad = (n: number) => String(n).padStart(2, '0');

/**
 * `YYYY-MM-DD`. The model is asked for ISO, but a printed "05/03/26" copied
 * through is read day-first, as Italian and UK receipts write it.
 */
export function normaliseDate(value: string): string | null {
  const text = value.trim();
  let y: number, m: number, d: number;
  let match = text.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$/);
  if (match) {
    [y, m, d] = [Number(match[1]), Number(match[2]), Number(match[3])];
  } else {
    match = text.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2}|\d{4})$/);
    if (!match) return null;
    [d, m, y] = [Number(match[1]), Number(match[2]), Number(match[3])];
    if (y < 100) y += 2000;
  }
  if (y < 1990 || y > 2100 || !isRealDate(y, m, d)) return null;
  return `${y}-${pad(m)}-${pad(d)}`;
}

export function normaliseTime(value: string): string | null {
  const match = value.trim().match(/^(\d{1,2})[:.](\d{2})(?::\d{2})?$/);
  if (!match) return null;
  const [h, m] = [Number(match[1]), Number(match[2])];
  return h < 24 && m < 60 ? `${pad(h)}:${pad(m)}` : null;
}

const text = (value: string) => value.trim() || null;

export type AssembleInput = {
  receiptId: string;
  parsed: ModelReceipt;
  model: string;
  categoryKeys: readonly string[];
  rule: MerchantRule | null;
  homeCurrency: string;
};

/**
 * Turns the model's reading into a ReceiptExtraction v1, minus
 * `duplicate_of` (which needs the database). Pure, so every rule about
 * categories, money and warnings is unit-tested directly.
 */
export function assembleExtraction(input: AssembleInput): ReceiptExtraction {
  const { parsed } = input;
  const currency = normalised(parsed.currency, normaliseCurrency);
  // Precision follows the receipt's currency; the home currency only stands
  // in when the receipt does not say.
  const precision = currency.value ?? input.homeCurrency;
  // Totals, tips and discounts are magnitudes. A minus printed beside a
  // discount ("SCONTO -2,00") says which way it goes, not that it is negative.
  const magnitude = (f: Field<string>) =>
    normalised(f, (v) => absMoney(normaliseMoney(v, precision)));

  const taxLines: TaxLine[] = parsed.tax_lines
    .map((line) => ({
      rate: line.rate === null ? null : normaliseDecimal(line.rate.replace('%', '')),
      taxable: line.taxable === null ? null : absMoney(normaliseMoney(line.taxable, precision)),
      tax: line.tax === null ? null : absMoney(normaliseMoney(line.tax, precision)),
    }))
    .filter((line) => line.rate !== null || line.taxable !== null || line.tax !== null);

  const lineItems: LineItem[] = parsed.line_items
    .map((item) => ({
      description: item.description.trim(),
      quantity: item.quantity === null ? null : normaliseDecimal(item.quantity),
      unit_price: item.unit_price === null ? null : normaliseMoney(item.unit_price, precision),
      // Signed: a discount line on the receipt is a negative item.
      amount: item.amount === null ? null : normaliseMoney(item.amount, precision),
    }))
    .filter((item) => item.description !== '' || item.amount !== null);

  const cardDigits = parsed.payment.card_last4.value?.replace(/\D/g, '') ?? '';

  const merchantName = normalised(parsed.merchant.name, text);
  const extraction: ReceiptExtraction = {
    version: '1',
    receipt_id: input.receiptId,
    document_type: parsed.document_type,
    merchant: {
      name: merchantName,
      vat_id: normalised(
        parsed.merchant.vat_id,
        (v) => v.replace(/\s+/g, '').toUpperCase() || null,
      ),
      address: normalised(parsed.merchant.address, text),
      country: normalised(parsed.merchant.country, normaliseCountry),
    },
    merchant_key: merchantKey(merchantName.value ?? ''),
    date: normalised(parsed.date, normaliseDate),
    time: normalised(parsed.time, normaliseTime),
    currency,
    total: magnitude(parsed.total),
    subtotal: magnitude(parsed.subtotal),
    tip: magnitude(parsed.tip),
    discount: magnitude(parsed.discount),
    tax_total: magnitude(parsed.tax_total),
    tax_lines: taxLines,
    line_items: lineItems,
    payment: {
      method: {
        value: parsed.payment.method.value,
        confidence: parsed.payment.method.value === null
          ? 0
          : clampConfidence(parsed.payment.method.confidence),
      },
      card_last4: cardDigits.length >= 4
        ? {
          value: cardDigits.slice(-4),
          confidence: clampConfidence(parsed.payment.card_last4.confidence),
        }
        : { value: null, confidence: 0 },
    },
    receipt_number: normalised(parsed.receipt_number, text),
    category: chooseCategory(parsed, input.rule, input.categoryKeys),
    scope_suggestion: input.rule?.scope ?? parsed.scope_suggestion,
    duplicate_of: null,
    warnings: [],
    model: input.model,
    prompt_version: RECEIPT_PROMPT_VERSION,
  };
  extraction.warnings = computeWarnings(parsed.warnings, extraction);
  return extraction;
}

/**
 * The user's own correction beats the model; the model may only name one of
 * the user's categories; anything else is "other".
 */
function chooseCategory(
  parsed: ModelReceipt,
  rule: MerchantRule | null,
  keys: readonly string[],
): ReceiptExtraction['category'] {
  if (rule && keys.includes(rule.category_key)) {
    return { key: rule.category_key, confidence: 1, source: 'rule' };
  }
  if (keys.includes(parsed.category.key)) {
    return {
      key: parsed.category.key,
      confidence: clampConfidence(parsed.category.confidence),
      source: 'model',
    };
  }
  return { key: 'other', confidence: 0, source: 'default' };
}

function computeWarnings(fromModel: ReceiptWarning[], e: ReceiptExtraction): ReceiptWarning[] {
  const warnings = new Set<ReceiptWarning>();
  if (fromModel.includes('multiple_currencies')) warnings.add('multiple_currencies');

  // Arithmetic is checked here when the receipt gives enough to check;
  // otherwise the model's own impression stands.
  const mismatch = totalMismatch(e);
  if (mismatch === true || (mismatch === null && fromModel.includes('total_mismatch'))) {
    warnings.add('total_mismatch');
  }

  const key = [e.merchant.name, e.date, e.total, e.currency];
  if (key.some((f) => f.value === null || f.confidence < LOW_CONFIDENCE)) {
    warnings.add('low_confidence');
  }
  return [...warnings];
}

/**
 * True when nothing printed adds up to the total, false when something does,
 * null when there is not enough on the receipt to say.
 *
 * Several readings are tried because receipts disagree on what a subtotal
 * is: Italian and UK prices include tax, US-style bills add it on top, and a
 * discount may already be a negative line item or printed separately.
 */
export function totalMismatch(e: ReceiptExtraction): boolean | null {
  const cur = e.currency.value;
  const minor = (v: string | null) => (v === null ? null : moneyToMinor(v, cur));
  const total = minor(e.total.value);
  if (total === null) return null;
  const discount = minor(e.discount.value) ?? 0n;
  const tip = minor(e.tip.value) ?? 0n;
  const tax = minor(e.tax_total.value) ?? 0n;

  const bases: bigint[] = [];
  const amounts = e.line_items.map((i) => minor(i.amount));
  if (amounts.length > 0 && amounts.every((a) => a !== null)) {
    bases.push(amounts.reduce((sum: bigint, a) => sum + (a as bigint), 0n));
  }
  const subtotal = minor(e.subtotal.value);
  if (subtotal !== null) bases.push(subtotal);
  if (bases.length === 0) return null;

  const candidates = bases.flatMap((b) => [
    b,
    b - discount,
    b + tip,
    b - discount + tip,
    b + tax,
    b + tax - discount + tip,
  ]);
  // Two minor units of slack for per-line rounding.
  return !candidates.some((c) => (c > total ? c - total : total - c) <= 2n);
}

// ---------------------------------------------------------------------------
// Duplicates
// ---------------------------------------------------------------------------

/**
 * A transaction already saved for the same merchant, day and amount. Looked
 * for in two places: receipts confirmed earlier (which carry merchant_key),
 * and transactions typed by hand or synced from elsewhere (which carry only
 * the merchant's name, so its key is computed here).
 */
async function findDuplicate(
  db: ReceiptsDb,
  userId: string,
  receiptId: string,
  e: ReceiptExtraction,
): Promise<string | null> {
  const date = e.date.value;
  const total = e.total.value;
  if (!e.merchant_key || !date || !total) return null;

  const receipts = await db
    .from('money_receipts')
    .select('id,transaction_id')
    .eq('user_id', userId)
    .eq('merchant_key', e.merchant_key)
    .eq('receipt_date', date)
    .eq('total', total)
    .eq('status', 'confirmed')
    .is('deleted_at', null)
    .neq('id', receiptId)
    .limit(5);
  if (receipts.error) throw new Error(`duplicate check failed: ${receipts.error.message}`);
  const linked = (Array.isArray(receipts.data) ? receipts.data : [])
    .map((r) => (r as { transaction_id?: unknown }).transaction_id)
    .find(isUuid);
  if (linked) return linked;

  const transactions = await db
    .from('money_transactions')
    .select('id,merchant')
    .eq('user_id', userId)
    .eq('transaction_date', date)
    .eq('amount', total)
    .eq('direction', 'expense')
    .is('deleted_at', null)
    .limit(50);
  if (transactions.error) throw new Error(`duplicate check failed: ${transactions.error.message}`);
  const match = (Array.isArray(transactions.data) ? transactions.data : [])
    .map((t) => t as { id?: unknown; merchant?: unknown })
    .find((t) => typeof t.merchant === 'string' && merchantKey(t.merchant) === e.merchant_key);
  return match && isUuid(match.id) ? match.id : null;
}
