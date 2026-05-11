import {
  PRIVY_APP_ID,
  privyConfig,
  SOLANA_RPC_URL,
  SUPABASE_ANON_KEY,
  SUPABASE_URL,
} from '@components/auth/privyConfig';
import { getPrimaryEmbeddedSolanaWallet, syncPrivyUserToSupabase } from '@components/auth/userSync';
import { PrivyProvider, usePrivy } from '@privy-io/react-auth';
import {
  useSignAndSendTransaction,
  useWallets as useSolanaWallets,
} from '@privy-io/react-auth/solana';
import {
  Connection,
  LAMPORTS_PER_SOL,
  PublicKey,
  SystemProgram,
  Transaction,
} from '@solana/web3.js';
import bs58 from 'bs58';
import { useEffect, useMemo, useState } from 'react';
import { VERA_BADGE_FEE_SOL, VERA_FEE_WALLET } from './appkit';

const SUPABASE_UPLOAD_FUNCTION = 'vera-badge-upload';
const SUPABASE_CNFT_MINT_FUNCTION = 'vera-badge-mint-compressed';
const SUPABASE_SAVE_FUNCTION = 'vera-badge-save';

type BadgeForm = {
  assetName: string;
  category: string;
  serialNumber: string;
  description: string;
  photos: File[];
};

type UploadedBadgeMetadata = {
  metadataUri: string;
  metadataGatewayUrl?: string;
  photoUris?: string[];
};

type PendingMint = {
  paymentSignature: string;
  walletAddress: string;
  feeLamports: number;
  form: Omit<BadgeForm, 'photos'>;
  upload: UploadedBadgeMetadata;
};

