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

type CreateUserPayload = {
  email: string;
  displayName?: string;
  socialProvider?: string;
  embeddedWalletAddress?: string;
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

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.' },
      500,
    );
  }

  const authHeader = req.headers.get('authorization') || '';
  const apiKeyHeader = req.headers.get('x-api-key') || '';
  const providedKey = authHeader.replace('Bearer ', '') || apiKeyHeader;

  if (!adminApiKey || providedKey !== adminApiKey) {
    return jsonResponse(
      { error: 'Unauthorized. Provide valid VERA_ADMIN_API_KEY.' },
      401,
    );
  }

  try {
    const payload = (await req.json()) as CreateUserPayload;

    if (!payload.email?.trim()) {
      return jsonResponse({ error: 'Email is required.' }, 400);
    }

    const normalizedEmail = payload.email.trim();
    const normalizedDisplayName = payload.displayName?.trim() || normalizedEmail.split('@')[0];
    const normalizedSocialProvider = payload.socialProvider?.trim() || 'test';
    const privyUserId = `test_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
    const accountIdentifier = `acct:${privyUserId}`;
    const embeddedWalletAddress = payload.embeddedWalletAddress?.trim() || null;

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { data, error } = await supabase
      .from('vera_users')
      .insert({
        account_identifier: accountIdentifier,
        privy_user_id: privyUserId,
        social_provider: normalizedSocialProvider,
        social_user_id: `${normalizedSocialProvider}_${Date.now()}`,
        email: normalizedEmail,
        display_name: normalizedDisplayName,
        embedded_wallet_address: embeddedWalletAddress,
      })
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to create user: ${error.message}`);
    }

    return jsonResponse({
      success: true,
      data: {
        id: data.id,
        privyUserId: data.privy_user_id,
        email: data.email,
        displayName: data.display_name,
        embeddedWalletAddress: data.embedded_wallet_address,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected error.';
    return jsonResponse({ error: message }, 500);
  }
});
