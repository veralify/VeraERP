import { createServerClient } from '@supabase/ssr';
import type { NextRequest, NextResponse } from 'next/server';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

/**
 * Refreshes the Supabase auth session (rotates cookies) on each matched request.
 * Returns a response carrying the updated Set-Cookie headers.
 */
export async function updateSupabaseSession(
  request: NextRequest,
  response: NextResponse,
): Promise<NextResponse> {
  if (!supabaseUrl || !supabaseAnonKey) {
    return response;
  }

  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
      },
    },
  });

  // Touch the session so expired tokens get refreshed and cookies rotated.
  await supabase.auth.getUser();

  return response;
}
