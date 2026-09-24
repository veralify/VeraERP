// HTTP plumbing shared by the adapters: one place that turns a provider's
// HTTP status into an AccountingError kind, so the worker's retry policy does
// not depend on which provider failed.

import {
  AccountingError,
  type AccountingErrorKind,
  type AccountingProvider,
  type FetchLike,
  type TokenBundle,
} from './types.ts';

/** Pulls a human-readable message out of a provider's error body. */
export type ErrorMessageExtractor = (body: unknown, rawText: string) => string | null;

export interface ProviderRequest {
  provider: AccountingProvider;
  fetch: FetchLike;
  url: string;
  method?: string;
  headers?: Record<string, string>;
  body?: BodyInit | null;
  errorMessage?: ErrorMessageExtractor;
  /**
   * Override the kind for particular statuses. Token endpoints use this to
   * treat 400 (`invalid_grant`) as `auth`: the grant is gone and only a new
   * consent can fix it.
   */
  statusKinds?: Partial<Record<number, AccountingErrorKind>>;
  /** Body-aware override, e.g. QuickBooks answers "not found" with a 400 fault code. */
  classify?: (status: number, body: unknown) => AccountingErrorKind | null;
}

/** Seconds from a Retry-After header (delta-seconds or HTTP date). */
export function parseRetryAfter(value: string | null, now = Date.now()): number | null {
  if (!value) return null;
  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) return Math.ceil(seconds);
  const date = Date.parse(value);
  if (Number.isFinite(date)) return Math.max(0, Math.ceil((date - now) / 1000));
  return null;
}

export function kindForStatus(status: number): AccountingErrorKind {
  if (status === 401) return 'auth';
  if (status === 404 || status === 410) return 'not_found';
  if (status === 429) return 'rate_limited';
  if (status === 408 || status === 409 || status === 423 || status === 425) return 'transient';
  if (status >= 500) return 'transient';
  return 'permanent';
}

function safeJson(text: string): unknown {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

/**
 * Sends the request and returns the raw Response when it is 2xx; throws an
 * AccountingError otherwise. Network failures (DNS, reset) are `transient`.
 */
export async function providerFetch(req: ProviderRequest): Promise<Response> {
  let res: Response;
  try {
    res = await req.fetch(req.url, {
      method: req.method ?? 'GET',
      headers: req.headers,
      body: req.body ?? undefined,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new AccountingError('transient', `${req.provider}: network error: ${message}`, {
      provider: req.provider,
    });
  }
  if (res.ok) return res;

  const text = await res.text().catch(() => '');
  const body = safeJson(text);
  const detail = req.errorMessage?.(body, text) ?? (text.slice(0, 300) || res.statusText);
  const kind = req.classify?.(res.status, body) ?? req.statusKinds?.[res.status] ??
    kindForStatus(res.status);
  throw new AccountingError(kind, `${req.provider} ${res.status}: ${detail}`, {
    status: res.status,
    retryAfterSeconds: parseRetryAfter(res.headers.get('retry-after')),
    provider: req.provider,
  });
}

/** `providerFetch` + JSON body. An empty 2xx body resolves to null. */
export async function providerJson<T = unknown>(req: ProviderRequest): Promise<T> {
  const res = await providerFetch(req);
  const text = await res.text();
  return safeJson(text) as T;
}

export function basicAuth(clientId: string, clientSecret: string): string {
  return `Basic ${btoa(`${clientId}:${clientSecret}`)}`;
}

export function formBody(values: Record<string, string | null | undefined>): URLSearchParams {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) {
    if (value !== null && value !== undefined) params.set(key, value);
  }
  return params;
}

/**
 * Standard RFC 6749 token response → TokenBundle. When a refresh response
 * omits `refresh_token` (some providers only rotate it sometimes) the previous
 * one is kept.
 */
export function tokenBundleFromResponse(
  body: unknown,
  previous: TokenBundle | null,
  now = new Date(),
  provider: AccountingProvider | null = null,
): TokenBundle {
  const data = (body ?? {}) as Record<string, unknown>;
  const access = typeof data.access_token === 'string' ? data.access_token : '';
  if (!access) {
    throw new AccountingError('auth', 'Token endpoint returned no access_token', { provider });
  }
  const expiresIn = Number(data.expires_in);
  const lifetime = Number.isFinite(expiresIn) && expiresIn > 0 ? expiresIn : 3600;
  // QuickBooks: x_refresh_token_expires_in; others: refresh_token_expires_in.
  const refreshIn = Number(data.x_refresh_token_expires_in ?? data.refresh_token_expires_in);
  return {
    access_token: access,
    refresh_token: typeof data.refresh_token === 'string'
      ? data.refresh_token
      : previous?.refresh_token ?? null,
    expires_at: new Date(now.getTime() + lifetime * 1000).toISOString(),
    refresh_expires_at: Number.isFinite(refreshIn) && refreshIn > 0
      ? new Date(now.getTime() + refreshIn * 1000).toISOString()
      : previous?.refresh_expires_at ?? null,
    token_type: typeof data.token_type === 'string' ? data.token_type : 'Bearer',
    scope: typeof data.scope === 'string' ? data.scope : previous?.scope ?? null,
  };
}

/** Status kinds for token endpoints: a rejected grant means re-consent. */
export const TOKEN_ENDPOINT_KINDS: Partial<Record<number, AccountingErrorKind>> = {
  400: 'auth',
  401: 'auth',
  403: 'auth',
};

export function bytesToBase64(bytes: Uint8Array): string {
  // Chunked: spreading a multi-megabyte array into fromCharCode overflows the stack.
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

/** Copies into a fresh ArrayBuffer-backed view so Blob accepts it under strict lib types. */
export function toBlob(bytes: Uint8Array, contentType: string): Blob {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return new Blob([copy.buffer], { type: contentType });
}

/** Decimal string → number for providers whose JSON wants numbers. */
export function decimalNumber(value: string): number {
  return Number(value);
}
