// Adapter construction from Supabase function secrets (contract §6), plus the
// URLs the OAuth round trip needs.

import { FattureInCloudAdapter } from './fatture_in_cloud.ts';
import { FreeAgentAdapter } from './freeagent.ts';
import { QuickBooksAdapter } from './quickbooks.ts';
import {
  type AccountingAdapter,
  AccountingError,
  type AccountingProvider,
  type FetchLike,
} from './types.ts';
import { XeroAdapter } from './xero.ts';

export type EnvReader = (name: string) => string | undefined;

const denoEnv: EnvReader = (name) => Deno.env.get(name);

function required(env: EnvReader, name: string): string {
  const value = env(name);
  if (!value) {
    throw new AccountingError('config', `Missing function secret ${name}`);
  }
  return value;
}

function environment(env: EnvReader, name: string): 'sandbox' | 'production' {
  return env(name) === 'sandbox' ? 'sandbox' : 'production';
}

export function createAdapter(
  provider: AccountingProvider,
  env: EnvReader = denoEnv,
  fetchFn?: FetchLike,
): AccountingAdapter {
  switch (provider) {
    case 'quickbooks':
      return new QuickBooksAdapter({
        clientId: required(env, 'QUICKBOOKS_CLIENT_ID'),
        clientSecret: required(env, 'QUICKBOOKS_CLIENT_SECRET'),
        environment: environment(env, 'QUICKBOOKS_ENVIRONMENT'),
        fetch: fetchFn,
      });
    case 'xero':
      return new XeroAdapter({
        clientId: required(env, 'XERO_CLIENT_ID'),
        clientSecret: required(env, 'XERO_CLIENT_SECRET'),
        fetch: fetchFn,
      });
    case 'freeagent':
      return new FreeAgentAdapter({
        clientId: required(env, 'FREEAGENT_CLIENT_ID'),
        clientSecret: required(env, 'FREEAGENT_CLIENT_SECRET'),
        environment: environment(env, 'FREEAGENT_ENVIRONMENT'),
        fetch: fetchFn,
      });
    case 'fatture_in_cloud':
      return new FattureInCloudAdapter({
        clientId: required(env, 'FIC_CLIENT_ID'),
        clientSecret: required(env, 'FIC_CLIENT_SECRET'),
        fetch: fetchFn,
      });
  }
}

/**
 * The redirect URI registered with every provider:
 * `{ACCOUNTING_OAUTH_REDIRECT_BASE}/accounting-callback`, where the base is
 * normally `https://<project-ref>.supabase.co/functions/v1`.
 */
export function oauthRedirectUri(env: EnvReader = denoEnv): string {
  return `${
    required(env, 'ACCOUNTING_OAUTH_REDIRECT_BASE').replace(/\/+$/, '')
  }/accounting-callback`;
}

export type ReturnTarget = 'web' | 'app';

export function isReturnTarget(value: unknown): value is ReturnTarget {
  return value === 'web' || value === 'app';
}

/** Default app return URL; ASWebAuthenticationSession listens for this scheme. */
export const DEFAULT_APP_RETURN_URL = 'veralify://integrations';

/**
 * Where the browser lands once the handshake is over. Web: the integrations
 * page (`ACCOUNTING_WEB_RETURN_URL`); app: a custom-scheme URL the iOS
 * authentication session is waiting for.
 */
export function returnUrl(
  target: ReturnTarget,
  params: Record<string, string>,
  env: EnvReader = denoEnv,
): string {
  const base = target === 'app'
    ? env('ACCOUNTING_APP_RETURN_URL') || DEFAULT_APP_RETURN_URL
    : required(env, 'ACCOUNTING_WEB_RETURN_URL');
  const url = new URL(base);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return url.toString();
}
