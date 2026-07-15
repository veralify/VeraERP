'use client';

import { getActiveBrand } from '@config/brands';
import { useLanguage } from '@i18n/LanguageProvider';

export function TermsContent() {
  const { t } = useLanguage();
  const brand = getActiveBrand();
  const tm = t.terms;

  return (
    <main
      className="mx-auto w-full max-w-3xl px-6 py-16"
      style={{ backgroundColor: 'var(--page-bg)', color: 'var(--text-main)' }}
    >
      <h1 className="matrix-heading text-3xl font-semibold md:text-4xl">{tm.title}</h1>
      <p className="matrix-text mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
        {tm.lastUpdated}
      </p>

      <div
        className="matrix-text mt-8 space-y-6 text-sm leading-relaxed md:text-base"
        style={{ color: 'var(--text-muted)' }}
      >
        <p>{tm.intro}</p>

        {tm.sections.map((section) => (
          <section key={section.heading} className="space-y-2">
            <h2
              className="matrix-heading text-lg font-semibold"
              style={{ color: 'var(--text-main)' }}
            >
              {section.heading}
            </h2>
            <p>{section.body}</p>
          </section>
        ))}

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            {tm.contactHeading}
          </h2>
          <p>
            {tm.contactBefore}{' '}
            <a href={brand.websiteUrl} className="underline hover:text-[#3B82F6]">
              {brand.websiteUrl}
            </a>
            .
          </p>
        </section>
      </div>
    </main>
  );
}
