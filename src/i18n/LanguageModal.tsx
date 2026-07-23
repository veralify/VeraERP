'use client';

import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { type Locale, localeMeta, locales } from './config';
import { useLanguage } from './LanguageProvider';

type Props = {
  open: boolean;
  onClose: () => void;
};

export function LanguageModal({ open, onClose }: Props) {
  const { locale, setLocale } = useLanguage();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    if (open) {
      window.addEventListener('keydown', onKey);
      document.body.style.overflow = 'hidden';
    }
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open, onClose]);

  if (!open || !mounted) return null;

  const choose = (next: Locale) => {
    setLocale(next);
    onClose();
  };

  return createPortal(
    <div className="fixed inset-0 z-[110] flex items-start justify-center overflow-y-auto p-4 sm:items-center">
      <button
        type="button"
        aria-label="Close dialog"
        onClick={onClose}
        className="fixed inset-0 h-full w-full cursor-default backdrop-blur-md"
        style={{ backgroundColor: 'rgb(0 0 0 / 70%)' }}
      />
      <div
        className="relative my-auto w-full max-w-3xl rounded-[22px] border p-6 sm:p-8"
        style={{
          borderColor: 'var(--surface-border)',
          backgroundColor: 'var(--surface-elevated)',
          boxShadow: 'var(--shadow-lg)',
        }}
        role="dialog"
        aria-modal="true"
        aria-label="Select your language"
      >
        <div className="mb-6 flex items-center justify-between">
          <h2
            className="text-[19px] font-semibold tracking-tight sm:text-xl"
            style={{ color: 'var(--text-main)' }}
          >
            Select your language
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="flex h-9 w-9 items-center justify-center rounded-full border text-sm opacity-70 transition hover:opacity-100"
            style={{ borderColor: 'var(--surface-border)', color: 'var(--text-main)' }}
            aria-label="Close"
          >
            ✕
          </button>
        </div>

        <div className="grid grid-cols-1 gap-1.5 sm:grid-cols-2 lg:grid-cols-4">
          {locales.map((code) => {
            const active = code === locale;
            return (
              <button
                key={code}
                type="button"
                onClick={() => choose(code)}
                aria-current={active}
                className="flex items-center gap-3 rounded-xl px-3 py-3 text-start text-sm transition hover:bg-white/5"
                style={{
                  backgroundColor: active ? 'rgb(59 130 246 / 12%)' : 'transparent',
                  color: active ? 'var(--brand-primary)' : 'var(--text-main)',
                }}
              >
                <span
                  className="flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-full text-base leading-none"
                  aria-hidden="true"
                  style={{
                    backgroundColor: 'var(--surface)',
                    boxShadow: 'inset 0 0 0 1px var(--surface-border)',
                  }}
                >
                  {localeMeta[code].flag}
                </span>
                <span className="flex-1 truncate font-medium">{localeMeta[code].nativeLabel}</span>
                {active && (
                  <svg
                    className="h-4 w-4 shrink-0"
                    viewBox="0 0 24 24"
                    fill="none"
                    aria-hidden="true"
                    style={{ color: 'var(--brand-primary)' }}
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
            );
          })}
        </div>
      </div>
    </div>,
    document.body,
  );
}
