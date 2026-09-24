// accounting-callback: the OAuth redirect URI for every provider.
//
//   GET /functions/v1/accounting-callback?code=…&state=…[&realmId=…]
//
// The browser arrives here from the provider, without a Supabase session, so
// the function is deployed with --no-verify-jwt and trusts only the `state`:
// 256 random bits, bound to the user who started the handshake, valid for 15
// minutes, and deleted as it is read so it cannot be replayed.
//
// Several companies on one consent (Xero organisations, Fatture in Cloud
// companies): every one is stored as its own connection, sharing one Vault
// secret, because a single consent yields a single token for all of them.
// Only when exactly one company comes back is auto-sync switched on; with
// several, all start paused so a business expense is never posted into every
// ledger at once — the user turns on the one(s) they want on the
// integrations page. A selection step here would be the alternative, but a
// browser coming back from the provider has no Supabase session to show it
// with (and inside the iOS authentication sheet, no web session at all).
//
// The browser is then sent to the web integrations page or back to the app
// (return_to), with ?status=connected|error.

import { corsHeaders } from '../_shared/http.ts';
import {
  createAdapter,
  isReturnTarget,
  oauthRedirectUri,
  type ReturnTarget,
  returnUrl,
} from '../_shared/accounting/adapters.ts';
import { saveConnections } from '../_shared/accounting/store.ts';
import { serviceClient } from '../_shared/accounting/supabase.ts';
import { isAccountingProvider } from '../_shared/accounting/types.ts';

function redirect(target: ReturnTarget, params: Record<string, string>): Response {
  try {
    return new Response(null, {
      status: 302,
      headers: { ...corsHeaders, Location: returnUrl(target, params), 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    // No return URL configured: say so rather than leaving a blank page.
    console.error(error);
    return new Response(
      JSON.stringify({
        error: 'NOT_CONFIGURED',
        message: 'Return URL is not configured.',
        ...params,
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'GET') return new Response('Method not allowed', { status: 405 });

  const url = new URL(req.url);
  const state = url.searchParams.get('state');
  if (!state) return redirect('web', { status: 'error', error: 'invalid_state' });

  const db = serviceClient();
  // Delete-returning: the state is single use even if the redirect is replayed.
  const { data: rows, error: stateError } = await db
    .from('accounting_oauth_states')
    .delete()
    .eq('state', state)
    .select('user_id, provider, code_verifier, return_to, expires_at');
  if (stateError) {
    console.error('accounting-callback: state lookup failed', stateError.message);
    return redirect('web', { status: 'error', error: 'server' });
  }
  const handshake = rows?.[0] as
    | {
      user_id: string;
      provider: string;
      code_verifier: string | null;
      return_to: string;
      expires_at: string;
    }
    | undefined;
  if (!handshake || Date.parse(handshake.expires_at) < Date.now()) {
    return redirect('web', { status: 'error', error: 'expired_state' });
  }
  const target: ReturnTarget = isReturnTarget(handshake.return_to) ? handshake.return_to : 'web';
  const provider = handshake.provider;
  if (!isAccountingProvider(provider)) {
    return redirect(target, { status: 'error', error: 'invalid_state' });
  }

  // The user declined, or the provider failed before issuing a code.
  const providerError = url.searchParams.get('error');
  const code = url.searchParams.get('code');
  if (providerError || !code) {
    return redirect(target, {
      status: 'error',
      provider,
      error: providerError === 'access_denied' ? 'denied' : 'provider',
    });
  }

  try {
    const adapter = createAdapter(provider);
    const tokens = await adapter.exchangeCode({
      code,
      redirectUri: oauthRedirectUri(),
      codeVerifier: handshake.code_verifier,
    });
    const companies = await adapter.listCompanies(tokens, url.searchParams);
    if (!companies.length) {
      return redirect(target, { status: 'error', provider, error: 'no_company' });
    }
    const saved = await saveConnections(db, handshake.user_id, provider, tokens, companies);
    return redirect(target, {
      status: 'connected',
      provider,
      companies: String(saved.length),
    });
  } catch (error) {
    console.error('accounting-callback: connect failed', provider, error);
    return redirect(target, { status: 'error', provider, error: 'exchange' });
  }
});
