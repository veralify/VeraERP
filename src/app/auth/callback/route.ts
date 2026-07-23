import { createSupabaseServerClient } from '@lib/supabase/server';
import { NextResponse } from 'next/server';

/**
 * OAuth / magic-link callback. Exchanges the `code` for a session cookie,
 * then redirects to `next` (default: home).
 */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get('code');
  const next = searchParams.get('next') ?? '/';

  if (code) {
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/?auth_error=1`);
}
