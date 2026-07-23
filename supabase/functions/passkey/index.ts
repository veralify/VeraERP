// @ts-nocheck
// Passkey (WebAuthn) auth for Supabase-native accounts.
// One function routes all four ceremonies via the `action` field:
//   register-options | register-verify | authenticate-options | authenticate-verify
//
// After a successful register/authenticate ceremony we bridge into a real
// Supabase session by minting an email OTP (admin.generateLink) and returning
// it; the browser then calls supabase.auth.verifyOtp() to sign in.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';
import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} from 'https://esm.sh/@simplewebauthn/server@13.1.1';
import { isoBase64URL, isoUint8Array } from 'https://esm.sh/@simplewebauthn/server@13.1.1/helpers';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const RP_ID = Deno.env.get('WEBAUTHN_RP_ID') || 'localhost';
const RP_NAME = Deno.env.get('WEBAUTHN_RP_NAME') || 'Veralify';
const ORIGIN = Deno.env.get('WEBAUTHN_ORIGIN') || 'http://localhost:3000';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const normalizeEmail = (email: unknown) =>
  typeof email === 'string' ? email.trim().toLowerCase() : '';

async function getUserByEmail(email: string) {
  // Admin listing filtered client-side (Supabase has no direct get-by-email).
  const { data, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
  if (error) throw error;
  return data.users.find((u) => u.email?.toLowerCase() === email) ?? null;
}

async function saveChallenge(email: string, challenge: string, purpose: string) {
  await admin.from('webauthn_challenges').delete().eq('email', email).eq('purpose', purpose);
  await admin.from('webauthn_challenges').insert({ email, challenge, purpose });
}

async function takeChallenge(email: string, purpose: string): Promise<string | null> {
  const { data } = await admin
    .from('webauthn_challenges')
    .select('id, challenge, expires_at')
    .eq('email', email)
    .eq('purpose', purpose)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (!data) return null;
  await admin.from('webauthn_challenges').delete().eq('id', data.id);
  if (new Date(data.expires_at).getTime() < Date.now()) return null;
  return data.challenge;
}

// Issue a one-time email OTP the browser can exchange for a session.
async function issueOtp(email: string) {
  const { data, error } = await admin.auth.admin.generateLink({ type: 'magiclink', email });
  if (error) throw error;
  return { email, otp: data.properties?.email_otp };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'Invalid JSON body.' }, 400);
  }

  const action = String(payload.action || '');
  const email = normalizeEmail(payload.email);
  if (!email) return json({ error: 'Email is required.' }, 400);

  try {
    switch (action) {
      case 'register-options': {
        // Create the account if it does not exist yet (passwordless sign-up).
        let user = await getUserByEmail(email);
        if (!user) {
          const { data, error } = await admin.auth.admin.createUser({
            email,
            email_confirm: true,
          });
          if (error) throw error;
          user = data.user;
        }

        const { data: creds } = await admin
          .from('webauthn_credentials')
          .select('credential_id, transports')
          .eq('user_id', user.id);

        const options = await generateRegistrationOptions({
          rpName: RP_NAME,
          rpID: RP_ID,
          userName: email,
          userID: isoUint8Array.fromUTF8String(user.id),
          attestationType: 'none',
          excludeCredentials: (creds ?? []).map((c) => ({
            id: c.credential_id,
            transports: c.transports,
          })),
          authenticatorSelection: {
            residentKey: 'preferred',
            userVerification: 'preferred',
          },
        });

        await saveChallenge(email, options.challenge, 'registration');
        return json({ options });
      }

      case 'register-verify': {
        const user = await getUserByEmail(email);
        if (!user) return json({ error: 'Account not found.' }, 404);

        const expectedChallenge = await takeChallenge(email, 'registration');
        if (!expectedChallenge) return json({ error: 'Challenge expired.' }, 400);

        const verification = await verifyRegistrationResponse({
          response: payload.response,
          expectedChallenge,
          expectedOrigin: ORIGIN,
          expectedRPID: RP_ID,
        });

        if (!verification.verified || !verification.registrationInfo) {
          return json({ error: 'Passkey registration failed.' }, 400);
        }

        const { credential } = verification.registrationInfo;
        await admin.from('webauthn_credentials').insert({
          user_id: user.id,
          credential_id: credential.id,
          public_key: isoBase64URL.fromBuffer(credential.publicKey),
          counter: credential.counter,
          transports: credential.transports ?? [],
        });

        return json({ verified: true, session: await issueOtp(email) });
      }

      case 'authenticate-options': {
        const user = await getUserByEmail(email);
        if (!user) return json({ error: 'Account not found.' }, 404);

        const { data: creds } = await admin
          .from('webauthn_credentials')
          .select('credential_id, transports')
          .eq('user_id', user.id);

        if (!creds || creds.length === 0) {
          return json({ error: 'No passkeys registered for this account.' }, 404);
        }

        const options = await generateAuthenticationOptions({
          rpID: RP_ID,
          userVerification: 'preferred',
          allowCredentials: creds.map((c) => ({
            id: c.credential_id,
            transports: c.transports,
          })),
        });

        await saveChallenge(email, options.challenge, 'authentication');
        return json({ options });
      }

      case 'authenticate-verify': {
        const user = await getUserByEmail(email);
        if (!user) return json({ error: 'Account not found.' }, 404);

        const expectedChallenge = await takeChallenge(email, 'authentication');
        if (!expectedChallenge) return json({ error: 'Challenge expired.' }, 400);

        const credentialId = payload.response?.id;
        const { data: stored } = await admin
          .from('webauthn_credentials')
          .select('*')
          .eq('user_id', user.id)
          .eq('credential_id', credentialId)
          .maybeSingle();

        if (!stored) return json({ error: 'Unknown passkey.' }, 404);

        const verification = await verifyAuthenticationResponse({
          response: payload.response,
          expectedChallenge,
          expectedOrigin: ORIGIN,
          expectedRPID: RP_ID,
          credential: {
            id: stored.credential_id,
            publicKey: isoBase64URL.toBuffer(stored.public_key),
            counter: Number(stored.counter),
            transports: stored.transports,
          },
        });

        if (!verification.verified) return json({ error: 'Passkey verification failed.' }, 400);

        await admin
          .from('webauthn_credentials')
          .update({
            counter: verification.authenticationInfo.newCounter,
            last_used_at: new Date().toISOString(),
          })
          .eq('id', stored.id);

        return json({ verified: true, session: await issueOtp(email) });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    console.error('passkey error', err);
    return json({ error: err instanceof Error ? err.message : 'Unexpected error.' }, 500);
  }
});
