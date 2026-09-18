import { cookies, headers } from 'next/headers';
import { resolveLocale, STORAGE_KEY } from './config';
import { dictionaries } from './dictionaries';

/**
 * Resolves the visitor's locale server-side (same cookie/Accept-Language logic
 * as the root layout) and returns its dictionary. For Server Components that
 * render translated marketing copy without needing `'use client'` + Context —
 * the LanguageProvider Context only exists for client components.
 */
export async function getServerDictionary() {
  const [cookieStore, headerList] = await Promise.all([cookies(), headers()]);
  const locale = resolveLocale(
    cookieStore.get(STORAGE_KEY)?.value,
    headerList.get('accept-language'),
  );
  return { locale, t: dictionaries[locale] };
}
