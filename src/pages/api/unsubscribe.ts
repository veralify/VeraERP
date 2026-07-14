import type { APIRoute } from 'astro';

export const prerender = false;

const page = (title: string, message: string) =>
  new Response(
    `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title></head><body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:#0d0d0d;color:#fff;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0"><div style="max-width:420px;padding:40px;text-align:center"><h1 style="font-size:22px;margin:0 0 12px">${title}</h1><p style="color:#b3b3b3;font-size:15px;line-height:24px;margin:0 0 24px">${message}</p><a href="/" style="color:#E84125;text-decoration:none;font-weight:600">← Back to Veralify</a></div></body></html>`,
    { status: 200, headers: { 'Content-Type': 'text/html' } },
  );

const unsubscribe = async (token: string | null) => {
  const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
  const serviceRoleKey = import.meta.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!token) return false;
  if (!supabaseUrl || !serviceRoleKey || serviceRoleKey === 'your_service_role_key') {
    return false;
  }

  const res = await fetch(
    `${supabaseUrl}/rest/v1/newsletter_subscribers?unsubscribe_token=eq.${encodeURIComponent(token)}`,
    {
      method: 'PATCH',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
        Prefer: 'return=minimal',
      },
      body: JSON.stringify({
        status: 'unsubscribed',
        updated_at: new Date().toISOString(),
      }),
    },
  );

  return res.ok;
};

// Gmail / Apple Mail one-click unsubscribe (RFC 8058).
export const POST: APIRoute = async ({ url }) => {
  const ok = await unsubscribe(url.searchParams.get('token'));
  return new Response(null, { status: ok ? 200 : 400 });
};

// Human clicking the "Unsubscribe" link in the email.
export const GET: APIRoute = async ({ url }) => {
  const ok = await unsubscribe(url.searchParams.get('token'));
  return ok
    ? page("You're unsubscribed", "You won't receive any more emails from the Veralify waitlist. Sorry to see you go!")
    : page('Something went wrong', "We couldn't process that request. The link may have expired.");
};
