import {
  mplBubblegum,
  createTree,
  mintV1,
  parseLeafFromMintV1Transaction,
  safeFetchTreeConfigFromSeeds,
} from 'npm:@metaplex-foundation/mpl-bubblegum@5.0.2';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';
import {
  createSignerFromKeypair,
  keypairIdentity,
  publicKey,
} from 'npm:@metaplex-foundation/umi@0.9.2';
import { createUmi } from 'npm:@metaplex-foundation/umi-bundle-defaults@0.9.2';
import { toWeb3JsPublicKey } from 'npm:@metaplex-foundation/umi-web3js-adapters@0.9.2';
import { Connection } from 'npm:@solana/web3.js@1.98.4';
import bs58 from 'npm:bs58@6.0.0';

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

type MintCompressedPayload = {
  walletAddress: string;
  paymentSignature: string;
  assetName: string;
  category?: string;
  serialNumber?: string;
  description: string;
  metadataUri: string;
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const isRetryableMintError = (value: unknown) => {
  const message = value instanceof Error ? value.message : String(value);
  return (
    /Blockhash not found/i.test(message) ||
    /block height exceeded/i.test(message) ||
    /signature .* has expired/i.test(message) ||
    /TransactionExpiredBlockheightExceededError/i.test(message) ||
    /Node is behind/i.test(message) ||
    /429|rate limit/i.test(message) ||
    /timed out|timeout/i.test(message) ||
    /Could not get transaction from signature/i.test(message) ||
    /Could not parse leaf from transaction/i.test(message)
  );
};

const withRetry = async <T>(operation: () => Promise<T>, maxAttempts = 4) => {
  let lastError: unknown;
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      if (!isRetryableMintError(error) || attempt === maxAttempts - 1) {
        throw error;
      }

      await sleep(500 * 2 ** attempt);
    }
  }

  throw lastError;
};

const buildUniqueCnftName = (assetName: string, paymentSignature: string) => {
  const rawSuffix = paymentSignature.replace(/[^1-9A-HJ-NP-Za-km-z]/g, '').slice(0, 6);
  const suffix = rawSuffix || crypto.randomUUID().replace(/-/g, '').slice(0, 6);
  const baseName = `${assetName} • Vera Badge`.trim();
  const reserved = suffix.length + 2;
  const maxBaseLength = Math.max(1, 32 - reserved);
  const clippedBase = baseName.slice(0, maxBaseLength).trim();
  return `${clippedBase} #${suffix}`.slice(0, 32);
};

const parseSecretKey = (value: string) => {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new Error('Empty secret key.');
  }

  if (trimmed.startsWith('[')) {
    const parsed = JSON.parse(trimmed);
    if (!Array.isArray(parsed)) {
      throw new Error('Secret key JSON must be an array.');
    }
    return Uint8Array.from(parsed);
  }

  return Uint8Array.from(bs58.decode(trimmed));
};

