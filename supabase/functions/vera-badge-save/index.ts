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

type SavePayload = {
  walletAddress: string;
  mintAddress: string;
  transactionSignature: string;
  assetName: string;
  category?: string;
  serialNumber?: string;
  description: string;
  metadataUri: string;
  metadataGatewayUrl?: string | null;
  photoUris?: string[];
  feeLamports: number;
  feeRecipient: string;
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
    const payload = (await req.json()) as SavePayload;

    if (
      !payload.walletAddress ||
      !payload.mintAddress ||
      !payload.transactionSignature ||
      !payload.assetName ||
      !payload.description ||
      !payload.metadataUri ||
      !payload.feeRecipient
    ) {
      return jsonResponse({ error: 'Missing required eNFT fields.' }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const normalizedWallet = payload.walletAddress.trim();

    const { data: userRow, error: userError } = await supabase
      .from('vera_users')
      .upsert({ wallet_address: normalizedWallet }, { onConflict: 'wallet_address' })
      .select('id')
      .single();

    if (userError || !userRow?.id) {
      return jsonResponse({ error: `Failed to upsert user: ${userError?.message}` }, 500);
    }

    const { error: enftError } = await supabase.from('vera_enfts').upsert(
      {
        user_id: userRow.id,
        wallet_address: normalizedWallet,
        mint_address: payload.mintAddress.trim(),
        transaction_signature: payload.transactionSignature.trim(),
        asset_name: payload.assetName.trim(),
        category: payload.category?.trim() || null,
        serial_number: payload.serialNumber?.trim() || null,
        description: payload.description.trim(),
        metadata_uri: payload.metadataUri.trim(),
        metadata_gateway_url: payload.metadataGatewayUrl?.trim() || null,
        photo_uris: payload.photoUris || [],
        fee_lamports: payload.feeLamports,
        fee_recipient: payload.feeRecipient.trim(),
        status: 'minted',
      },
      { onConflict: 'mint_address' },
    );

    if (enftError) {
      return jsonResponse({ error: `Failed to save eNFT: ${enftError.message}` }, 500);
    }

    return jsonResponse({ success: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected save error.';
    return jsonResponse({ error: message }, 500);
  }
});
