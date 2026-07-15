import { getActiveBrand } from '@config/brands';
import { apiLogger } from '@lib/logger';

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=30',
    },
  });

export async function GET(request: Request) {
  const log = apiLogger('/api/waitlist-count', request);
  const brand = getActiveBrand();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceRoleKey || serviceRoleKey === 'your_service_role_key') {
    log.warn('storage not configured');
    log.done(200, { count: 0 });
    return jsonResponse({ count: 0 });
  }

  try {
    // HEAD request with count=exact returns the total in the Content-Range
    // header without transferring any rows.
    const res = await log.fetch(
      `${supabaseUrl}/rest/v1/newsletter_subscribers?select=id&brand=eq.${encodeURIComponent(brand.id)}&status=eq.subscribed`,
      {
        method: 'HEAD',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          Prefer: 'count=exact',
          Range: '0-0',
        },
      },
    );

    const range = res.headers.get('content-range'); // e.g. "0-0/42"
    const total = range?.split('/')?.[1];
    const count = total ? Number.parseInt(total, 10) : 0;

    const value = Number.isFinite(count) ? count : 0;
    log.done(200, { count: value });
    return jsonResponse({ count: value });
  } catch (err) {
    log.error('count failed', err instanceof Error ? err.message : String(err));
    log.done(200, { count: 0 });
    return jsonResponse({ count: 0 });
  }
}
