import type { SupabaseClient } from '@supabase/supabase-js';
import { PDFDocument, type PDFFont, type PDFPage, rgb, StandardFonts } from 'pdf-lib';
import {
  categoryLabel,
  formatAmount,
  formatDate,
  humaniseKey,
  type Report,
  type ReportRow,
  SCOPE_LABEL,
} from './report';

/**
 * The expense report as a PDF, with the receipts attached at the back.
 *
 * Receipt files live in the private `receipts` bucket. They are fetched here,
 * on the server, through short-lived signed URLs made with the signed-in
 * user's own session, so storage row security decides what can be read and
 * nothing is ever exposed to the browser.
 */

// ---------------------------------------------------------------------------
// Receipt files
// ---------------------------------------------------------------------------

type FileKind = 'jpeg' | 'png' | 'pdf';

export interface ReceiptFile {
  kind: FileKind;
  bytes: Uint8Array;
}

export interface ReceiptAttachment {
  files: ReceiptFile[];
  /** Pages that could not be fetched or read (HEIC, missing object, timeout). */
  missing: number;
}

// A report is downloaded in one request, and a serverless function has a
// memory and time budget. These keep a year of receipts inside it; past them
// the report says how many were left out instead of failing.
export const MAX_RECEIPTS_IN_PDF = 150;
const MAX_FILES_PER_RECEIPT = 4;
const MAX_TOTAL_BYTES = 60 * 1024 * 1024;
const FETCH_CONCURRENCY = 6;
const SIGNED_URL_SECONDS = 120;

function sniff(bytes: Uint8Array): FileKind | null {
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'jpeg';
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) {
    return 'png';
  }
  const head = new TextDecoder('latin1').decode(bytes.subarray(0, 1024));
  return head.includes('%PDF-') ? 'pdf' : null;
}

async function mapLimit<T, R>(items: T[], limit: number, task: (item: T) => Promise<R>) {
  const results: R[] = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const index = next++;
      results[index] = await task(items[index]);
    }
  });
  await Promise.all(workers);
  return results;
}

