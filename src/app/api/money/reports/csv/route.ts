import { createSupabaseServerClient } from '@lib/supabase/server';
import type { SupabaseClient } from '@supabase/supabase-js';
import {
  loadReport,
  parseReportFilters,
  reportFileName,
  reportToCsv,
} from '../../../../dashboard/money/reports/_lib/report';

export const dynamic = 'force-dynamic';

/** GET /api/money/reports/csv?from=&to=&scope=&category= — the report's lines as CSV. */
export async function GET(request: Request) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return Response.json({ error: 'UNAUTHENTICATED' }, { status: 401 });

  const filters = parseReportFilters(new URL(request.url).searchParams);
  try {
    const report = await loadReport(supabase as unknown as SupabaseClient, user.id, filters);
    return new Response(reportToCsv(report), {
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${reportFileName(filters, 'csv')}"`,
        'Cache-Control': 'private, no-store',
      },
    });
  } catch (error) {
    console.error('money report csv failed', error);
    return Response.json({ error: 'REPORT_FAILED' }, { status: 500 });
  }
}
