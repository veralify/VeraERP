import { useAppKitAccount, useAppKitProvider } from '@reown/appkit/react';
import {
  type Provider as SolanaProvider,
  useAppKitConnection,
} from '@reown/appkit-adapter-solana/react';
import {
  ASSOCIATED_TOKEN_PROGRAM_ID,
  createAssociatedTokenAccountInstruction,
  createInitializeMintInstruction,
  createMintToInstruction,
  getAssociatedTokenAddress,
  getMinimumBalanceForRentExemptMint,
  MINT_SIZE,
  TOKEN_PROGRAM_ID,
} from '@solana/spl-token';
import {
  createCreateMetadataAccountV3Instruction,
  PROGRAM_ID as TOKEN_METADATA_PROGRAM_ID,
} from '@metaplex-foundation/mpl-token-metadata';
import {
  Keypair,
  LAMPORTS_PER_SOL,
  PublicKey,
  SystemProgram,
  Transaction,
} from '@solana/web3.js';
import { useState } from 'react';
import { ensureAppKitInitialized, VERA_BADGE_FEE_SOL, VERA_FEE_WALLET } from './appkit';

ensureAppKitInitialized();

const SUPABASE_URL = import.meta.env.PUBLIC_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;
const SUPABASE_UPLOAD_FUNCTION = 'vera-badge-upload';
const SUPABASE_SAVE_FUNCTION = 'vera-badge-save';

type BadgeForm = {
  assetName: string;
  category: string;
  serialNumber: string;
  description: string;
  photos: File[];
};

