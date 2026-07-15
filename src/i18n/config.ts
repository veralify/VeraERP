export const locales = ['en', 'es', 'fr', 'de', 'it', 'ar'] as const;

export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = 'en';

export const localeMeta: Record<
  Locale,
  { label: string; nativeLabel: string; flag: string; dir: 'ltr' | 'rtl' }
> = {
  en: { label: 'English', nativeLabel: 'English', flag: '🇬🇧', dir: 'ltr' },
  es: { label: 'Spanish', nativeLabel: 'Español', flag: '🇪🇸', dir: 'ltr' },
  fr: { label: 'French', nativeLabel: 'Français', flag: '🇫🇷', dir: 'ltr' },
  de: { label: 'German', nativeLabel: 'Deutsch', flag: '🇩🇪', dir: 'ltr' },
  it: { label: 'Italian', nativeLabel: 'Italiano', flag: '🇮🇹', dir: 'ltr' },
  ar: { label: 'Arabic', nativeLabel: 'العربية', flag: '🇵🇸', dir: 'rtl' },
};

export const STORAGE_KEY = 'veralify-lang';

export function isLocale(value: string | null | undefined): value is Locale {
  return !!value && (locales as readonly string[]).includes(value);
}

/**
 * Resolve the best locale for a first render on the server, given the persisted
 * cookie value and the browser's `Accept-Language` header. Cookie wins; then the
 * first supported language in the header; otherwise the default locale.
 */
export function resolveLocale(cookieValue?: string | null, acceptLanguage?: string | null): Locale {
  if (isLocale(cookieValue)) return cookieValue;
  if (acceptLanguage) {
    for (const part of acceptLanguage.split(',')) {
      const tag = part.split(';')[0]?.trim().slice(0, 2).toLowerCase();
      if (isLocale(tag)) return tag;
    }
  }
  return defaultLocale;
}
