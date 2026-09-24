// In-memory stand-ins for the service-role Supabase client and OpenRouter,
// for driving the receipts route end to end in tests (and in the eval
// runner's offline mode).

import type { DbQuery, DbResult, ReceiptsDb } from '../receipts.ts';
import type { OpenRouterTransport } from '../openrouter.ts';

type Row = Record<string, unknown>;

/** Loose equality the way PostgREST compares a filter value to a column: as text. */
const same = (a: unknown, b: unknown) =>
  a === b || (a !== null && a !== undefined && String(a) === String(b));

class FakeQuery implements DbQuery {
  private op: 'select' | 'update' | 'insert' = 'select';
  private values: Row | Row[] = {};
  private filters: Array<(row: Row) => boolean> = [];
  private max = Infinity;

  constructor(private db: FakeDb, private table: string) {}

  select(_columns?: string): FakeQuery {
    return this;
  }
  update(values: Row): FakeQuery {
    this.op = 'update';
    this.values = values;
    return this;
  }
  insert(values: Row | Row[]): FakeQuery {
    this.op = 'insert';
    this.values = values;
    return this;
  }
  eq(column: string, value: unknown): FakeQuery {
    this.filters.push((row) => same(row[column], value));
    return this;
  }
  neq(column: string, value: unknown): FakeQuery {
    this.filters.push((row) => !same(row[column], value));
    return this;
  }
  is(column: string, value: null): FakeQuery {
    this.filters.push((row) => (row[column] ?? null) === value);
    return this;
  }
  limit(count: number): FakeQuery {
    this.max = count;
    return this;
  }
  maybeSingle(): Promise<DbResult> {
    return this.run().then((r) => ({
      data: Array.isArray(r.data) ? r.data[0] ?? null : r.data,
      error: r.error,
    }));
  }
  single(): Promise<DbResult> {
    return this.maybeSingle();
  }
  then<A = DbResult, B = never>(
    onfulfilled?: ((value: DbResult) => A | PromiseLike<A>) | null,
    onrejected?: ((reason: unknown) => B | PromiseLike<B>) | null,
  ): Promise<A | B> {
    return this.run().then(onfulfilled, onrejected);
  }

  private run(): Promise<DbResult> {
    const rows = this.db.table(this.table);
    if (this.op === 'insert') {
      const inserted = (Array.isArray(this.values) ? this.values : [this.values]).map((v) => ({
        id: crypto.randomUUID(),
        ...v,
      }));
      rows.push(...inserted);
      return Promise.resolve({ data: inserted, error: null });
    }
    const matched = rows.filter((row) => this.filters.every((f) => f(row)));
    if (this.op === 'update') {
      for (const row of matched) Object.assign(row, structuredClone(this.values));
      this.db.updates.push({ table: this.table, values: structuredClone(this.values) as Row });
      return Promise.resolve({ data: null, error: null });
    }
    return Promise.resolve({ data: structuredClone(matched.slice(0, this.max)), error: null });
  }
}

export class FakeDb implements ReceiptsDb {
  tables: Record<string, Row[]> = {};
  files = new Map<string, Blob>();
  updates: Array<{ table: string; values: Row }> = [];
  /** The month the fake claims scans against, as the SQL function returns it. */
  month = '2026-09-01';

  constructor(seed: Record<string, Row[]> = {}) {
    for (const [name, rows] of Object.entries(seed)) {
      this.tables[name] = rows.map((r) => ({ ...r }));
    }
  }

  table(name: string): Row[] {
    return (this.tables[name] ??= []);
  }

  from(table: string): FakeQuery {
    return new FakeQuery(this, table);
  }

  usage(userId: string): Row | undefined {
    return this.table('money_receipt_usage').find((r) =>
      r.user_id === userId && r.month === this.month
    );
  }

  /** Mirrors 20260925110000_money_receipt_scan_usage.sql. */
  rpc(fn: string, args: Record<string, unknown>): Promise<DbResult> {
    const userId = String(args.p_user_id);
    if (fn === 'money_claim_receipt_scan') {
      const limit = Number(args.p_limit);
      let row = this.usage(userId);
      if (!row) {
        if (limit <= 0) return Promise.resolve({ data: null, error: null });
        row = { user_id: userId, month: this.month, scans: 0, cost_usd: 0 };
        this.table('money_receipt_usage').push(row);
      }
      if (Number(row.scans) >= limit) return Promise.resolve({ data: null, error: null });
      row.scans = Number(row.scans) + 1;
      return Promise.resolve({ data: this.month, error: null });
    }
    if (fn === 'money_settle_receipt_scan') {
      const row = this.table('money_receipt_usage').find((r) =>
        r.user_id === userId && r.month === args.p_month
      );
      if (row) {
        if (!args.p_counted) row.scans = Math.max(Number(row.scans) - 1, 0);
        row.cost_usd = Number(row.cost_usd) + Number(args.p_cost_usd ?? 0);
      }
      return Promise.resolve({ data: null, error: null });
    }
    return Promise.resolve({ data: null, error: { message: `unknown function ${fn}` } });
  }

  storage = {
    from: (_bucket: string) => ({
      download: (path: string) => {
        const blob = this.files.get(path);
        return Promise.resolve(
          blob
            ? { data: blob, error: null }
            : { data: null, error: { message: 'Object not found' } },
        );
      },
    }),
  };
}

/** A chat-completions response carrying `content` as the model's message. */
export function completion(content: unknown, model = 'google/gemini-3.7-flash'): Response {
  return new Response(
    JSON.stringify({
      model,
      choices: [{
        message: { content: typeof content === 'string' ? content : JSON.stringify(content) },
      }],
      usage: { prompt_tokens: 1200, completion_tokens: 400 },
    }),
    { status: 200 },
  );
}

export type RecordedCall = { body: Record<string, unknown> };

/** A transport that answers from `respond` and records every request body. */
export function fakeTransport(
  respond: (body: Record<string, unknown>, call: number) => Response,
): { transport: OpenRouterTransport; calls: RecordedCall[] } {
  const calls: RecordedCall[] = [];
  const transport: OpenRouterTransport = (_input, init) => {
    const body = JSON.parse(String(init?.body ?? '{}'));
    calls.push({ body });
    return Promise.resolve(respond(body, calls.length));
  };
  return { transport, calls };
}

export const field = (value: string | null, confidence = 0.95) => ({ value, confidence });
