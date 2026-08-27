import { updateSupabaseSession } from '@lib/supabase/middleware';
import type { NextRequest } from 'next/server';
import { NextResponse } from 'next/server';

export async function middleware(request: NextRequest) {
  const host = request.headers.get('host')?.toLowerCase() || '';

  if (host.startsWith('dashboard.veralify.com') && request.nextUrl.pathname === '/') {
    const url = request.nextUrl.clone();
    url.pathname = '/dashboard';
    return NextResponse.redirect(url);
  }

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('x-pathname', request.nextUrl.pathname);
  const response = NextResponse.next({ request: { headers: requestHeaders } });
  return updateSupabaseSession(request, response);
}

export const config = {
  // Run on non-API app paths only (excluding static assets and Next internals)
  // so auth-session refresh middleware never blocks public API endpoints.
  matcher: [
    '/((?!api|_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
