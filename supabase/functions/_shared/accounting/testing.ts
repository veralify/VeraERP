// Test helpers for the adapter and worker tests: a scripted fetch that
// records every request. Not a test file itself (no _test suffix).

import type { ExpenseDraft, FetchLike, TokenBundle } from './types.ts';

export interface RecordedRequest {
  method: string;
  url: URL;
  headers: Headers;
  body: BodyInit | null | undefined;
}

export type Responder = (request: RecordedRequest) => Response | Promise<Response>;

/**
 * Answers requests in order from `responses`; each entry is a Response or a
 * function of the request. Running out of responses fails the test loudly.
 */
export function scriptedFetch(responses: (Response | Responder)[]): {
  fetch: FetchLike;
  requests: RecordedRequest[];
} {
  const queue = [...responses];
  const requests: RecordedRequest[] = [];
  const fetch: FetchLike = async (input, init) => {
    const request: RecordedRequest = {
      method: init?.method ?? 'GET',
      url: new URL(typeof input === 'string' || input instanceof URL ? input : input.url),
      headers: new Headers(init?.headers),
      body: init?.body,
    };
    requests.push(request);
    const next = queue.shift();
    if (!next) throw new Error(`Unexpected request: ${request.method} ${request.url}`);
    return typeof next === 'function' ? await next(request) : next;
  };
  return { fetch, requests };
}

export function jsonResponse(
  body: unknown,
  status = 200,
  headers: Record<string, string> = {},
): Response {
  return new Response(body === null ? null : JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  });
}

export function jsonBody(request: RecordedRequest): Record<string, unknown> {
  return JSON.parse(String(request.body)) as Record<string, unknown>;
}

export function formValues(request: RecordedRequest): Record<string, string> {
  return Object.fromEntries(new URLSearchParams(String(request.body)));
}

export function testTokens(overrides: Partial<TokenBundle> = {}): TokenBundle {
  return {
    access_token: 'access-1',
    refresh_token: 'refresh-1',
    expires_at: new Date(Date.now() + 3600_000).toISOString(),
    token_type: 'Bearer',
    ...overrides,
  };
}

/** €/£ 24.00 including 4.00 VAT at 20%, one line. */
export function sampleDraft(overrides: Partial<ExpenseDraft> = {}): ExpenseDraft {
  return {
    transactionId: '0f8fad5b-d9cb-469f-a165-70867728950e',
    date: '2026-09-20',
    merchant: 'Staples',
    description: 'Staples — printer paper',
    currency: 'GBP',
    total: '24.00',
    taxTotal: '4.00',
    taxKnown: true,
    lines: [{
      description: 'Staples — printer paper',
      accountId: '429',
      taxCodeId: 'INPUT2',
      vatRate: '20',
      net: '20.00',
      tax: '4.00',
      gross: '24.00',
    }],
    paymentAccountId: 'bank-1',
    ...overrides,
  };
}

export const JPEG_BYTES = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4, 0xff, 0xd9]);
