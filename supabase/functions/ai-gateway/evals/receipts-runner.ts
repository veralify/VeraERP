// Receipt-reading evaluation.
//
// Runs each case through the real `receipts-extract` route — the same
// normalisation, rules and validation the app gets — against an in-memory
// database, and scores the stored extraction field by field.
//
//   deno run --allow-read --allow-write --allow-env evals/receipts-runner.ts
//       offline: every case answers from its `mock_model_output`, which checks
//       the scoring and the server-side pipeline, not the model.
//   deno run --allow-read --allow-write --allow-env --allow-net evals/receipts-runner.ts --real-openrouter
//       sends each case's images to the `multimodal_primary` role for real
//       (OPENROUTER_API_KEY must be set). Cases without images are skipped.
//
// Case files are JSONL; see evals/receipts/README.md for the format and for
// where anonymised receipt images go (they are never committed).

import { OpenRouterClient } from '../openrouter.ts';
import { loadModelPolicy } from '../registry.ts';
import { handleReceiptsExtract, type ReceiptsDeps } from '../receipts.ts';
import type { ReceiptExtraction } from '../receipt-schema.ts';
import { resetInMemoryRateLimitsForTests } from '../ratelimit.ts';
import { completion, FakeDb, fakeTransport } from '../tests/receipts_fakes.ts';

export type ReceiptEvalCase = {
  id: string;
  /** File names inside evals/receipts/images/, one per page, in order. */
  images?: string[];
  locale?: string;
  home_currency?: string;
  /** The user's category keys; the contract's defaults when omitted. */
  categories?: string[];
  /** What the model would answer, for offline runs. */
  mock_model_output?: unknown;
  /** Only the fields listed are scored. */
  expected: {
    unreadable?: boolean;
    document_type?: string;
    merchant_key?: string;
    vat_id?: string;
    country?: string;
    date?: string;
    currency?: string;
    total?: string;
    tax_total?: string;
    tax_rates?: string[];
    category?: string;
    payment_method?: string;
    line_item_count?: number;
  };
};

type FieldScore = {
  field: string;
  expected: unknown;
  actual: unknown;
  correct: boolean;
  flagged: boolean | null;
};
type CaseScore = {
  id: string;
  passed: boolean;
  status: number;
  latency_ms: number;
  cost_usd: number;
  fields: FieldScore[];
  error?: string;
};

const USER = '00000000-0000-4000-8000-00000000e7a1';
const HERE = new URL('./', import.meta.url);

async function loadCases(path: string | URL): Promise<ReceiptEvalCase[]> {
  return (await Deno.readTextFile(path))
    .split('\n')
    .filter((line) => line.trim() && !line.trimStart().startsWith('#'))
    .map((line) => JSON.parse(line));
}

function mimeOf(name: string) {
  const ext = name.split('.').pop()?.toLowerCase();
  return ext === 'png' ? 'image/png' : ext === 'pdf' ? 'application/pdf' : 'image/jpeg';
}

/** Field-level checks. `flagged` is whether the app would have highlighted it (<0.75). */
function scoreFields(c: ReceiptEvalCase, e: ReceiptExtraction | null): FieldScore[] {
  const x = c.expected;
  const out: FieldScore[] = [];
  const add = (field: string, expected: unknown, actual: unknown, confidence?: number) => {
    if (expected === undefined) return;
    out.push({
      field,
      expected,
      actual,
      correct: JSON.stringify(expected) === JSON.stringify(actual),
      flagged: confidence === undefined ? null : confidence < 0.75,
    });
  };
  add('document_type', x.document_type, e?.document_type);
  add('merchant_key', x.merchant_key, e?.merchant_key, e?.merchant.name.confidence);
  add('vat_id', x.vat_id, e?.merchant.vat_id.value, e?.merchant.vat_id.confidence);
  add('country', x.country, e?.merchant.country.value, e?.merchant.country.confidence);
  add('date', x.date, e?.date.value, e?.date.confidence);
  add('currency', x.currency, e?.currency.value, e?.currency.confidence);
  add('total', x.total, e?.total.value, e?.total.confidence);
  add('tax_total', x.tax_total, e?.tax_total.value, e?.tax_total.confidence);
  add('tax_rates', x.tax_rates, e ? e.tax_lines.map((t) => t.rate).sort() : undefined);
  add('category', x.category, e?.category.key, e?.category.confidence);
  add('payment_method', x.payment_method, e?.payment.method.value, e?.payment.method.confidence);
  add('line_item_count', x.line_item_count, e?.line_items.length);
  return out;
}

