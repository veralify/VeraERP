import { createBrowserClient } from '@supabase/ssr';
import type { SupabaseClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

/**
 * Browser-side Supabase client (uses cookies for SSR-compatible sessions).
 * Safe to import in Client Components.
 *
 * Returns `null` when the public env vars are absent (e.g. a preview deploy
 * that wasn't given them) so a misconfiguration degrades gracefully — auth UI
 * disables itself — instead of throwing during render/mount and white-screening
 * the entire site with "Application error: a client-side exception".
 */
export function createSupabaseBrowserClient(): SupabaseClient | null {
  if (!supabaseUrl || !supabaseAnonKey) {
    if (typeof console !== 'undefined') {
      console.error(
        'Supabase browser client not configured: missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY.',
      );
    }
    return null;
  }
  return createBrowserClient(supabaseUrl, supabaseAnonKey);
}

/** True when the public Supabase env vars are present in this bundle. */
export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);
