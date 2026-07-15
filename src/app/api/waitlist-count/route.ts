import { getActiveBrand } from '@config/brands';

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=30',
    },
  });

export async function GET() {
  const brand = getActiveBrand();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceRoleKey || serviceRoleKey === 'your_service_role_key') {
    return jsonResponse({ count: 0 });
  }

  try {
    // HEAD request with count=exact returns the total in the Content-Range
    // header without transferring any rows.
    const res = await fetch(
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

    return jsonResponse({ count: Number.isFinite(count) ? count : 0 });
  } catch {
    return jsonResponse({ count: 0 });
  }
}