export async function loadReceiptFiles(
  client: SupabaseClient,
  rows: ReportRow[],
): Promise<{ attachments: Map<string, ReceiptAttachment>; omitted: number }> {
  const receiptIds = [...new Set(rows.map((row) => row.receiptId).filter(Boolean))] as string[];
  const wanted = receiptIds.slice(0, MAX_RECEIPTS_IN_PDF);
  const attachments = new Map<string, ReceiptAttachment>();
  if (wanted.length === 0) return { attachments, omitted: 0 };

  const paths = new Map<string, string[]>();
  for (let start = 0; start < wanted.length; start += 100) {
    const { data } = await client
      .from('money_receipts')
      .select('id, image_paths')
      .in('id', wanted.slice(start, start + 100))
      .is('deleted_at', null);
    for (const row of (data ?? []) as { id: string; image_paths: string[] | null }[]) {
      paths.set(row.id, (row.image_paths ?? []).slice(0, MAX_FILES_PER_RECEIPT));
    }
  }

  const allPaths = [...paths.values()].flat();
  const signed = new Map<string, string>();
  for (let start = 0; start < allPaths.length; start += 100) {
    const { data } = await client.storage
      .from('receipts')
      .createSignedUrls(allPaths.slice(start, start + 100), SIGNED_URL_SECONDS);
    for (const item of data ?? []) {
      if (item.path && item.signedUrl && !item.error) signed.set(item.path, item.signedUrl);
    }
  }

  let budget = MAX_TOTAL_BYTES;
  const jobs = [...paths.entries()].flatMap(([receiptId, list]) =>
    list.map((path, page) => ({ receiptId, path, page })),
  );
  const fetched = await mapLimit(jobs, FETCH_CONCURRENCY, async (job) => {
    const url = signed.get(job.path);
    if (!url || budget <= 0) return null;
    try {
      const response = await fetch(url, { cache: 'no-store', signal: AbortSignal.timeout(15_000) });
      if (!response.ok) return null;
      const bytes = new Uint8Array(await response.arrayBuffer());
      budget -= bytes.length;
      if (budget < 0) return null;
      const kind = sniff(bytes);
      return kind ? { kind, bytes } : null;
    } catch {
      return null;
    }
  });

  jobs.forEach((job, index) => {
    const attachment = attachments.get(job.receiptId) ?? { files: [], missing: 0 };
    const file = fetched[index];
    if (file) attachment.files.push(file);
    else attachment.missing++;
    attachments.set(job.receiptId, attachment);
  });
  for (const receiptId of wanted) {
    if (!attachments.has(receiptId)) attachments.set(receiptId, { files: [], missing: 1 });
  }
  return { attachments, omitted: receiptIds.length - wanted.length };
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

const PAGE: [number, number] = [595.28, 841.89]; // A4 portrait, points
const MARGIN = 48;
const CONTENT_WIDTH = PAGE[0] - MARGIN * 2;
const INK = rgb(0.1, 0.1, 0.12);
const MUTED = rgb(0.42, 0.42, 0.46);
const RULE = rgb(0.85, 0.85, 0.88);
const BAND = rgb(0.95, 0.95, 0.96);
const ACCENT = rgb(0.2, 0.36, 0.85);

interface Column {
  label: string;
  width: number;
  align?: 'right';
}

class Writer {
  page!: PDFPage;
  y = 0;
  private charCache = new Map<string, boolean>();

  constructor(
    readonly doc: PDFDocument,
    readonly regular: PDFFont,
    readonly bold: PDFFont,
  ) {
    this.newPage();
  }

  newPage() {
    this.page = this.doc.addPage(PAGE);
    this.y = PAGE[1] - MARGIN;
  }

  ensure(height: number, onBreak?: () => void) {
    if (this.y - height < MARGIN + 18) {
      this.newPage();
      onBreak?.();
    }
  }

  /**
   * Text the standard fonts can draw. They cover Latin-1 (accented Italian
   * and French merchant names, €, £) but not Arabic, Greek or CJK, and
   * pdf-lib throws on any character outside the set, so those become "?".
   */
  safe(text: string, font: PDFFont = this.regular): string {
    const flat = text
      .replace(/[\r\n\t]+/g, ' ')
      .replace(/[\u2000-\u200b\u202f\u205f]/g, ' ')
      .replace(/\u2192/g, '->');
    try {
      font.encodeText(flat);
      return flat;
    } catch {
      let out = '';
      for (const char of flat) {
        let ok = this.charCache.get(char);
        if (ok === undefined) {
          try {
            font.encodeText(char);
            ok = true;
          } catch {
            ok = false;
          }
          this.charCache.set(char, ok);
        }
        out += ok ? char : '?';
      }
      return out;
    }
  }

  /** Cuts text with an ellipsis so it fits `width`. */
  fit(text: string, width: number, size: number, font: PDFFont): string {
    const clean = this.safe(text, font);
    if (font.widthOfTextAtSize(clean, size) <= width) return clean;
    let low = 0;
    let high = clean.length;
    while (low < high) {
      const mid = Math.ceil((low + high) / 2);
      if (font.widthOfTextAtSize(`${clean.slice(0, mid)}…`, size) <= width) low = mid;
      else high = mid - 1;
    }
    return `${clean.slice(0, low)}…`;
  }

  text(
    value: string,
    options: { x?: number; size?: number; font?: PDFFont; color?: ReturnType<typeof rgb> } = {},
  ) {
    const size = options.size ?? 10;
    const font = options.font ?? this.regular;
    this.page.drawText(
      this.fit(value, CONTENT_WIDTH - ((options.x ?? MARGIN) - MARGIN), size, font),
      {
        x: options.x ?? MARGIN,
        y: this.y - size,
        size,
        font,
        color: options.color ?? INK,
      },
    );
  }

  row(columns: Column[], values: string[], options: { header?: boolean; band?: boolean } = {}) {
    const size = options.header ? 8 : 9;
    const font = options.header ? this.bold : this.regular;
    const height = 16;
    if (options.band) {
      this.page.drawRectangle({
        x: MARGIN,
        y: this.y - height + 3,
        width: CONTENT_WIDTH,
        height,
        color: BAND,
      });
    }
    let x = MARGIN;
    columns.forEach((column, index) => {
      const value = this.fit(values[index] ?? '', column.width - 6, size, font);
      const width = font.widthOfTextAtSize(value, size);
      this.page.drawText(value, {
        x: column.align === 'right' ? x + column.width - 3 - width : x + 3,
        y: this.y - 10,
        size,
        font,
        color: options.header ? MUTED : INK,
      });
      x += column.width;
    });
    this.y -= height;
    if (options.header) this.rule();
  }

  rule() {
    this.page.drawLine({
      start: { x: MARGIN, y: this.y + 2 },
      end: { x: MARGIN + CONTENT_WIDTH, y: this.y + 2 },
      thickness: 0.5,
      color: RULE,
    });
  }

  gap(points: number) {
    this.y -= points;
  }
}

const CATEGORY_COLUMNS: Column[] = [
  { label: 'Category', width: 279 },
  { label: 'Items', width: 60, align: 'right' },
  { label: 'Not converted', width: 80, align: 'right' },
  { label: 'Total', width: 80, align: 'right' },
];

const LINE_COLUMNS: Column[] = [
  { label: 'Date', width: 62 },
  { label: 'Merchant', width: 128 },
  { label: 'Category', width: 84 },
  { label: 'Scope', width: 50 },
  { label: 'Amount', width: 72, align: 'right' },
  { label: 'Home', width: 72, align: 'right' },
  { label: 'Rcpt', width: 31, align: 'right' },
];

export async function buildReportPdf(
  report: Report,
  attachments: Map<string, ReceiptAttachment>,
  omittedReceipts: number,
  generatedAt = new Date(),
): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  doc.setTitle(`Expense report ${report.filters.from} to ${report.filters.to}`);
  doc.setCreator('Veralify');
  doc.setProducer('Veralify');
  const regular = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const w = new Writer(doc, regular, bold);
  const home = report.homeCurrency;
  const names = new Map(report.categories.map((row) => [row.key, row.name]));

  // Receipts are numbered in the order they appear, so a line's "#3" leads
  // straight to the third receipt at the back.
  const receiptNumbers = new Map<string, number>();
  for (const row of report.rows) {
    if (row.receiptId && attachments.has(row.receiptId) && !receiptNumbers.has(row.receiptId)) {
      receiptNumbers.set(row.receiptId, receiptNumbers.size + 1);
    }
  }

  // Heading
  w.text('Expense report', { size: 22, font: bold });
  w.gap(30);
  w.text(
    `${formatDate(report.filters.from)} – ${formatDate(report.filters.to)} · ${SCOPE_LABEL[report.filters.scope]} · ${categoryLabel(report)}`,
    { size: 11, color: MUTED },
  );
  w.gap(16);
  w.text(
    `Generated ${formatDate(generatedAt.toISOString().slice(0, 10))} · Totals in ${home} at ECB reference rates`,
    { size: 9, color: MUTED },
  );
  w.gap(28);

  // Summary
  const stats: [string, string][] = [
    ['Total', formatAmount(report.total, home)],
    ['Expenses', String(report.rows.length)],
    ['With receipt', String(report.receiptCount)],
    ['Not converted', String(report.unconvertedCount)],
  ];
  stats.forEach(([label, value], index) => {
    const x = MARGIN + index * (CONTENT_WIDTH / 4);
    w.page.drawText(w.safe(label), { x, y: w.y - 8, size: 8, font: regular, color: MUTED });
    w.page.drawText(w.safe(value, bold), {
      x,
      y: w.y - 26,
      size: 15,
      font: bold,
      color: index === 0 ? ACCENT : INK,
    });
  });
  w.gap(44);
  if (report.unconvertedCount > 0) {
    w.text(
      `${report.unconvertedCount} foreign-currency expense(s) had no exchange rate for their date and are listed but not included in the totals.`,
      { size: 8, color: MUTED },
    );
    w.gap(14);
  }
  if (report.truncated) {
    w.text('This selection was too large; only the first 5,000 expenses are included.', {
      size: 8,
      color: MUTED,
    });
    w.gap(14);
  }

  // By category
  w.gap(8);
  w.text('By category', { size: 13, font: bold });
  w.gap(20);
  w.row(
    CATEGORY_COLUMNS,
    CATEGORY_COLUMNS.map((column) => column.label),
    { header: true },
  );
  report.byCategory.forEach((line, index) => {
    w.ensure(16, () =>
      w.row(
        CATEGORY_COLUMNS,
        CATEGORY_COLUMNS.map((column) => column.label),
        { header: true },
      ),
    );
    w.row(
      CATEGORY_COLUMNS,
      [
        line.name,
        String(line.count),
        line.unconverted ? String(line.unconverted) : '',
        formatAmount(line.total, home),
      ],
      { band: index % 2 === 1 },
    );
  });
  w.rule();
  w.row(
    CATEGORY_COLUMNS,
    ['Total', String(report.rows.length), '', formatAmount(report.total, home)],
    {
      header: false,
    },
  );

  // Lines
  w.gap(18);
  w.ensure(60);
  w.text('Expenses', { size: 13, font: bold });
  w.gap(20);
  const lineHeader = () =>
    w.row(
      LINE_COLUMNS,
      LINE_COLUMNS.map((column) => (column.label === 'Home' ? home : column.label)),
      { header: true },
    );
  lineHeader();
  if (report.rows.length === 0) {
    w.text('No expenses match this selection.', { size: 9, color: MUTED });
    w.gap(16);
  }
  report.rows.forEach((row, index) => {
    w.ensure(16, lineHeader);
    const number = row.receiptId ? receiptNumbers.get(row.receiptId) : undefined;
    w.row(
      LINE_COLUMNS,
      [
        row.date,
        row.merchant,
        names.get(row.category) ?? humaniseKey(row.category),
        row.scope === 'business' ? 'Business' : 'Personal',
        formatAmount(row.amount, row.currency),
        row.homeAmount === null ? '—' : formatAmount(row.homeAmount, home),
        number ? `#${number}` : '',
      ],
      { band: index % 2 === 1 },
    );
  });

  // Receipts
  const rowByReceipt = new Map<string, ReportRow>();
  for (const row of report.rows) {
    if (row.receiptId && !rowByReceipt.has(row.receiptId)) rowByReceipt.set(row.receiptId, row);
  }
  for (const [receiptId, number] of receiptNumbers) {
    const attachment = attachments.get(receiptId);
    const row = rowByReceipt.get(receiptId);
    if (!attachment || !row) continue;
    const caption = `Receipt #${number} · ${row.merchant} · ${formatDate(row.date)} · ${formatAmount(row.amount, row.currency)}`;
    if (attachment.files.length === 0) {
      w.newPage();
      w.text(caption, { size: 11, font: bold });
      w.gap(20);
      w.text('The receipt image could not be included (missing or in an unsupported format).', {
        size: 9,
        color: MUTED,
      });
      continue;
    }
    for (const file of attachment.files) {
      await drawReceiptFile(w, file, caption);
    }
  }
  if (omittedReceipts > 0) {
    w.newPage();
    w.text(
      `${omittedReceipts} further receipt(s) were not attached to keep this file a manageable size. Narrow the date range to include them.`,
      { size: 9, color: MUTED },
    );
  }

  // Page numbers, now that the count is known.
  const pages = doc.getPages();
  pages.forEach((page, index) => {
    const label = `Page ${index + 1} of ${pages.length}`;
    page.drawText(label, {
      x: PAGE[0] - MARGIN - regular.widthOfTextAtSize(label, 8),
      y: MARGIN / 2,
      size: 8,
      font: regular,
      color: MUTED,
    });
  });

  return doc.save();
}

