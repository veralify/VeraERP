'use client';

import { AuthWidget } from '@components/auth/AuthWidget';
import { getActiveBrand } from '@config/brands';
import { useEffect } from 'react';

type Props = {
  pageTitle?: string;
};

const hasPrivyAppId = Boolean(process.env.NEXT_PUBLIC_PRIVY_APP_ID);

export function BaseNavigation({ pageTitle }: Props) {
  const brand = getActiveBrand();

  useEffect(() => {
    const nav = document.getElementById('site-nav');
    if (!nav) return;

    let lastY = window.scrollY;
    let ticking = false;

    const update = () => {
      const y = window.scrollY;
      if (y <= 80 || y < lastY) {
        nav.classList.remove('nav-hidden');
      } else if (y > lastY) {
        nav.classList.add('nav-hidden');
      }
      lastY = y;
      ticking = false;
    };

    const onScroll = () => {
      if (!ticking) {
        window.requestAnimationFrame(update);
        ticking = true;
      }
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <header
      id="site-nav"
      className="sticky top-0 z-40 border-b px-6 py-4 transition-transform duration-300 will-change-transform"
      style={{ borderColor: 'rgb(255 255 255 / 8%)', backgroundColor: 'var(--page-bg)' }}
    >
      {pageTitle && <h1 className="hidden">{pageTitle}</h1>}
      <div className="relative mx-auto flex w-full max-w-6xl items-center justify-center">
        <a
          href="/"
          className="matrix-text inline-flex items-center gap-3 hover:opacity-80 transition-opacity"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={brand.assets.logoPath}
            alt={`${brand.name} logo`}
            width={40}
            height={40}
            loading="eager"
          />
          <p className="matrix-heading text-xl font-semibold tracking-tight md:text-2xl">
            {brand.shortName}
          </p>
        </a>
        {hasPrivyAppId ? (
          <div className="absolute right-6">
            <AuthWidget />
          </div>
        ) : null}
      </div>
    </header>
  );
}