export function CreateVeraBadge() {
  const { address, isConnected } = useAppKitAccount({ namespace: 'solana' });
  const { connection } = useAppKitConnection();
  const { walletProvider } = useAppKitProvider<SolanaProvider | undefined>('solana');

  const [form, setForm] = useState<BadgeForm>({
    assetName: '',
    category: '',
    serialNumber: '',
    description: '',
    photos: [],
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<{ signature: string; mintAddress: string } | null>(null);

  const onFieldChange = (field: keyof Omit<BadgeForm, 'photos'>, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const onFilesChange = (files: FileList | null) => {
    const nextFiles = files ? Array.from(files).slice(0, 5) : [];
    setForm((prev) => ({ ...prev, photos: nextFiles }));
  };

  const submitBadge = async () => {
    try {
      setError(null);
      setSuccess(null);
      setIsSubmitting(true);

      if (!isConnected || !address) {
        throw new Error('Connect your wallet first.');
      }
      if (!connection) {
        throw new Error('Solana network connection is not ready.');
      }
      if (!walletProvider) {
        throw new Error('Wallet provider is not available.');
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

      const uploadResponse = await fetch(
        `${SUPABASE_URL}/functions/v1/${SUPABASE_UPLOAD_FUNCTION}`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
            apikey: SUPABASE_ANON_KEY,
          },
          body: uploadForm,
        },
      );

      if (!uploadResponse.ok) {
        const uploadError = await uploadResponse.json().catch(() => null);
        const uploadMessage =
          uploadError && typeof uploadError.error === 'string'
            ? uploadError.error
            : 'Failed to upload badge metadata.';
        throw new Error(uploadMessage);
      }

      const uploadResult = (await uploadResponse.json()) as {
        metadataUri: string;
        metadataGatewayUrl?: string;
        photoUris?: string[];
      };

      const user = new PublicKey(address);
      const mint = Keypair.generate();
      const feeWallet = new PublicKey(VERA_FEE_WALLET);
      const badgeTokenAccount = await getAssociatedTokenAddress(
        mint.publicKey,
        user,
        false,
        TOKEN_PROGRAM_ID,
        ASSOCIATED_TOKEN_PROGRAM_ID,
      );
      const mintRent = await getMinimumBalanceForRentExemptMint(connection);
      const feeLamports = Math.round(VERA_BADGE_FEE_SOL * LAMPORTS_PER_SOL);
      const metadataName = `${form.assetName.trim()} • Vera Badge`.slice(0, 32);
      const metadataSymbol = 'VERA'.slice(0, 10);
      const metadataUri = uploadResult.metadataUri.trim();

      if (metadataUri.length > 200) {
        throw new Error('Metadata URI is too long for on-chain NFT metadata.');
      }

      const [metadataPda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from('metadata'),
          TOKEN_METADATA_PROGRAM_ID.toBuffer(),
          mint.publicKey.toBuffer(),
        ],
        TOKEN_METADATA_PROGRAM_ID,
      );
      const buildMintTransaction = (blockhash: string) => {
        const tx = new Transaction().add(
          SystemProgram.transfer({
            fromPubkey: user,
            toPubkey: feeWallet,
            lamports: feeLamports,
          }),
          SystemProgram.createAccount({
            fromPubkey: user,
            newAccountPubkey: mint.publicKey,
            space: MINT_SIZE,
            lamports: mintRent,
            programId: TOKEN_PROGRAM_ID,
          }),
          createInitializeMintInstruction(mint.publicKey, 0, user, user, TOKEN_PROGRAM_ID),
          createAssociatedTokenAccountInstruction(
            user,
            badgeTokenAccount,
            user,
            mint.publicKey,
            TOKEN_PROGRAM_ID,
            ASSOCIATED_TOKEN_PROGRAM_ID,
          ),
          createMintToInstruction(mint.publicKey, badgeTokenAccount, user, 1, [], TOKEN_PROGRAM_ID),
          createCreateMetadataAccountV3Instruction(
            {
              metadata: metadataPda,
              mint: mint.publicKey,
              mintAuthority: user,
              payer: user,
              updateAuthority: user,
            },
            {
              createMetadataAccountArgsV3: {
                data: {
                  name: metadataName,
                  symbol: metadataSymbol,
                  uri: metadataUri,
                  sellerFeeBasisPoints: 0,
                  creators: null,
                  collection: null,
                  uses: null,
                },
                isMutable: true,
                collectionDetails: null,
              },
            },
          ),
        );

        tx.feePayer = user;
        tx.recentBlockhash = blockhash;
        tx.partialSign(mint);
        return tx;
      };

      const isRetryableBlockhashError = (value: unknown) => {
        const message = value instanceof Error ? value.message : String(value);
        return (
          /Blockhash not found/i.test(message) ||
          /block height exceeded/i.test(message) ||
          /signature .* has expired/i.test(message) ||
          /TransactionExpiredBlockheightExceededError/i.test(message)
        );
      };

      const maxAttempts = 3;
      let signature = '';
      let wasConfirmed = false;

      for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
        const latestBlockhash = await connection.getLatestBlockhash('finalized');
        const tx = buildMintTransaction(latestBlockhash.blockhash);
        try {
          signature = await walletProvider.sendTransaction(tx, connection, {
            preflightCommitment: 'processed',
            maxRetries: 3,
          });

          try {
            await connection.confirmTransaction(
              {
                signature,
                blockhash: latestBlockhash.blockhash,
                lastValidBlockHeight: latestBlockhash.lastValidBlockHeight,
              },
              'confirmed',
            );
            wasConfirmed = true;
            break;
          } catch (confirmError) {
            const status = await connection.getSignatureStatuses([signature]);
            const currentStatus = status.value[0];
            if (currentStatus && !currentStatus.err && currentStatus.confirmationStatus) {
              wasConfirmed = true;
              break;
            }

            if (!isRetryableBlockhashError(confirmError) || attempt === maxAttempts - 1) {
              throw confirmError;
            }
          }
        } catch (sendError) {
          if (!isRetryableBlockhashError(sendError) || attempt === maxAttempts - 1) {
            throw sendError;
          }
        }
      }

      if (!signature || !wasConfirmed) {
        throw new Error('Unable to confirm mint transaction. Please try again.');
      }

      const saveResponse = await fetch(`${SUPABASE_URL}/functions/v1/${SUPABASE_SAVE_FUNCTION}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
          apikey: SUPABASE_ANON_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          walletAddress: address,
          mintAddress: mint.publicKey.toBase58(),
          transactionSignature: signature,
          assetName: form.assetName.trim(),
          category: form.category.trim(),
          serialNumber: form.serialNumber.trim(),
          description: form.description.trim(),
          metadataUri: uploadResult.metadataUri,
          metadataGatewayUrl: uploadResult.metadataGatewayUrl || null,
          photoUris: uploadResult.photoUris || [],
          feeLamports,
          feeRecipient: VERA_FEE_WALLET,
        }),
      });

      if (!saveResponse.ok) {
        const saveError = await saveResponse.json().catch(() => null);
        const saveMessage =
          saveError && typeof saveError.error === 'string'
            ? saveError.error
            : 'Mint succeeded, but saving eNFT record failed.';
        setError(saveMessage);
      }

      setSuccess({ signature, mintAddress: mint.publicKey.toBase58() });
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
          Upload your physical asset details + photos, mint your badge NFT-like token to your
          wallet, and pay {VERA_BADGE_FEE_SOL} SOL mint fee.
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
          disabled={!isConnected || isSubmitting}
          onClick={submitBadge}
        >
          {isSubmitting ? 'Minting...' : 'Mint Vera Badge'}
        </button>
        <span className="matrix-text text-xs" style={{ color: 'var(--text-muted)' }}>
          Fee recipient: {VERA_FEE_WALLET}
        </span>
      </div>

      {error && (
        <p className="mt-3 text-sm" style={{ color: '#ffb5a8' }}>
          {error}
        </p>
      )}

      {success && (
        <div className="mt-3 flex flex-col gap-1 text-sm">
          <a
            className="text-[#ffb5a8] underline"
            href={`https://solscan.io/tx/${success.signature}`}
            target="_blank"
            rel="noreferrer"
          >
            View mint transaction
          </a>
          <p style={{ color: 'var(--text-muted)' }}>Badge mint: {success.mintAddress}</p>
        </div>
      )}
    </section>
  );
}
