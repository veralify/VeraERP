// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });

const isValidEmail = (email: string) =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim().toLowerCase());

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.' }, 500);
  }

  try {
    const payload = (await req.json()) as {
      fullName?: string;
      email?: string;
      company?: string;
      message?: string;
      brand?: string;
      source?: string;
    };

    const email = payload.email?.trim().toLowerCase() || '';
    if (!isValidEmail(email)) {
      return jsonResponse({ error: 'A valid email is required.' }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { error } = await supabase.from('website_signups').upsert(
      {
        brand: payload.brand?.trim() || 'default',
        full_name: payload.fullName?.trim() || null,
        email,
        company: payload.company?.trim() || null,
        message: payload.message?.trim() || null,
        source: payload.source?.trim() || 'website-signup',
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'email,brand' },
    );

    if (error) {
      throw new Error(`Failed to save signup: ${error.message}`);
    }

    return jsonResponse({ success: true, message: "Thanks. We'll be in touch shortly." });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected signup error.';
    return jsonResponse({ error: message }, 500);
  }
});
