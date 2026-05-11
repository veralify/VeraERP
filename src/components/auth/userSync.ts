import type { User } from '@privy-io/react-auth';
import { SUPABASE_ANON_KEY, SUPABASE_URL } from './privyConfig';

export type SocialIdentity = {
  provider: string;
  socialUserId: string;
  email?: string | null;
  name?: string | null;
};

const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null;

const getLinkedAccountIdentity = (user: User): SocialIdentity | null => {
  const customFacebook = user.linkedAccounts.find((account) =>
    typeof account.type === 'string' ? account.type.toLowerCase().includes('facebook') : false,
  );

  if (customFacebook && isObject(customFacebook) && typeof customFacebook.subject === 'string') {
    return {
      provider: 'facebook',
      socialUserId: customFacebook.subject,
      email: typeof customFacebook.email === 'string' ? customFacebook.email : null,
      name: typeof customFacebook.name === 'string' ? customFacebook.name : null,
    };
  }

  return null;
};

export const getPrimarySocialIdentity = (user: User): SocialIdentity | null => {
  if (user.google) {
    return {
      provider: 'google',
      socialUserId: user.google.subject,
      email: user.google.email,
      name: user.google.name,
    };
  }

  if (user.apple) {
    return {
      provider: 'apple',
      socialUserId: user.apple.subject,
      email: user.apple.email,
      name: null,
    };
  }

  return getLinkedAccountIdentity(user);
};

export const getDisplayIdentity = (user: User): string =>
  user.google?.name ||
  getPrimarySocialIdentity(user)?.name ||
  user.email?.address ||
  user.phone?.number ||
  'Member';

export const syncPrivyUserToSupabase = async (params: { user: User }) => {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    return;
  }

  const identity = getPrimarySocialIdentity(params.user);
  await fetch(`${SUPABASE_URL}/functions/v1/vera-user-sync`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      apikey: SUPABASE_ANON_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      privyUserId: params.user.id,
      socialProvider: identity?.provider || null,
      socialUserId: identity?.socialUserId || null,
      email: identity?.email || params.user.email?.address || null,
      phone: params.user.phone?.number || null,
      displayName: getDisplayIdentity(params.user),
    }),
  });
};
