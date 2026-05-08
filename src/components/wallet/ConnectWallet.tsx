import { useAppKit, useAppKitAccount, useDisconnect } from '@reown/appkit/react';
import { useAppKitConnection } from '@reown/appkit-adapter-solana/react';
import { LAMPORTS_PER_SOL, PublicKey } from '@solana/web3.js';
import { useEffect, useState } from 'react';
import { ensureAppKitInitialized, WALLETCONNECT_PROJECT_ID } from './appkit';

ensureAppKitInitialized();

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
