import { SUPABASE_ANON_KEY, SUPABASE_URL } from './supabaseConfig';

export type SocialIdentity = {
  provider: string;
  socialUserId: string;
  email?: string | null;
  name?: string | null;
};