function CreateVeraBadgeInner() {
  const { authenticated, user } = usePrivy();
  const { wallets } = useSolanaWallets();
  const { signAndSendTransaction } = useSignAndSendTransaction();
  const connection = useMemo(() => new Connection(SOLANA_RPC_URL, 'confirmed'), []);
  const embeddedWallet = useMemo(() => getPrimaryEmbeddedSolanaWallet(wallets), [wallets]);
  const walletAddress = embeddedWallet?.address || null;

  const [form, setForm] = useState<BadgeForm>({
    assetName: '',
    category: '',
    serialNumber: '',
    description: '',
    photos: [],
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<{ signature: string; assetId: string } | null>(null);
  const [pendingMint, setPendingMint] = useState<PendingMint | null>(null);

  useEffect(() => {
    if (!authenticated || !user || !walletAddress) {
      return;
    }

    void syncPrivyUserToSupabase({ user, walletAddress });
  }, [authenticated, user, walletAddress]);

  const onFieldChange = (field: keyof Omit<BadgeForm, 'photos'>, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const onFilesChange = (files: FileList | null) => {
    const nextFiles = files ? Array.from(files).slice(0, 5) : [];
    setForm((prev) => ({ ...prev, photos: nextFiles }));
  };

  const readErrorMessage = async (response: Response, fallback: string) => {
    const payload = await response
      .clone()
      .json()
      .catch(() => null);
    if (payload && typeof payload.error === 'string' && payload.error.trim()) {
      return payload.error.trim();
    }

    const rawText = await response.text().catch(() => '');
    const text = rawText.trim();
    if (text) {
      return text.slice(0, 240);
    }

    return `${fallback} (HTTP ${response.status})`;
  };

  const finalizeCompressedMint = async (params: PendingMint) => {
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
      throw new Error('Missing PUBLIC_SUPABASE_URL or PUBLIC_SUPABASE_ANON_KEY.');
    }
    const supabaseUrl = SUPABASE_URL;
    const supabaseAnonKey = SUPABASE_ANON_KEY;

    const isRetryableCompressedMintError = (value: unknown) => {
      const message = value instanceof Error ? value.message : String(value);
      return (
        /Blockhash not found/i.test(message) ||
        /block height exceeded/i.test(message) ||
        /signature .* has expired/i.test(message) ||
        /TransactionExpiredBlockheightExceededError/i.test(message) ||
        /429|rate limit/i.test(message) ||
        /timed out|timeout/i.test(message) ||
        /Could not get transaction from signature/i.test(message) ||
        /Could not parse leaf from transaction/i.test(message)
      );
    };

    let compressedMintResult: {
      signature: string;
      assetId: string;
      treeAddress: string;
    } | null = null;

    for (let attempt = 0; attempt < 4; attempt += 1) {
      const compressedMintResponse = await fetch(
        `${supabaseUrl}/functions/v1/${SUPABASE_CNFT_MINT_FUNCTION}`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${supabaseAnonKey}`,
            apikey: supabaseAnonKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            walletAddress: params.walletAddress,
            paymentSignature: params.paymentSignature,
            assetName: params.form.assetName.trim(),
            category: params.form.category.trim(),
            serialNumber: params.form.serialNumber.trim(),
            description: params.form.description.trim(),
            metadataUri: params.upload.metadataUri,
          }),
        },
      );

      if (compressedMintResponse.ok) {
        compressedMintResult = (await compressedMintResponse.json()) as {
          signature: string;
          assetId: string;
          treeAddress: string;
        };
        break;
      }

      const compressedMintMessage = await readErrorMessage(
        compressedMintResponse,
        'Compressed NFT mint failed.',
      );

      if (!isRetryableCompressedMintError(compressedMintMessage) || attempt === 3) {
        throw new Error(compressedMintMessage);
      }

      await new Promise((resolve) => setTimeout(resolve, 500 * 2 ** attempt));
    }

    if (!compressedMintResult) {
      throw new Error('Compressed NFT mint failed.');
    }

    const saveResponse = await fetch(`${supabaseUrl}/functions/v1/${SUPABASE_SAVE_FUNCTION}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${supabaseAnonKey}`,
        apikey: supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        walletAddress: params.walletAddress,
        mintAddress: compressedMintResult.assetId,
        transactionSignature: compressedMintResult.signature,
        assetName: params.form.assetName.trim(),
        category: params.form.category.trim(),
        serialNumber: params.form.serialNumber.trim(),
        description: params.form.description.trim(),
        metadataUri: params.upload.metadataUri,
        metadataGatewayUrl: params.upload.metadataGatewayUrl || null,
        photoUris: params.upload.photoUris || [],
        feeLamports: params.feeLamports,
        feeRecipient: VERA_FEE_WALLET,
      }),
    });

    if (!saveResponse.ok) {
      const saveMessage = await readErrorMessage(
        saveResponse,
        'Mint succeeded, but saving eNFT record failed.',
      );
      setError(saveMessage);
    }

    setSuccess({
      signature: compressedMintResult.signature,
      assetId: compressedMintResult.assetId,
    });
    setPendingMint(null);
  };

  const retryPendingMint = async () => {
    if (!pendingMint) {
      return;
    }

    try {
      setError(null);
      setSuccess(null);
      setIsSubmitting(true);
      await finalizeCompressedMint(pendingMint);
    } catch (retryError) {
      const message =
        retryError instanceof Error
          ? retryError.message
          : 'Retrying mint without extra fee failed.';
      setError(message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const submitBadge = async () => {
    try {
      setError(null);
      setSuccess(null);
      setIsSubmitting(true);

      if (!authenticated || !user) {
        throw new Error('Sign in first to continue.');
      }
      if (!embeddedWallet || !walletAddress) {
        throw new Error('Embedded Solana wallet is not ready yet.');
      }
      if (!form.assetName.trim()) {
        throw new Error('Asset name is required.');
      }
      if (!form.description.trim()) {
        throw new Error('Asset description is required.');
      }
      if (form.photos.length === 0) {
        throw new Error('Add at least one photo.');
      }

      const uploadForm = new FormData();
      uploadForm.append('assetName', form.assetName.trim());
      uploadForm.append('category', form.category.trim());
      uploadForm.append('serialNumber', form.serialNumber.trim());
      uploadForm.append('description', form.description.trim());
      for (const photo of form.photos) {
        uploadForm.append('photos', photo, photo.name);
      }

      if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
        throw new Error('Missing PUBLIC_SUPABASE_URL or PUBLIC_SUPABASE_ANON_KEY.');
      }
      const supabaseUrl = SUPABASE_URL;
      const supabaseAnonKey = SUPABASE_ANON_KEY;

      const uploadResponse = await fetch(
        `${supabaseUrl}/functions/v1/${SUPABASE_UPLOAD_FUNCTION}`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${supabaseAnonKey}`,
            apikey: supabaseAnonKey,
          },
          body: uploadForm,
        },
      );

      if (!uploadResponse.ok) {
        const uploadMessage = await readErrorMessage(
          uploadResponse,
          'Failed to upload badge metadata.',
        );
        throw new Error(uploadMessage);
      }

      const uploadResult = (await uploadResponse.json()) as UploadedBadgeMetadata;

      const owner = new PublicKey(walletAddress);
      const feeWallet = new PublicKey(VERA_FEE_WALLET);
      const feeLamports = Math.round(VERA_BADGE_FEE_SOL * LAMPORTS_PER_SOL);

      const buildFeeTransaction = (blockhash: string) => {
        const tx = new Transaction().add(
          SystemProgram.transfer({
            fromPubkey: owner,
            toPubkey: feeWallet,
            lamports: feeLamports,
          }),
        );
        tx.feePayer = owner;
        tx.recentBlockhash = blockhash;
        return tx;
      };

      const latestBlockhash = await connection.getLatestBlockhash('processed');
      const feeTransaction = buildFeeTransaction(latestBlockhash.blockhash);
      const feeTransactionBytes = feeTransaction.serialize({
        requireAllSignatures: false,
        verifySignatures: false,
      });
      const { signature: feeSignatureBytes } = await signAndSendTransaction({
        transaction: feeTransactionBytes,
        wallet: embeddedWallet,
        chain: 'solana:mainnet',
      });
      const feeSignature = bs58.encode(feeSignatureBytes);

      try {
        await connection.confirmTransaction(
          {
            signature: feeSignature,
            blockhash: latestBlockhash.blockhash,
            lastValidBlockHeight: latestBlockhash.lastValidBlockHeight,
          },
          'confirmed',
        );
      } catch (confirmError) {
        const status = await connection.getSignatureStatuses([feeSignature]);
        const currentStatus = status.value[0];
        if (!currentStatus || currentStatus.err) {
          throw confirmError;
        }
      }

      const pending: PendingMint = {
        paymentSignature: feeSignature,
        walletAddress,
        feeLamports,
        form: {
          assetName: form.assetName,
          category: form.category,
          serialNumber: form.serialNumber,
          description: form.description,
        },
        upload: uploadResult,
      };

      setPendingMint(pending);
      await finalizeCompressedMint(pending);
      setForm({
        assetName: '',
        category: '',
        serialNumber: '',
        description: '',
        photos: [],
      });
    } catch (submitError) {
      const message = submitError instanceof Error ? submitError.message : 'Badge creation failed.';
      setError(message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <section
      className="mx-auto mt-8 w-full max-w-6xl rounded-2xl border p-6"
      style={{ borderColor: 'var(--surface-border)', backgroundColor: 'var(--surface-elevated)' }}
    >
      <div className="flex flex-col gap-2">
        <h2 className="matrix-heading text-2xl font-semibold md:text-3xl">Create Vera Badge</h2>
        <p className="matrix-text text-sm" style={{ color: 'var(--text-muted)' }}>
          Upload your physical asset details + photos, mint your passport-grade compressed Vera
          badge, and pay {VERA_BADGE_FEE_SOL} SOL mint fee using your embedded wallet.
        </p>
      </div>

      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <input
          type="text"
          value={form.assetName}
          onChange={(event) => onFieldChange('assetName', event.target.value)}
          placeholder="Asset name (required)"
          className="rounded-xl border px-4 py-3 text-sm"
          style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
        />
        <input
          type="text"
          value={form.category}
          onChange={(event) => onFieldChange('category', event.target.value)}
          placeholder="Category (watch, bag, sneaker...)"
          className="rounded-xl border px-4 py-3 text-sm"
          style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
        />
        <input
          type="text"
          value={form.serialNumber}
          onChange={(event) => onFieldChange('serialNumber', event.target.value)}
          placeholder="Serial / reference number"
          className="rounded-xl border px-4 py-3 text-sm"
          style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
        />
        <input
          type="file"
          accept="image/*"
          multiple
          onChange={(event) => onFilesChange(event.target.files)}
          className="rounded-xl border px-4 py-3 text-sm"
          style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
        />
      </div>

      <textarea
        value={form.description}
        onChange={(event) => onFieldChange('description', event.target.value)}
        placeholder="Describe asset condition, provenance, and key details (required)"
        className="mt-4 min-h-28 w-full rounded-xl border px-4 py-3 text-sm"
        style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
      />

      <div className="mt-5 flex flex-wrap items-center gap-3">
        <button
          type="button"
          className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
          style={{ borderColor: 'var(--surface-border)' }}
          disabled={!authenticated || !walletAddress || isSubmitting}
          onClick={submitBadge}
        >
          {isSubmitting ? 'Minting...' : 'Mint Passport'}
        </button>
        <span className="matrix-text text-xs" style={{ color: 'var(--text-muted)' }}>
          Fee recipient: {VERA_FEE_WALLET}
        </span>
      </div>

      {(!authenticated || !walletAddress) && (
        <p className="mt-3 text-sm" style={{ color: 'var(--text-muted)' }}>
          Sign in with Email, Phone, Google, Apple, or Facebook to mint with your embedded Solana
          wallet.
        </p>
      )}

      {error && (
        <p className="mt-3 text-sm" style={{ color: '#ffb5a8' }}>
          {error}
        </p>
      )}

      {pendingMint && (
        <button
          type="button"
          className="matrix-text mt-3 inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
          style={{ borderColor: 'var(--surface-border)' }}
          disabled={isSubmitting}
          onClick={retryPendingMint}
        >
          Retry cNFT mint (no extra fee)
        </button>
      )}

      {success && (
        <div className="mt-3 flex flex-col gap-1 text-sm">
          <a
            className="text-[#ffb5a8] underline"
            href={`https://solscan.io/tx/${success.signature}`}
            target="_blank"
            rel="noreferrer"
          >
            View cNFT mint transaction
          </a>
          <p style={{ color: 'var(--text-muted)' }}>Compressed asset ID: {success.assetId}</p>
        </div>
      )}
    </section>
  );
}

export function CreateVeraBadge() {
  if (!PRIVY_APP_ID) {
    return (
      <section
        className="mx-auto mt-8 w-full max-w-6xl rounded-2xl border p-6"
        style={{ borderColor: 'var(--surface-border)', backgroundColor: 'var(--surface-elevated)' }}
      >
        <p className="matrix-text text-sm" style={{ color: 'var(--text-muted)' }}>
          Authentication is unavailable. Set PUBLIC_PRIVY_APP_ID to enable secure onboarding.
        </p>
      </section>
    );
  }

  return (
    <PrivyProvider appId={PRIVY_APP_ID} config={privyConfig}>
      <CreateVeraBadgeInner />
    </PrivyProvider>
  );
}
