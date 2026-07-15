'use client';

import { useLanguage } from '@i18n/LanguageProvider';

export function PrivacyContent() {
  const { t } = useLanguage();
  const p = t.privacy;

  return (
    <main
      className="mx-auto w-full max-w-3xl px-6 py-16"
      style={{ backgroundColor: 'var(--page-bg)', color: 'var(--text-main)' }}
    >
      <h1 className="matrix-heading text-3xl font-semibold md:text-4xl">{p.title}</h1>
      <p className="matrix-text mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
        {p.lastUpdated}
      </p>

      <div
        className="matrix-text mt-8 space-y-6 text-sm leading-relaxed md:text-base"
        style={{ color: 'var(--text-muted)' }}
      >
        <p>{p.intro}</p>

        {p.sections.map((section) => (
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
            {p.contactHeading}
          </h2>
          <p>
            VERALIFY LTD
            <br />
            Registered in England and Wales. Company Number: 17332341
            <br />
            Registered Office: 71-75 Shelton Street, Covent Garden, London, WC2H 9JQ
            <br />
            {p.contactEmailLabel}{' '}
            <a href="mailto:privacy@veralify.com" className="underline hover:text-[#3B82F6]">
              privacy@veralify.com
            </a>
          </p>
        </section>
      </div>
    </main>
  );
}
