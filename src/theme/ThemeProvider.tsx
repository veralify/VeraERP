'use client';

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';

export type ThemeMode = 'auto' | 'day' | 'night';
export type Theme = 'day' | 'night';

export const THEME_KEY = 'veralify-theme';

/** Day between 06:00 and 18:00 local time, night otherwise. */
export const themeByHour = (date = new Date()): Theme => {
  const h = date.getHours();
  return h >= 6 && h < 18 ? 'day' : 'night';
};

const applyTheme = (theme: Theme) => {
  document.documentElement.setAttribute('data-theme', theme === 'day' ? 'light' : 'dark');
};

const readStoredMode = (): ThemeMode => {
  try {
    const match = document.cookie.match(/(?:^|; )veralify-theme=([^;]+)/);
    const stored = match ? decodeURIComponent(match[1]) : window.localStorage.getItem(THEME_KEY);
    if (stored === 'day' || stored === 'night' || stored === 'auto') return stored;
  } catch {
    /* ignore */
  }
  return 'auto';
};

const persistMode = (mode: ThemeMode) => {
  try {
    window.localStorage.setItem(THEME_KEY, mode);
    // biome-ignore lint/suspicious/noDocumentCookie: mirrors theme to a server-readable cookie.
    document.cookie = `${THEME_KEY}=${mode};path=/;max-age=31536000;samesite=lax`;
  } catch {
    /* ignore */
  }
};

type ThemeContextValue = {
  /** User preference: follows the clock when 'auto'. */
  mode: ThemeMode;
  /** Resolved theme currently shown. */
  theme: Theme;
  /** Set an explicit preference (or 'auto' to follow the clock). */
  setMode: (mode: ThemeMode) => void;
  /** Flip between day and night (sets an explicit preference). */
  toggle: () => void;
  /** True once the client has reconciled the stored preference. */
  ready: boolean;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

export function ThemeProvider({
  children,
  initialTheme = 'night',
}: {
  children: React.ReactNode;
  initialTheme?: Theme;
}) {
  const [mode, setModeState] = useState<ThemeMode>('auto');
  const [theme, setTheme] = useState<Theme>(initialTheme);
  const [ready, setReady] = useState(false);

  // Reconcile the stored preference on the client (cookie already primed the
  // first paint via the inline script in <head>, so this never flashes).
  useEffect(() => {
    setModeState(readStoredMode());
    setReady(true);
  }, []);

  // Resolve the active theme from the mode and keep <html data-theme> in sync.
  // When 'auto', re-check on an interval so it flips at the day/night boundary.
  useEffect(() => {
    const resolve = () => {
      const next = mode === 'auto' ? themeByHour() : mode;
      setTheme(next);
      applyTheme(next);
    };
    resolve();
    if (mode !== 'auto') return;
    const id = window.setInterval(resolve, 60_000);
    return () => window.clearInterval(id);
  }, [mode]);

  const setMode = useCallback((next: ThemeMode) => {
    setModeState(next);
    persistMode(next);
  }, []);

  const toggle = useCallback(() => {
    const current = mode === 'auto' ? themeByHour() : mode;
    setMode(current === 'day' ? 'night' : 'day');
  }, [mode, setMode]);

  const value = useMemo<ThemeContextValue>(
    () => ({ mode, theme, setMode, toggle, ready }),
    [mode, theme, setMode, toggle, ready],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within a ThemeProvider');
  return ctx;
}
