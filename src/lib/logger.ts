/**
 * Lightweight, dev-only structured logger for API routes.
 *
 * Emits nicely formatted, colorized logs of the request lifecycle and every
 * outbound `fetch` (Supabase, Resend, …) with status + timing. It stays
 * completely silent in production so nothing leaks into server logs there.
 *
 * Enable in production for debugging by setting `DEBUG_API=1`.
 */

const enabled = process.env.NODE_ENV !== 'production' || process.env.DEBUG_API === '1';

const c = {
  reset: '\x1b[0m',
  dim: '\x1b[2m',
  bold: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  gray: '\x1b[90m',
};

let seq = 0;
const nextId = () => (++seq).toString(36).padStart(3, '0');

const stamp = () => new Date().toISOString().slice(11, 23);

const statusColor = (status: number) =>
  status >= 500 ? c.red : status >= 400 ? c.yellow : status >= 300 ? c.cyan : c.green;

const fmtMeta = (meta?: unknown) => {
  if (meta === undefined) return '';
  if (typeof meta === 'string') return ` ${c.dim}${meta}${c.reset}`;
  try {
    return ` ${c.dim}${JSON.stringify(meta)}${c.reset}`;
  } catch {
    return '';
  }
};

/**
 * Strip the Supabase/Resend origin so logs stay short, and redact any
 * sensitive query params (tokens, keys) that might appear in a URL.
 */
const sanitizeUrl = (url: string) => {
  try {
    const u = new URL(url);
    for (const key of u.searchParams.keys()) {
      if (/token|apikey|key|secret|password/i.test(key)) {
        u.searchParams.set(key, '***');
      }
    }
    return `${u.host}${u.pathname}${u.search}`;
  } catch {
    return url;
  }
};

export type ApiLogger = {
  /** The unique id for this request. */
  readonly id: string;
  info: (msg: string, meta?: unknown) => void;
  warn: (msg: string, meta?: unknown) => void;
  error: (msg: string, meta?: unknown) => void;
  /** Drop-in `fetch` replacement that logs method, url, status and duration. */
  fetch: typeof fetch;
  /** Log the final response for this request. */
  done: (status: number, meta?: unknown) => void;
};

const line = (id: string, color: string, label: string, msg: string, meta?: unknown) => {
  console.log(
    `${c.gray}${stamp()}${c.reset} ${color}${label}${c.reset} ${c.dim}#${id}${c.reset} ${msg}${fmtMeta(
      meta,
    )}`,
  );
};

const noop = () => {};

/**
 * Create a request-scoped logger. Pass the route name and the incoming request;
 * it logs the inbound line immediately and returns helpers for the rest of the
 * request's life.
 */
export function apiLogger(route: string, request?: Request): ApiLogger {
  const id = nextId();
  const start = Date.now();

  if (!enabled) {
    const passthroughFetch = ((input: RequestInfo | URL, init?: RequestInit) =>
      fetch(input, init)) as typeof fetch;
    return {
      id,
      info: noop,
      warn: noop,
      error: noop,
      fetch: passthroughFetch,
      done: noop,
    };
  }

  const method = request?.method ?? 'GET';
  line(id, c.bold + c.magenta, '→ API', `${c.bold}${method}${c.reset} ${route}`);

  const loggedFetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    const m = (init?.method ?? (input instanceof Request ? input.method : 'GET')).toUpperCase();
    const t0 = Date.now();
    try {
      const res = await fetch(input, init);
      const ms = Date.now() - t0;
      line(
        id,
        statusColor(res.status),
        '  ↳ fetch',
        `${c.dim}${m}${c.reset} ${sanitizeUrl(url)} ${statusColor(res.status)}${res.status}${c.reset} ${c.dim}${ms}ms${c.reset}`,
      );
      return res;
    } catch (err) {
      const ms = Date.now() - t0;
      line(
        id,
        c.red,
        '  ↳ fetch',
        `${c.dim}${m}${c.reset} ${sanitizeUrl(url)} ${c.red}FAILED${c.reset} ${c.dim}${ms}ms${c.reset}`,
        err instanceof Error ? err.message : String(err),
      );
      throw err;
    }
  }) as typeof fetch;

  return {
    id,
    info: (msg, meta) => line(id, c.blue, '  ·', msg, meta),
    warn: (msg, meta) => line(id, c.yellow, '  ⚠', msg, meta),
    error: (msg, meta) => line(id, c.red, '  ✖', msg, meta),
    fetch: loggedFetch,
    done: (status, meta) => {
      const ms = Date.now() - start;
      line(
        id,
        statusColor(status),
        '← API',
        `${route} ${statusColor(status)}${status}${c.reset} ${c.dim}${ms}ms${c.reset}`,
        meta,
      );
    },
  };
}
