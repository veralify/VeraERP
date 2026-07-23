import { createSupabaseBrowserClient } from '@lib/supabase/client';
import {
  browserSupportsWebAuthn,
  startAuthentication,
  startRegistration,
} from '@simplewebauthn/browser';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const passkeysSupported = () => typeof window !== 'undefined' && browserSupportsWebAuthn();

async function callPasskey(action: string, body: Record<string, unknown>) {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error('Supabase is not configured.');
  }
  const res = await fetch(`${SUPABASE_URL}/functions/v1/passkey`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify({ action, ...body }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data?.error || 'Passkey request failed.');
  }
  return data;
}

// Exchange the one-time email OTP returned by the Edge Function for a session.
async function establishSession(session: { email: string; otp: string }) {
  const supabase = createSupabaseBrowserClient();
  if (!supabase) throw new Error('Authentication is temporarily unavailable.');
  const { error } = await supabase.auth.verifyOtp({
    email: session.email,
    token: session.otp,
    type: 'email',
  });
  if (error) throw error;
}

/** Register a new passkey for `email` (creates the account if needed) and signs in. */
export async function registerPasskey(email: string) {
  const { options } = await callPasskey('register-options', { email });
  const response = await startRegistration({ optionsJSON: options });
  const result = await callPasskey('register-verify', { email, response });
  if (!result.verified || !result.session?.otp) {
    throw new Error('Passkey registration could not complete.');
  }
  await establishSession(result.session);
}

/** Authenticate an existing account with a previously registered passkey. */
export async function authenticateWithPasskey(email: string) {
  const { options } = await callPasskey('authenticate-options', { email });
  const response = await startAuthentication({ optionsJSON: options });
  const result = await callPasskey('authenticate-verify', { email, response });
  if (!result.verified || !result.session?.otp) {
    throw new Error('Passkey sign-in could not complete.');
  }
  await establishSession(result.session);
}
