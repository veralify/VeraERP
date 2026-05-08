import { solana } from '@reown/appkit/networks';
import { createAppKit } from '@reown/appkit/react';
import { SolanaAdapter } from '@reown/appkit-adapter-solana/react';

export const WALLETCONNECT_PROJECT_ID = import.meta.env.PUBLIC_WALLETCONNECT_PROJECT_ID;
export const VERA_BADGE_FEE_SOL = 0.001;
export const VERA_FEE_WALLET = 'CK1gBf6XyJaeZq1aS2gHsmrohA4gMDmPDBBu9hCBswnS';

const APPKIT_FLAG = '__veralify_appkit_initialized__';

declare global {
  interface Window {
    [APPKIT_FLAG]?: string;
  }
}

export function ensureAppKitInitialized() {
  if (typeof window === 'undefined' || !WALLETCONNECT_PROJECT_ID) {
    return;
  }

  if (window[APPKIT_FLAG] === WALLETCONNECT_PROJECT_ID) {
    return;
  }

  createAppKit({
    projectId: WALLETCONNECT_PROJECT_ID,
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

  window[APPKIT_FLAG] = WALLETCONNECT_PROJECT_ID;
}
