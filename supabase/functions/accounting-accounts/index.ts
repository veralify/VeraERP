// accounting-accounts: what the mapping screen can choose from.
//
//   POST /functions/v1/accounting-accounts
//   Authorization: Bearer <user access token>
//   { "connection_id": "uuid" }
//   → { "expense_accounts": [...], "tax_codes": [...], "payment_accounts": [...] }
//
// Read live from the provider (charts of accounts change), through the same
// token manager as the worker, so an expired access token is refreshed and a
// dead grant flips the connection to needs_reauth.

import { corsHeaders } from '../_shared/http.ts';
import { createAdapter } from '../_shared/accounting/adapters.ts';
import { SupabaseSyncStore } from '../_shared/accounting/store.ts';
import {
  errorResponse,
  HttpError,
  isUuid,
  jsonResponse,
  readJson,
  requireUser,
  serviceClient,
} from '../_shared/accounting/supabase.ts';
import { TokenManager } from '../_shared/accounting/sync.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'METHOD_NOT_ALLOWED', message: 'Use POST.' }, 405);
  }
  try {
    const db = serviceClient();
    const user = await requireUser(req, db);
    const body = await readJson(req);
    if (!isUuid(body.connection_id)) {
      throw new HttpError(400, 'INVALID_CONNECTION', 'connection_id is required.');
    }
    const store = new SupabaseSyncStore(db);
    const connection = await store.loadConnection(body.connection_id);
    // Someone else's id looks exactly like a missing one.
    if (!connection || connection.user_id !== user.id) {
      throw new HttpError(404, 'CONNECTION_NOT_FOUND', 'Connection not found.');
    }
    if (connection.status !== 'active') {
      throw new HttpError(409, 'NEEDS_REAUTH', 'Reconnect this integration first.');
    }

    const adapter = createAdapter(connection.provider);
    const tokens = new TokenManager(store, adapter, connection);
    // First call alone: if the token needs refreshing it happens once, and the
    // two parallel calls after it reuse the new token.
    const expenseAccounts = await tokens.call((ctx) => adapter.listExpenseAccounts(ctx));
    const [taxCodes, paymentAccounts] = await Promise.all([
      tokens.call((ctx) => adapter.listTaxCodes(ctx)),
      tokens.call((ctx) => adapter.listPaymentAccounts(ctx)),
    ]);
    return jsonResponse({
      connection_id: connection.id,
      provider: connection.provider,
      requires_payment_account: adapter.requiresPaymentAccount,
      expense_accounts: expenseAccounts,
      tax_codes: taxCodes,
      payment_accounts: paymentAccounts,
    });
  } catch (error) {
    return errorResponse(error);
  }
});
