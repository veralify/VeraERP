// accounting-connect: starts an OAuth handshake with an accounting provider.
//
//   POST /functions/v1/accounting-connect
//   Authorization: Bearer <user access token>
//   { "provider": "xero", "return_to": "web" | "app" }
//   → { "url": "<provider authorize URL>", "expires_in": 900 }
//
// The state (and the PKCE verifier, where the provider supports it) is kept
// server-side in accounting_oauth_states; the browser only ever carries the
// opaque state value, which accounting-callback consumes exactly once.

import { corsHeaders } from '../_shared/http.ts';
import { createAdapter, isReturnTarget, oauthRedirectUri } from '../_shared/accounting/adapters.ts';
import { codeChallengeS256, randomToken } from '../_shared/accounting/pkce.ts';
import {
  errorResponse,
  HttpError,
  jsonResponse,
  readJson,
  requireUser,
  serviceClient,
} from '../_shared/accounting/supabase.ts';
import { isAccountingProvider } from '../_shared/accounting/types.ts';

/** Matches the column default on accounting_oauth_states.expires_at. */
const STATE_TTL_SECONDS = 15 * 60;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'METHOD_NOT_ALLOWED', message: 'Use POST.' }, 405);
  }
  try {
    const db = serviceClient();
    const user = await requireUser(req, db);
    const body = await readJson(req);
    if (!isAccountingProvider(body.provider)) {
      throw new HttpError(400, 'INVALID_PROVIDER', 'Unknown accounting provider.');
    }
    const returnTo = body.return_to ?? 'web';
    if (!isReturnTarget(returnTo)) {
      throw new HttpError(400, 'INVALID_RETURN_TO', 'return_to must be "web" or "app".');
    }

    const adapter = createAdapter(body.provider);
    const redirectUri = oauthRedirectUri();
    const state = randomToken();
    const verifier = adapter.supportsPkce ? randomToken(48) : null;

    // Housekeeping: abandoned handshakes of this user.
    await db.from('accounting_oauth_states').delete().eq('user_id', user.id).lt(
      'expires_at',
      new Date().toISOString(),
    );
    const { error } = await db.from('accounting_oauth_states').insert({
      state,
      user_id: user.id,
      provider: body.provider,
      code_verifier: verifier,
      return_to: returnTo,
      expires_at: new Date(Date.now() + STATE_TTL_SECONDS * 1000).toISOString(),
    });
    if (error) throw new Error(`store oauth state: ${error.message}`);

    const url = adapter.authorizeUrl({
      state,
      redirectUri,
      codeChallenge: verifier ? await codeChallengeS256(verifier) : undefined,
    });
    return jsonResponse({ url, provider: body.provider, expires_in: STATE_TTL_SECONDS });
  } catch (error) {
    return errorResponse(error);
  }
});
