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
      action?: 'list_users' | 'get_user' | 'update_user_role';
      userId?: string;
      role?: 'user' | 'admin';
      limit?: number;
      offset?: number;
      query?: string;
    };

    const action = payload.action;
    if (!action) {
      return jsonResponse({ error: 'Missing action.' }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    if (action === 'list_users') {
      const limit = Math.min(Math.max(payload.limit || 50, 1), 200);
      const offset = Math.max(payload.offset || 0, 0);
      const query = payload.query?.trim() || '';

      let request = supabase
        .from('vera_users')
        .select(
          'id, account_identifier, display_name, email, phone, social_provider, role, created_at, updated_at',
          { count: 'exact' },
        )
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (query) {
        request = request.or(
          `display_name.ilike.%${query}%,email.ilike.%${query}%,account_identifier.ilike.%${query}%`,
        );
      }

      const { data, count, error } = await request;
      if (error) {
        throw new Error(`Failed to list users: ${error.message}`);
      }

      return jsonResponse({
        success: true,
        data: data || [],
        pagination: { limit, offset, count: count || 0 },
      });
    }

    if (action === 'get_user') {
      if (!payload.userId?.trim()) {
        return jsonResponse({ error: 'Missing userId.' }, 400);
      }

      const { data, error } = await supabase
        .from('vera_users')
        .select(
          'id, account_identifier, privy_user_id, display_name, email, phone, social_provider, social_user_id, role, created_at, updated_at',
        )
        .eq('id', payload.userId.trim())
        .maybeSingle();

      if (error) {
        throw new Error(`Failed to fetch user: ${error.message}`);
      }
      if (!data) {
        return jsonResponse({ error: 'User not found.' }, 404);
      }

      return jsonResponse({ success: true, data });
    }

    if (action === 'update_user_role') {
      if (!payload.userId?.trim()) {
        return jsonResponse({ error: 'Missing userId.' }, 400);
      }
      if (payload.role !== 'user' && payload.role !== 'admin') {
        return jsonResponse({ error: 'Role must be user or admin.' }, 400);
      }

      const { data, error } = await supabase
        .from('vera_users')
        .update({
          role: payload.role,
          updated_at: new Date().toISOString(),
        })
        .eq('id', payload.userId.trim())
        .select('id, role, updated_at')
        .maybeSingle();

      if (error) {
        throw new Error(`Failed to update role: ${error.message}`);
      }
      if (!data) {
        return jsonResponse({ error: 'User not found.' }, 404);
      }

      return jsonResponse({ success: true, data });
    }

    return jsonResponse({ error: 'Unsupported action.' }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected users API error.';
    return jsonResponse({ error: message }, 500);
  }
});