const wasPaymentMade = async (params: {
  connection: Connection;
  signature: string;
  walletAddress: string;
  feeRecipient: string;
  minimumLamports: number;
}) => {
  const tx = await params.connection.getParsedTransaction(params.signature, {
    commitment: 'confirmed',
    maxSupportedTransactionVersion: 0,
  });
  if (!tx) {
    throw new Error('Fee payment transaction not found.');
  }

  const feePayer = tx.transaction.message.accountKeys.find((key) => key.signer)?.pubkey.toBase58();
  if (!feePayer || feePayer !== params.walletAddress) {
    throw new Error('Fee transaction signer does not match wallet address.');
  }

  const hasTransfer = tx.transaction.message.instructions.some((instruction) => {
    if (!('parsed' in instruction) || instruction.program !== 'system') {
      return false;
    }

    const parsed = instruction.parsed as
      | { type?: string; info?: { source?: string; destination?: string; lamports?: number } }
      | undefined;
    if (!parsed || parsed.type !== 'transfer' || !parsed.info) {
      return false;
    }

    return (
      parsed.info.source === params.walletAddress &&
      parsed.info.destination === params.feeRecipient &&
      Number(parsed.info.lamports || 0) >= params.minimumLamports
    );
  });

  if (!hasTransfer) {
    throw new Error('Fee transfer to recipient was not found in payment transaction.');
  }
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  const rpcUrl = Deno.env.get('VERA_SOLANA_RPC_URL');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const mintAuthoritySecret = Deno.env.get('VERA_CNFT_MINT_AUTHORITY_SECRET');
  const treeAddressValue = Deno.env.get('VERA_CNFT_TREE_ADDRESS');
  const treeSecretValue = Deno.env.get('VERA_CNFT_TREE_SECRET');
  const feeRecipient = Deno.env.get('VERA_FEE_WALLET') || 'CK1gBf6XyJaeZq1aS2gHsmrohA4gMDmPDBBu9hCBswnS';
  const feeSol = Number(Deno.env.get('VERA_BADGE_FEE_SOL') || '0.001');
  const maxDepth = Number(Deno.env.get('VERA_CNFT_MAX_DEPTH') || '14');
  const maxBufferSize = Number(Deno.env.get('VERA_CNFT_MAX_BUFFER_SIZE') || '64');

  if (!rpcUrl || !mintAuthoritySecret || !supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      {
        error:
          'Missing VERA_SOLANA_RPC_URL, VERA_CNFT_MINT_AUTHORITY_SECRET, SUPABASE_URL, or SUPABASE_SERVICE_ROLE_KEY.',
      },
      500,
    );
  }

  let paymentSignatureForError: string | null = null;
  try {
    const payload = (await req.json()) as MintCompressedPayload;
    if (
      !payload.walletAddress ||
      !payload.paymentSignature ||
      !payload.assetName ||
      !payload.description ||
      !payload.metadataUri
    ) {
      return jsonResponse({ error: 'Missing required compressed mint fields.' }, 400);
    }

    const walletAddress = payload.walletAddress.trim();
    const paymentSignature = payload.paymentSignature.trim();
    paymentSignatureForError = paymentSignature;
    const metadataUri = payload.metadataUri.trim();
    const normalizedName = buildUniqueCnftName(payload.assetName.trim(), payload.paymentSignature);
    const normalizedSymbol = 'VERA'.slice(0, 10);
    const feeLamports = Math.round(feeSol * 1_000_000_000);

    await wasPaymentMade({
      connection: new Connection(rpcUrl, 'confirmed'),
      signature: paymentSignature,
      walletAddress,
      feeRecipient,
      minimumLamports: feeLamports,
    });

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });
    const { data: existingPayment, error: existingPaymentError } = await supabase
      .from('vera_mint_payments')
      .select('status, asset_id, mint_signature, tree_address')
      .eq('payment_signature', paymentSignature)
      .maybeSingle();

    if (existingPaymentError) {
      throw new Error(`Failed to read payment record: ${existingPaymentError.message}`);
    }

    if (
      existingPayment &&
      existingPayment.status === 'minted' &&
      existingPayment.asset_id &&
      existingPayment.mint_signature
    ) {
      return jsonResponse({
        signature: existingPayment.mint_signature,
        assetId: existingPayment.asset_id,
        treeAddress: existingPayment.tree_address || treeAddressValue?.trim() || null,
      });
    }

    const { error: markProcessingError } = await supabase.from('vera_mint_payments').upsert(
      {
        payment_signature: paymentSignature,
        wallet_address: walletAddress,
        metadata_uri: metadataUri,
        status: 'processing',
        last_error: null,
      },
      { onConflict: 'payment_signature' },
    );

    if (markProcessingError) {
      throw new Error(`Failed to mark payment as processing: ${markProcessingError.message}`);
    }

    const umi = createUmi(rpcUrl).use(mplBubblegum());
    const mintAuthorityKeypair = umi.eddsa.createKeypairFromSecretKey(
      parseSecretKey(mintAuthoritySecret),
    );
    umi.use(keypairIdentity(mintAuthorityKeypair));
    const mintAuthoritySigner = createSignerFromKeypair(umi, mintAuthorityKeypair);

    const treeSigner = treeSecretValue
      ? createSignerFromKeypair(umi, umi.eddsa.createKeypairFromSecretKey(parseSecretKey(treeSecretValue)))
      : null;
    const treePublicKey = treeAddressValue?.trim()
      ? publicKey(treeAddressValue.trim())
      : treeSigner?.publicKey;

    if (!treePublicKey) {
      throw new Error('Set VERA_CNFT_TREE_ADDRESS or VERA_CNFT_TREE_SECRET.');
    }

    if (
      treeSigner &&
      toWeb3JsPublicKey(treePublicKey).toBase58() !==
        toWeb3JsPublicKey(treeSigner.publicKey).toBase58()
    ) {
      throw new Error('VERA_CNFT_TREE_ADDRESS does not match VERA_CNFT_TREE_SECRET.');
    }

    const treeConfig = await safeFetchTreeConfigFromSeeds(umi, {
      merkleTree: publicKey(treePublicKey),
    });
    if (!treeConfig) {
      if (!treeSigner) {
        throw new Error('Merkle tree is not initialized. Set VERA_CNFT_TREE_SECRET to auto-create it.');
      }

      await withRetry(async () => {
        const createTreeBuilder = await createTree(umi, {
          merkleTree: treeSigner,
          maxDepth,
          maxBufferSize,
          public: true,
        });
        await createTreeBuilder.sendAndConfirm(umi, {
          confirm: { commitment: 'confirmed' },
        });
      });
    }

    const mintBuilder = mintV1(umi, {
      leafOwner: publicKey(walletAddress),
      leafDelegate: publicKey(walletAddress),
      merkleTree: publicKey(treePublicKey),
      treeCreatorOrDelegate: mintAuthoritySigner,
      metadata: {
        name: normalizedName,
        symbol: normalizedSymbol,
        uri: metadataUri,
        sellerFeeBasisPoints: 0,
        creators: [
          {
            address: publicKey(walletAddress),
            verified: false,
            share: 100,
          },
        ],
        collection: null,
        uses: null,
      },
    });

    const { signature } = await withRetry(() =>
      mintBuilder.sendAndConfirm(umi, {
        confirm: { commitment: 'confirmed' },
      }),
    );
    const leaf = await withRetry(() => parseLeafFromMintV1Transaction(umi, signature));
    const assetId = toWeb3JsPublicKey(leaf.id).toBase58();
    const treeAddress = toWeb3JsPublicKey(treePublicKey).toBase58();

    const { error: markMintedError } = await supabase
      .from('vera_mint_payments')
      .update({
        status: 'minted',
        mint_signature: signature,
        asset_id: assetId,
        tree_address: treeAddress,
        last_error: null,
      })
      .eq('payment_signature', paymentSignature);

    if (markMintedError) {
      throw new Error(`Failed to store minted payment record: ${markMintedError.message}`);
    }

    return jsonResponse({
      signature,
      assetId,
      treeAddress,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected compressed mint error.';
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL');
      const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
      if (supabaseUrl && serviceRoleKey) {
        const supabase = createClient(supabaseUrl, serviceRoleKey, {
          auth: { persistSession: false },
        });
        if (paymentSignatureForError) {
          await supabase
            .from('vera_mint_payments')
            .update({ status: 'failed', last_error: message })
            .eq('payment_signature', paymentSignatureForError);
        }
      }
    } catch {
      // Preserve original mint error.
    }
    return jsonResponse({ error: message }, 500);
  }
});