/** One receipt page: a caption, then the image (or the PDF's pages) scaled to fit below it. */
async function drawReceiptFile(w: Writer, file: ReceiptFile, caption: string) {
  const box = { width: CONTENT_WIDTH, height: PAGE[1] - MARGIN * 2 - 40 };
  const place = (width: number, height: number) => {
    const scale = Math.min(box.width / width, box.height / height, 1.5);
    return { width: width * scale, height: height * scale };
  };
  try {
    if (file.kind === 'pdf') {
      const source = await PDFDocument.load(file.bytes, { ignoreEncryption: true });
      const indices = source.getPageIndices().slice(0, MAX_FILES_PER_RECEIPT);
      const embedded = await w.doc.embedPdf(source, indices);
      for (const page of embedded) {
        w.newPage();
        w.text(caption, { size: 11, font: w.bold });
        const size = place(page.width, page.height);
        w.page.drawPage(page, {
          x: MARGIN + (box.width - size.width) / 2,
          y: w.y - 30 - size.height,
          ...size,
        });
      }
      return;
    }
    const image =
      file.kind === 'jpeg' ? await w.doc.embedJpg(file.bytes) : await w.doc.embedPng(file.bytes);
    w.newPage();
    w.text(caption, { size: 11, font: w.bold });
    const size = place(image.width, image.height);
    w.page.drawImage(image, {
      x: MARGIN + (box.width - size.width) / 2,
      y: w.y - 30 - size.height,
      ...size,
    });
  } catch {
    w.newPage();
    w.text(caption, { size: 11, font: w.bold });
    w.gap(20);
    w.text('This receipt file could not be read.', { size: 9, color: MUTED });
  }
}
