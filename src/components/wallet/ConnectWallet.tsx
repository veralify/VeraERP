import { solana } from '@reown/appkit/networks';
import { createAppKit, useAppKit, useAppKitAccount, useDisconnect } from '@reown/appkit/react';
import { SolanaAdapter, useAppKitConnection } from '@reown/appkit-adapter-solana/react';
import { LAMPORTS_PER_SOL, PublicKey } from '@solana/web3.js';
import { useEffect, useState } from 'react';

const WALLETCONNECT_PROJECT_ID = import.meta.env.PUBLIC_WALLETCONNECT_PROJECT_ID;

let initializedProjectId: string | null = null;

function initializeAppKit(projectId: string) {
  if (initializedProjectId === projectId) {
    return;
  }

  createAppKit({
    projectId,
    adapters: [new SolanaAdapter()],
    networks: [solana],
    defaultNetwork: solana,
    showWallets: true,
    metadata: {
      name: 'Veralify',
      description: 'Veralify wallet connection',
      url: window.location.origin,
      icons: [`${window.location.origin}/favicon.svg`],
    },
    themeMode: 'dark',
    themeVariables: {
      '--w3m-accent': '#d78a7a',
      '--w3m-color-mix': '#0d111b',
      '--w3m-color-mix-strength': 6,
      '--w3m-qr-color': '#d7a79c',
      '--apkt-accent': '#d78a7a',
      '--apkt-color-mix': '#0d111b',
      '--apkt-color-mix-strength': 6,
      '--apkt-qr-color': '#d7a79c',
    },
  });

  initializedProjectId = projectId;
}

if (typeof window !== 'undefined' && WALLETCONNECT_PROJECT_ID) {
  initializeAppKit(WALLETCONNECT_PROJECT_ID);
}

export function ConnectWallet() {
  const { open } = useAppKit();
  const { disconnect } = useDisconnect();
  const { connection } = useAppKitConnection();
  const { address, isConnected } = useAppKitAccount({ namespace: 'solana' });

  const [error, setError] = useState<string | null>(null);
  const [solBalance, setSolBalance] = useState<string | null>(null);
  const [isBalanceLoading, setIsBalanceLoading] = useState(false);

  useEffect(() => {
    const loadBalance = async () => {
      if (!isConnected || !address || !connection) {
        setSolBalance(null);
        return;
      }

      try {
        setIsBalanceLoading(true);
        const lamports = await connection.getBalance(new PublicKey(address), 'confirmed');
        const sol = lamports / LAMPORTS_PER_SOL;
        setSolBalance(sol.toFixed(4));
      } catch {
        setSolBalance(null);
      } finally {
        setIsBalanceLoading(false);
      }
    };

    void loadBalance();
  }, [address, connection, isConnected]);

  const connectWallet = async () => {
    try {
      setError(null);
      await open({ view: 'Connect' });
    } catch (openError) {
      const message =
        openError instanceof Error ? openError.message : 'Unable to open wallet modal';
      setError(message);
    }
  };

  const disconnectWallet = async () => {
    try {
      setError(null);
      await disconnect({ namespace: 'solana' });
    } catch (disconnectError) {
      const message =
        disconnectError instanceof Error ? disconnectError.message : 'Unable to disconnect wallet';
      setError(message);
    }
  };

  if (!WALLETCONNECT_PROJECT_ID) {
    return (
      <button
        type="button"
        className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
        style={{ borderColor: 'var(--surface-border)', color: 'var(--text-muted)' }}
        disabled
        title="Set PUBLIC_WALLETCONNECT_PROJECT_ID to enable WalletConnect AppKit."
      >
        WalletConnect disabled
      </button>
    );
  }

  const shortAddress = address ? `${address.slice(0, 6)}...${address.slice(-4)}` : null;

  return (
    <div className="flex flex-col items-end gap-2">
      {isConnected && shortAddress ? (
        <div className="flex items-center gap-2">
          <span
            className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
            style={{ borderColor: 'var(--surface-border)' }}
          >
            {shortAddress}
          </span>
          <span
            className="matrix-text inline-flex items-center gap-1.5 rounded-xl border px-4 py-2 text-xs font-semibold"
            style={{ borderColor: 'var(--surface-border)' }}
          >
            <svg viewBox="0 0 128 128" className="h-3.5 w-3.5" aria-hidden="true">
              <defs>
                <linearGradient id="solana-gradient-1" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stopColor="#00FFA3" />
                  <stop offset="100%" stopColor="#DC1FFF" />
                </linearGradient>
              </defs>
              <path
                d="M18 28c2-2 4-3 7-3h88c5 0 8 6 4 10l-14 14c-2 2-4 3-7 3H8c-5 0-8-6-4-10z"
                fill="url(#solana-gradient-1)"
              />
              <path
                d="M18 76c2-2 4-3 7-3h88c5 0 8 6 4 10L103 97c-2 2-4 3-7 3H8c-5 0-8-6-4-10z"
                fill="url(#solana-gradient-1)"
              />
              <path
                d="M103 52c-2 2-4 3-7 3H8c-5 0-8 6-4 10l14 14c2 2 4 3 7 3h88c5 0 8-6 4-10z"
                fill="url(#solana-gradient-1)"
              />
            </svg>
            <span>{isBalanceLoading ? '... SOL' : `${solBalance ?? '0.0000'} SOL`}</span>
          </span>
          <button
            type="button"
            className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
            style={{ borderColor: 'var(--surface-border)' }}
            onClick={disconnectWallet}
          >
            Disconnect
          </button>
        </div>
      ) : (
        <button
          type="button"
          className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
          style={{ borderColor: 'var(--surface-border)' }}
          onClick={connectWallet}
        >
          Connect Wallet
        </button>
      )}

      {error && <span className="text-xs text-[#ffb5a8]">{error}</span>}
    </div>
  );
}
