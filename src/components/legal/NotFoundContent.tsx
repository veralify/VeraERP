'use client';

import { useLanguage } from '@i18n/LanguageProvider';

export function NotFoundContent() {
  const { t } = useLanguage();

  return (
    <main
      className="flex min-h-[70vh] items-center justify-center px-6 py-24"
      style={{ backgroundColor: 'var(--page-bg)', color: 'var(--text-main)' }}
    >
      <section className="flex max-w-md flex-col items-center gap-5 text-center">
        <p
          className="text-7xl font-semibold tracking-tight sm:text-8xl"
          style={{ color: 'var(--brand-primary)' }}
        >
          404
        </p>
        <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">{t.notFound.heading}</h2>
        <p className="text-lg leading-relaxed" style={{ color: 'var(--text-muted)' }}>
          {t.notFound.message}
        </p>
        <a href="/" title={t.notFound.goHome} className="btn-apple mt-2">
          &larr; {t.notFound.goHome}
        </a>
      </section>
    </main>
  );
}
