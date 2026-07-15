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