async function runCase(
  c: ReceiptEvalCase,
  realModel: boolean,
  deps: Omit<ReceiptsDeps, 'db' | 'openRouter'>,
) {
  const receiptId = crypto.randomUUID();
  const images = c.images ?? [];
  const db = new FakeDb({
    money_receipts: [{
      id: receiptId,
      user_id: USER,
      status: 'uploaded',
      image_paths: (images.length ? images : ['placeholder.jpg']).map((_, i) =>
        `${USER}/${receiptId}/${i + 1}.jpg`
      ),
      deleted_at: null,
    }],
    money_categories: (c.categories ?? []).map((key) => ({
      user_id: USER,
      key,
      kind: 'expense',
      deleted_at: null,
    })),
  });
  if (images.length) {
    for (const [i, name] of images.entries()) {
      const bytes = await Deno.readFile(new URL(`receipts/images/${name}`, HERE));
      db.files.set(`${USER}/${receiptId}/${i + 1}.jpg`, new Blob([bytes], { type: mimeOf(name) }));
    }
  } else {
    // Offline cases need no real image: the mock answer stands in for the read.
    db.files.set(
      `${USER}/${receiptId}/1.jpg`,
      new Blob([new Uint8Array([0xff, 0xd8])], { type: 'image/jpeg' }),
    );
  }

  const { transport } = fakeTransport(() => completion(c.mock_model_output ?? {}));
  const client = realModel
    ? new OpenRouterClient(Deno.env.get('OPENROUTER_API_KEY') ?? '', fetch)
    : new OpenRouterClient('eval-mock', transport);
  resetInMemoryRateLimitsForTests();

  const started = performance.now();
  const res = await handleReceiptsExtract(
    new Request('http://eval/functions/v1/ai-gateway/receipts-extract', {
      method: 'POST',
      headers: { authorization: 'Bearer eval-service', 'content-type': 'application/json' },
      body: JSON.stringify({
        receipt_id: receiptId,
        user_id: USER,
        locale: c.locale ?? 'it-IT',
        home_currency: c.home_currency ?? 'EUR',
      }),
    }),
    () => Promise.resolve({ ...deps, db, openRouter: () => client }),
  );
  const latency = Math.round(performance.now() - started);
  const body = await res.json();
  const extraction = res.status === 200 ? body as ReceiptExtraction : null;
  const fields = scoreFields(c, extraction);
  const unreadableOk = c.expected.unreadable === undefined ||
    c.expected.unreadable === (res.status === 422);
  return {
    id: c.id,
    passed: unreadableOk && fields.every((f) => f.correct),
    status: res.status,
    latency_ms: latency,
    cost_usd: Number(db.usage(USER)?.cost_usd ?? 0),
    fields,
    error: res.status === 200 ? undefined : body.error,
  } satisfies CaseScore;
}

function summarise(scores: CaseScore[]) {
  const fields = scores.flatMap((s) => s.fields);
  const byField: Record<string, { count: number; accuracy: number }> = {};
  for (const name of new Set(fields.map((f) => f.field))) {
    const of = fields.filter((f) => f.field === name);
    byField[name] = { count: of.length, accuracy: of.filter((f) => f.correct).length / of.length };
  }
  // Calibration that matters to the user: how many wrong values the review
  // screen failed to highlight.
  const wrong = fields.filter((f) => !f.correct && f.flagged !== null);
  return {
    cases: scores.length,
    pass_rate: scores.filter((s) => s.passed).length / Math.max(scores.length, 1),
    field_accuracy: byField,
    wrong_but_not_flagged: wrong.filter((f) => !f.flagged).length,
    wrong_and_flagged: wrong.filter((f) => f.flagged).length,
    avg_latency_ms: scores.reduce((s, c) => s + c.latency_ms, 0) / Math.max(scores.length, 1),
    total_cost_usd: scores.reduce((s, c) => s + c.cost_usd, 0),
  };
}

export async function runReceiptEval(
  manifest: string | URL,
  options: { realModel?: boolean; outDir?: string; write?: boolean } = {},
) {
  const policy = await loadModelPolicy();
  const prompt = await Deno.readTextFile(
    new URL('../prompts/receipts-extraction.md', import.meta.url),
  );
  const cases = (await loadCases(manifest)).filter((c) =>
    !options.realModel || (c.images?.length ?? 0) > 0
  );
  const deps = {
    serviceRoleKey: 'eval-service',
    userIdForToken: () => Promise.resolve(null),
    policy,
    scanLimit: 1_000_000,
    prompt,
  };
  const scores: CaseScore[] = [];
  for (const c of cases) scores.push(await runCase(c, !!options.realModel, deps));

  const report = {
    generated_at: new Date().toISOString(),
    manifest: String(manifest),
    mode: options.realModel ? 'openrouter' : 'mock',
    model_policy_version: policy.model_policy_version,
    summary: summarise(scores),
    cases: scores,
  };
  // The unit tests run the seed set without write permission.
  if (options.write !== false) {
    const outDir = options.outDir ?? new URL('./out', import.meta.url).pathname;
    await Deno.mkdir(outDir, { recursive: true });
    await Deno.writeTextFile(`${outDir}/receipts.report.json`, JSON.stringify(report, null, 2));
  }
  return report;
}

if (import.meta.main) {
  const manifest = Deno.args.find((a) => !a.startsWith('--')) ??
    new URL('./datasets/receipts_seed.jsonl', import.meta.url);
  const realModel = Deno.args.includes('--real-openrouter');
  const outDir = Deno.args.find((a) => a.startsWith('--out='))?.slice(6);
  const report = await runReceiptEval(manifest, { realModel, outDir });
  console.log(JSON.stringify(report.summary, null, 2));
}
