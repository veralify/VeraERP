'use client';

import { useState } from 'react';
import { localeMeta } from './config';
import { LanguageModal } from './LanguageModal';
import { useLanguage } from './LanguageProvider';

export function LanguageSwitcher() {
  const { locale } = useLanguage();
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-label="Select language"
        className="inline-flex h-9 items-center gap-2 rounded-full border px-3 text-[13px] font-medium tracking-tight transition-colors hover:bg-white/10"
        style={{
          borderColor: 'var(--surface-border)',
          backgroundColor: 'var(--surface)',
          color: 'var(--text-main)',
        }}
      >
        <span aria-hidden="true">{localeMeta[locale].flag}</span>
        <span className="hidden sm:inline">{localeMeta[locale].nativeLabel}</span>
        <span className="uppercase sm:hidden">{locale}</span>
        <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path
            d="M6 9l6 6 6-6"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </button>

      <LanguageModal open={open} onClose={() => setOpen(false)} />
    </>
  );
}
