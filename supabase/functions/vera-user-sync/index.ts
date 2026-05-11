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

type SyncUserPayload = {
  privyUserId: string;
  socialProvider?: string | null;
  socialUserId?: string | null;
  email?: string | null;
  phone?: string | null;
  displayName?: string | null;
  walletAddress: string;
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

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in function secrets.' },
      500,
    );
  }

  try {
    const payload = (await req.json()) as SyncUserPayload;
    if (!payload.privyUserId || !payload.walletAddress) {
      return jsonResponse({ error: 'Missing privyUserId or walletAddress.' }, 400);
    }

    const normalizedWallet = payload.walletAddress.trim();
    const normalizedPrivyId = payload.privyUserId.trim();
    const normalizedSocialProvider = payload.socialProvider?.trim() || null;
    const normalizedSocialUserId = payload.socialUserId?.trim() || null;
    const normalizedEmail = payload.email?.trim() || null;
    const normalizedPhone = payload.phone?.trim() || null;
    const normalizedDisplayName = payload.displayName?.trim() || null;

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    let existingUserId: string | null = null;

    const { data: byPrivy, error: byPrivyError } = await supabase
      .from('vera_users')
      .select('id')
      .eq('privy_user_id', normalizedPrivyId)
      .maybeSingle();
    if (byPrivyError) {
      throw new Error(`Failed to query by privy_user_id: ${byPrivyError.message}`);
    }
    existingUserId = byPrivy?.id || null;

    if (!existingUserId && normalizedSocialProvider && normalizedSocialUserId) {
      const { data: bySocial, error: bySocialError } = await supabase
        .from('vera_users')
        .select('id')
        .eq('social_provider', normalizedSocialProvider)
        .eq('social_user_id', normalizedSocialUserId)
        .maybeSingle();
      if (bySocialError) {
        throw new Error(`Failed to query by social identity: ${bySocialError.message}`);
      }
      existingUserId = bySocial?.id || null;
    }

    if (!existingUserId) {
      const { data: byWallet, error: byWalletError } = await supabase
        .from('vera_users')
        .select('id')
        .eq('wallet_address', normalizedWallet)
        .maybeSingle();
      if (byWalletError) {
        throw new Error(`Failed to query by wallet address: ${byWalletError.message}`);
      }
      existingUserId = byWallet?.id || null;
    }

    if (existingUserId) {
      const { error: updateUserError } = await supabase
        .from('vera_users')
        .update({
          wallet_address: normalizedWallet,
          privy_user_id: normalizedPrivyId,
          social_provider: normalizedSocialProvider,
          social_user_id: normalizedSocialUserId,
          email: normalizedEmail,
          phone: normalizedPhone,
          display_name: normalizedDisplayName,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existingUserId);
      if (updateUserError) {
        throw new Error(`Failed to update user: ${updateUserError.message}`);
      }
    } else {
      const { data: insertedUser, error: insertUserError } = await supabase
        .from('vera_users')
        .insert({
          wallet_address: normalizedWallet,
          privy_user_id: normalizedPrivyId,
          social_provider: normalizedSocialProvider,
          social_user_id: normalizedSocialUserId,
          email: normalizedEmail,
          phone: normalizedPhone,
          display_name: normalizedDisplayName,
        })
        .select('id')
        .single();
      if (insertUserError || !insertedUser?.id) {
        throw new Error(`Failed to insert user: ${insertUserError?.message}`);
      }
      existingUserId = insertedUser.id;
    }

    const { error: clearPrimaryError } = await supabase
      .from('registered_devices')
      .update({ is_primary: false, updated_at: new Date().toISOString() })
      .eq('user_id', existingUserId);
    if (clearPrimaryError) {
      throw new Error(`Failed to clear previous primary devices: ${clearPrimaryError.message}`);
    }

    const { error: upsertDeviceError } = await supabase.from('registered_devices').upsert(
      {
        user_id: existingUserId,
        wallet_address: normalizedWallet,
        wallet_type: 'embedded',
        auth_provider: 'privy',
        is_primary: true,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'wallet_address' },
    );
    if (upsertDeviceError) {
      throw new Error(`Failed to upsert registered device: ${upsertDeviceError.message}`);
    }

    return jsonResponse({ success: true, userId: existingUserId, walletAddress: normalizedWallet });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected user sync error.';
    return jsonResponse({ error: message }, 500);
  }
});
