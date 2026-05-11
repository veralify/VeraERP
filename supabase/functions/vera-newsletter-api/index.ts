// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });

const getApiKey = (req: Request) => {
  const bearer = req.headers.get('authorization');
  if (bearer?.startsWith('Bearer ')) {
    return bearer.replace('Bearer ', '').trim();
  }
  return req.headers.get('x-api-key')?.trim() || '';
};

const normalizeEmail = (email: string) => email.trim().toLowerCase();

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const adminApiKey = Deno.env.get('VERA_ADMIN_API_KEY');

  if (!supabaseUrl || !serviceRoleKey || !adminApiKey) {
    return jsonResponse(
      { error: 'Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or VERA_ADMIN_API_KEY.' },
      500,
    );
  }

  if (getApiKey(req) !== adminApiKey) {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  try {
    const payload = (await req.json()) as {
      action?: 'list_subscribers' | 'update_subscriber_status' | 'delete_subscriber' | 'stats';
      email?: string;
      status?: 'subscribed' | 'unsubscribed';
      brand?: string;
      query?: string;
      limit?: number;
      offset?: number;
    };

    const action = payload.action;
    if (!action) {
      return jsonResponse({ error: 'Missing action.' }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    if (action === 'list_subscribers') {
      const limit = Math.min(Math.max(payload.limit || 50, 1), 200);
      const offset = Math.max(payload.offset || 0, 0);
      const query = payload.query?.trim() || '';
      const brand = payload.brand?.trim() || '';
      const status = payload.status;

      let request = supabase
        .from('newsletter_subscribers')
        .select('id, email, brand, source, status, created_at, updated_at', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (brand) {
        request = request.eq('brand', brand);
      }
      if (status === 'subscribed' || status === 'unsubscribed') {
        request = request.eq('status', status);
      }
      if (query) {
        request = request.ilike('email', `%${query}%`);
      }

      const { data, count, error } = await request;
      if (error) {
        throw new Error(`Failed to list subscribers: ${error.message}`);
      }

      return jsonResponse({
        success: true,
        data: data || [],
        pagination: { limit, offset, count: count || 0 },
      });
    }

    if (action === 'update_subscriber_status') {
      const rawEmail = payload.email?.trim();
      if (!rawEmail) {
        return jsonResponse({ error: 'Missing email.' }, 400);
      }
      if (payload.status !== 'subscribed' && payload.status !== 'unsubscribed') {
        return jsonResponse({ error: 'Status must be subscribed or unsubscribed.' }, 400);
      }

      const email = normalizeEmail(rawEmail);
      const { data, error } = await supabase
        .from('newsletter_subscribers')
        .update({
          status: payload.status,
          updated_at: new Date().toISOString(),
        })
        .eq('email', email)
        .select('id, email, status, updated_at')
        .maybeSingle();

      if (error) {
        throw new Error(`Failed to update subscriber: ${error.message}`);
      }
      if (!data) {
        return jsonResponse({ error: 'Subscriber not found.' }, 404);
      }

      return jsonResponse({ success: true, data });
    }

    if (action === 'delete_subscriber') {
      const rawEmail = payload.email?.trim();
      if (!rawEmail) {
        return jsonResponse({ error: 'Missing email.' }, 400);
      }

      const email = normalizeEmail(rawEmail);
      const { data, error } = await supabase
        .from('newsletter_subscribers')
        .delete()
        .eq('email', email)
        .select('id, email');

      if (error) {
        throw new Error(`Failed to delete subscriber: ${error.message}`);
      }
      if (!data?.length) {
        return jsonResponse({ error: 'Subscriber not found.' }, 404);
      }

      return jsonResponse({ success: true, data: data[0] });
    }

    if (action === 'stats') {
      const { count: totalCount, error: totalError } = await supabase
        .from('newsletter_subscribers')
        .select('id', { count: 'exact', head: true });
      if (totalError) {
        throw new Error(`Failed to fetch total subscribers: ${totalError.message}`);
      }

      const { count: subscribedCount, error: subscribedError } = await supabase
        .from('newsletter_subscribers')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'subscribed');
      if (subscribedError) {
        throw new Error(`Failed to fetch subscribed count: ${subscribedError.message}`);
      }

      return jsonResponse({
        success: true,
        data: {
          total: totalCount || 0,
          subscribed: subscribedCount || 0,
          unsubscribed: Math.max((totalCount || 0) - (subscribedCount || 0), 0),
        },
      });
    }

    return jsonResponse({ error: 'Unsupported action.' }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected newsletter API error.';
    return jsonResponse({ error: message }, 500);
  }
});
