'use client';

import { AuthWidget } from '@components/auth/AuthWidget';
import { getActiveBrand } from '@config/brands';
import { LanguageSwitcher } from '@i18n/LanguageSwitcher';
import { ThemeToggle } from '@theme/ThemeToggle';
import { useEffect } from 'react';

type Props = {
  pageTitle?: string;
};

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
      className="glass sticky top-0 z-40 transition-transform duration-300 will-change-transform"
      style={{ borderLeft: 'none', borderRight: 'none', borderTop: 'none' }}
    >
      {pageTitle && <h1 className="hidden">{pageTitle}</h1>}
      <div className="mx-auto flex h-14 w-full max-w-6xl items-center justify-between px-6">
        <a
          href="/"
          className="inline-flex items-center gap-2.5 transition-opacity hover:opacity-80"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={brand.assets.logoPath}
            alt={`${brand.name} logo`}
            width={30}
            height={30}
            loading="eager"
          />
          <p
            className="text-[17px] font-semibold tracking-tight"
            style={{ color: 'var(--text-main)' }}
          >
            {brand.shortName}
          </p>
        </a>
        <div className="flex items-center gap-2.5">
          <ThemeToggle />
          <LanguageSwitcher />
          <AuthWidget />
        </div>
      </div>
    </header>
  );
}
