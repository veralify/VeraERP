// POST /functions/v1/account-delete   Authorization: Bearer <user access token>
// Body: {"confirm": true}. See handler.ts.

import { configFromEnv, createHandler } from './handler.ts';

Deno.serve(createHandler(() => configFromEnv()));
