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

const normalizeEmail = (email: string) => email.trim().toLowerCase();

const isValidEmail = (email: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

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
    return jsonResponse(
      { error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in function secrets.' },
      500,
    );
  }

  try {
    const payload = (await req.json()) as {
      email?: string;
      brand?: string | null;
      source?: string | null;
    };

    const rawEmail = payload.email?.trim();
    if (!rawEmail || !isValidEmail(rawEmail)) {
      return jsonResponse({ error: 'A valid email is required.' }, 400);
    }

    const email = normalizeEmail(rawEmail);
    const brand = payload.brand?.trim() || 'default';
    const source = payload.source?.trim() || 'website';

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { error } = await supabase.from('newsletter_subscribers').upsert(
      {
        email,
        brand,
        source,
        status: 'subscribed',
        updated_at: new Date().toISOString(),
      },
      {
        onConflict: 'email',
      },
    );

    if (error) {
      throw new Error(`Failed to save subscriber: ${error.message}`);
    }

    return jsonResponse({ success: true, message: "You're on the list." });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected subscription error.';
    return jsonResponse({ error: message }, 500);
  }
});
