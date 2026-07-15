'use client';

import { useEffect, useRef, useState } from 'react';
import { type Locale, localeMeta, locales } from './config';
import { useLanguage } from './LanguageProvider';

export function LanguageSwitcher() {
  const { locale, setLocale } = useLanguage();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onClick);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const choose = (next: Locale) => {
    setLocale(next);
    setOpen(false);
  };

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label="Select language"
        className="inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-medium transition hover:opacity-90"
        style={{
          borderColor: 'rgb(255 255 255 / 15%)',
          backgroundColor: 'rgb(255 255 255 / 5%)',
          color: 'var(--text-main)',
        }}
      >
        <span aria-hidden="true">{localeMeta[locale].flag}</span>
        <span className="hidden sm:inline">{localeMeta[locale].nativeLabel}</span>
        <span className="uppercase sm:hidden">{locale}</span>
        <svg
          className={`h-4 w-4 transition-transform ${open ? 'rotate-180' : ''}`}
          viewBox="0 0 24 24"
          fill="none"
          aria-hidden="true"
        >
          <path
            d="M6 9l6 6 6-6"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </button>

      {open && (
        <div
          role="listbox"
          aria-label="Language"
          className="absolute end-0 z-50 mt-2 w-44 overflow-hidden rounded-xl border shadow-xl"
          style={{
            borderColor: 'rgb(255 255 255 / 12%)',
            backgroundColor: '#0b0e17',
          }}
        >
          {locales.map((code) => (
            <button
              key={code}
              type="button"
              role="option"
              aria-selected={code === locale}
              onClick={() => choose(code)}
              className="flex w-full items-center gap-3 px-4 py-2.5 text-start text-sm transition hover:bg-white/10"
              style={{
                color: 'var(--text-main)',
                backgroundColor: code === locale ? 'rgb(59 130 246 / 18%)' : 'transparent',
              }}
            >
              <span aria-hidden="true">{localeMeta[code].flag}</span>
              <span>{localeMeta[code].nativeLabel}</span>
              {code === locale && (
                <svg
                  className="ms-auto h-4 w-4"
                  viewBox="0 0 24 24"
                  fill="none"
                  aria-hidden="true"
                  style={{ color: '#3b82f6' }}
                >
                  <path
                    d="M20 6 9 17l-5-5"
                    stroke="currentColor"
                    strokeWidth={2.5}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
