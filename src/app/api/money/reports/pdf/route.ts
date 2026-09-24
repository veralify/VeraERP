import { createSupabaseServerClient } from '@lib/supabase/server';
import type { SupabaseClient } from '@supabase/supabase-js';
import { buildReportPdf, loadReceiptFiles } from '../../../../dashboard/money/reports/_lib/pdf';
import {
  loadReport,
  parseReportFilters,
  reportFileName,
} from '../../../../dashboard/money/reports/_lib/report';

export const dynamic = 'force-dynamic';
// pdf-lib and the receipt downloads need Node, and a report with a year of
// receipts takes longer than the default limit on some hosts.
export const runtime = 'nodejs';
export const maxDuration = 60;

/** GET /api/money/reports/pdf?from=&to=&scope=&category= — the report with receipts attached. */
export async function GET(request: Request) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return Response.json({ error: 'UNAUTHENTICATED' }, { status: 401 });

  const filters = parseReportFilters(new URL(request.url).searchParams);
  const client = supabase as unknown as SupabaseClient;
  try {
    const report = await loadReport(client, user.id, filters);
    const { attachments, omitted } = await loadReceiptFiles(client, report.rows);
    const pdf = await buildReportPdf(report, attachments, omitted);
    return new Response(pdf as BodyInit, {
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="${reportFileName(filters, 'pdf')}"`,
        'Cache-Control': 'private, no-store',
      },
    });
  } catch (error) {
    console.error('money report pdf failed', error);
    return Response.json({ error: 'REPORT_FAILED' }, { status: 500 });
  }
}
