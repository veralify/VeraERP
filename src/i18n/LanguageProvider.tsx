'use client';

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { defaultLocale, isLocale, type Locale, localeMeta, STORAGE_KEY } from './config';
import { ar } from './locales/ar';
import { de } from './locales/de';
import { type Dictionary, en } from './locales/en';
import { es } from './locales/es';
import { fr } from './locales/fr';
import { it } from './locales/it';

const dictionaries: Record<Locale, Dictionary> = { en, es, fr, de, it, ar };

// Persist the choice in a cookie (one year) so the server can render the right
// language on the first paint, eliminating the English flash on navigation.
const writeLocaleCookie = (locale: Locale) => {
  try {
    document.cookie = `${STORAGE_KEY}=${locale};path=/;max-age=31536000;samesite=lax`;
  } catch {
    /* ignore */
  }
};

type LanguageContextValue = {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: Dictionary;
  dir: 'ltr' | 'rtl';
};

const LanguageContext = createContext<LanguageContextValue | null>(null);

export function LanguageProvider({
  children,
  initialLocale = defaultLocale,
}: {
  children: React.ReactNode;
  initialLocale?: Locale;
}) {
  const [locale, setLocaleState] = useState<Locale>(initialLocale);

  useEffect(() => {
    // The server already resolved the locale from the cookie / Accept-Language,
    // so `initialLocale` is normally correct. This only reconciles legacy users
    // who saved a preference in localStorage before we used a cookie — adopt it
    // once and mirror it into the cookie so future loads render it server-side.
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (isLocale(stored)) {
      if (stored !== initialLocale) setLocaleState(stored);
      writeLocaleCookie(stored);
    } else {
      writeLocaleCookie(initialLocale);
    }
  }, [initialLocale]);

  useEffect(() => {
    const dir = localeMeta[locale].dir;
    document.documentElement.lang = locale;
    document.documentElement.dir = dir;
  }, [locale]);

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next);
    try {
      window.localStorage.setItem(STORAGE_KEY, next);
    } catch {
      /* ignore */
    }
    writeLocaleCookie(next);
  }, []);

  const value = useMemo<LanguageContextValue>(
    () => ({
      locale,
      setLocale,
      t: dictionaries[locale],
      dir: localeMeta[locale].dir,
    }),
    [locale, setLocale],
  );

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguage() {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error('useLanguage must be used within a LanguageProvider');
  return ctx;
}
