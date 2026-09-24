// Supabase clients and request authentication for the accounting functions.

import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.49.8';
import { corsHeaders } from '../http.ts';
import { AccountingError } from './types.ts';

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

/** An error that maps to a JSON `{ error, message }` response (contract §5 style). */
export class HttpError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message);
  }
}

export function bearer(req: Request): string | null {
  const header = req.headers.get('authorization') ?? '';
  const [scheme, token] = header.split(' ');
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
}

/** The signed-in caller, from their access token. */
export async function requireUser(req: Request, db: SupabaseClient): Promise<{ id: string }> {
  const token = bearer(req);
  if (!token) throw new HttpError(401, 'UNAUTHENTICATED', 'Bearer token required.');
  const { data, error } = await db.auth.getUser(token);
  if (error || !data.user?.id) throw new HttpError(401, 'UNAUTHENTICATED', 'Invalid bearer token.');
  return { id: data.user.id };
}

/** Worker endpoints accept only the service-role key (cron / pg_net). */
export function isServiceRequest(req: Request): boolean {
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  return !!key && bearer(req) === key;
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Content-Type': 'application/json',
    },
  });
}

/** Turns anything thrown by a handler into a JSON error response. */
export function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) {
    return jsonResponse({ error: error.code, message: error.message }, error.status);
  }
  if (error instanceof AccountingError) {
    const status = error.kind === 'auth'
      ? 409
      : error.kind === 'rate_limited'
      ? 429
      : error.kind === 'config'
      ? 500
      : 502;
    const code = error.kind === 'auth'
      ? 'NEEDS_REAUTH'
      : error.kind === 'rate_limited'
      ? 'RATE_LIMITED'
      : error.kind === 'config'
      ? 'NOT_CONFIGURED'
      : 'PROVIDER_ERROR';
    return jsonResponse({ error: code, message: error.message }, status);
  }
  console.error(error);
  return jsonResponse({ error: 'INTERNAL_ERROR', message: 'Something went wrong.' }, 500);
}

export async function readJson(req: Request): Promise<Record<string, unknown>> {
  try {
    const body = await req.json();
    return body && typeof body === 'object' ? body as Record<string, unknown> : {};
  } catch {
    return {};
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID.test(value);
}
