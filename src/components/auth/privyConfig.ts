import { activeBrand } from '@config/brands';
import type { PrivyClientConfig } from '@privy-io/react-auth';

export const PRIVY_APP_ID = import.meta.env.PUBLIC_PRIVY_APP_ID;
export const SUPABASE_URL = import.meta.env.PUBLIC_SUPABASE_URL;
export const SUPABASE_ANON_KEY = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

const loginMethods: Array<'email' | 'sms' | 'google' | 'apple' | `privy:${string}`> = [
  'google',
  'apple',
  'email',
  'sms',
];

export const privyConfig: PrivyClientConfig = {
  appearance: {
    theme: 'dark' as const,
    accentColor: activeBrand.theme.authAccent as `#${string}`,
    logo: activeBrand.assets.logoPath,
    landingHeader: activeBrand.copy.authLandingHeader,
    loginMessage: activeBrand.copy.authLandingMessage,
    showWalletLoginFirst: false,
    walletChainType: 'solana-only',
  },
  loginMethods,
  embeddedWallets: {
    solana: {
      createOnLogin: 'users-without-wallets',
    },
  },
};
