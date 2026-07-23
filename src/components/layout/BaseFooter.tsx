'use client';

import { getActiveBrand } from '@config/brands';
import { useLanguage } from '@i18n/LanguageProvider';
import { useEffect } from 'react';

type Props = {
  backToTop?: boolean;
};

export function BaseFooter({ backToTop = false }: Props) {
  const brand = getActiveBrand();
  const { t } = useLanguage();
  const year = new Date().getFullYear();

  const footerColumns: {
    title: string;
    links: { label: string; href: string; newTab?: boolean }[];
  }[] = [
    {
      title: t.footer.legalNotice,
      links: [
        { label: t.footer.privacyPolicy, href: '/privacy', newTab: true },
        { label: t.footer.termsOfService, href: '/terms', newTab: true },
      ],
    },
  ];

  useEffect(() => {
    if (!backToTop) return;
    const button = document.querySelector('.backToTop');
    if (!button) return;

    const toggle = () => {
      if (window.scrollY > 250) button.classList.add('active');
      else button.classList.remove('active');
    };
    const onClick = () => window.scrollTo({ top: 0, behavior: 'smooth' });

    button.addEventListener('click', onClick);
    window.addEventListener('scroll', toggle);
    return () => {
      button.removeEventListener('click', onClick);
      window.removeEventListener('scroll', toggle);
    };
  }, [backToTop]);

  return (
    <>
      {backToTop && (
        <button
          type="button"
          className="backToTop glass fixed bottom-6 right-6 z-50 flex h-11 w-11 items-center justify-center rounded-full p-2.5 opacity-0 transition-all duration-300 hover:scale-105"
          style={{ color: 'var(--text-main)' }}
          aria-label={t.footer.backToTop}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            height="100%"
            width="100%"
            strokeWidth={1.75}
            stroke="currentColor"
          >
            <title>{t.footer.backToTop}</title>
            <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 15.75 7.5-7.5 7.5 7.5" />
          </svg>
        </button>
      )}

      <footer
        className="relative z-10 border-t"
        style={{
          backgroundColor: 'var(--surface-elevated)',
          borderColor: 'var(--surface-border)',
          color: 'var(--text-muted)',
        }}
      >
        <h2 className="sr-only">Footer</h2>

        <div className="mx-auto w-full max-w-6xl px-6 pb-12 pt-16">
          <div className="flex flex-col gap-12 md:flex-row md:justify-between">
            <div className="max-w-sm">
              <a href="/" className="flex items-center gap-2.5" aria-label={`${brand.name} home`}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={brand.assets.logoPath} alt="" className="h-8 w-8" />
                <span
                  className="text-xl font-semibold tracking-tight"
                  style={{ color: 'var(--text-main)' }}
                >
                  {brand.name}
                </span>
              </a>
              <p className="mt-4 text-sm leading-relaxed">{t.footer.tagline}</p>
            </div>

            <nav className="flex flex-wrap gap-x-16 gap-y-8" aria-label="Footer">
              {footerColumns.map((col) => (
                <div key={col.title}>
                  <h3
                    className="text-[13px] font-semibold tracking-tight"
                    style={{ color: 'var(--text-main)' }}
                  >
                    {col.title}
                  </h3>
                  <ul className="mt-4 space-y-3 text-sm">
                    {col.links.map((link) => (
                      <li key={link.href}>
                        <a
                          href={link.href}
                          target={link.newTab ? '_blank' : undefined}
                          rel={link.newTab ? 'noopener noreferrer' : undefined}
                          className="transition-colors hover:text-[var(--brand-primary)]"
                          style={{ color: 'var(--text-muted)' }}
                        >
                          {link.label}
                        </a>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </nav>
          </div>

          <hr
            className="mt-16 h-px border-0"
            style={{ backgroundColor: 'var(--surface-border)' }}
          />

          <div className="mt-6 flex flex-col gap-4 text-xs sm:flex-row sm:items-center sm:justify-between">
            <p>{t.footer.company.replace('{year}', String(year))}</p>

            <div className="flex items-center gap-5">
              <a
                href="https://www.linkedin.com"
                target="_blank"
                rel="noopener noreferrer"
                aria-label={`${brand.name} on LinkedIn`}
                className="transition-colors hover:text-[var(--brand-primary)]"
                style={{ color: 'var(--text-muted)' }}
              >
                <span className="sr-only">{brand.name} on LinkedIn</span>
                <svg viewBox="0 0 24 24" aria-hidden="true" className="h-5 w-5 fill-current">
                  <path d="M4.98 3.5a2.5 2.5 0 1 0 .02 5 2.5 2.5 0 0 0-.02-5ZM3 9h4v12H3V9Zm7 0h3.8v1.7h.1c.5-1 1.8-2 3.7-2 4 0 4.8 2.6 4.8 6V21h-4v-5.3c0-1.3 0-2.8-1.8-2.8-1.8 0-2 1.4-2 2.7V21h-4V9Z" />
                </svg>
              </a>
              <a
                href={brand.social.xUrl}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={`${brand.name} on X`}
                className="transition-colors hover:text-[var(--brand-primary)]"
                style={{ color: 'var(--text-muted)' }}
              >
                <span className="sr-only">{brand.name} on X</span>
                <svg viewBox="0 0 24 24" aria-hidden="true" className="h-5 w-5 fill-current">
                  <path d="M18.9 2H22l-6.8 7.7L23 22h-6.4l-5-6.5L5.8 22H2.7l7.3-8.3L1 2h6.6l4.5 5.9L18.9 2Zm-1.1 18h1.7L6.6 3.9H4.8L17.8 20Z" />
                </svg>
              </a>
              <a
                href="https://github.com/veralify"
                target="_blank"
                rel="noopener noreferrer"
                aria-label={`${brand.name} on GitHub`}
                className="transition-colors hover:text-[var(--brand-primary)]"
                style={{ color: 'var(--text-muted)' }}
              >
                <span className="sr-only">{brand.name} on GitHub</span>
                <svg viewBox="0 0 24 24" aria-hidden="true" className="h-5 w-5 fill-current">
                  <path d="M12 2C6.48 2 2 6.59 2 12.24c0 4.52 2.87 8.35 6.84 9.7.5.1.66-.22.66-.49 0-.24-.01-1.05-.01-1.91-2.78.62-3.37-1.22-3.37-1.22-.46-1.2-1.11-1.52-1.11-1.52-.91-.64.07-.62.07-.62 1 .07 1.53 1.05 1.53 1.05.9 1.58 2.36 1.13 2.93.86.09-.67.35-1.13.64-1.39-2.22-.26-4.56-1.14-4.56-5.09 0-1.13.39-2.05 1.04-2.78-.1-.26-.45-1.31.1-2.73 0 0 .84-.28 2.75 1.06A9.28 9.28 0 0 1 12 6.89a9.2 9.2 0 0 1 2.5.35c1.9-1.34 2.74-1.06 2.74-1.06.55 1.42.2 2.47.1 2.73.65.73 1.04 1.65 1.04 2.78 0 3.96-2.34 4.82-4.57 5.08.36.32.68.94.68 1.9 0 1.38-.01 2.49-.01 2.83 0 .27.16.59.67.49A10.12 10.12 0 0 0 22 12.24C22 6.59 17.52 2 12 2Z" />
                </svg>
              </a>
            </div>
          </div>
        </div>
      </footer>
    </>
  );
}
