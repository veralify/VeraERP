'use client';

import { AuthWidget } from '@components/auth/AuthWidget';
import { getActiveBrand } from '@config/brands';
import { LanguageSwitcher } from '@i18n/LanguageSwitcher';
import { ThemeToggle } from '@theme/ThemeToggle';
import Image from 'next/image';

const productLinks = [
  ['AI', '/ai'],
  ['Tracking', '/tracking'],
  ['Communities', '/communities'],
  ['Live', '/live'],
  ['Coaches', '/coaches'],
] as const;

type Props = { pageTitle?: string };

export function BaseNavigation({ pageTitle }: Props) {
  const brand = getActiveBrand();

  return (
    <header
      id="site-nav"
      className="glass sticky top-0 z-40"
      style={{ borderLeft: 'none', borderRight: 'none', borderTop: 'none' }}
    >
      {pageTitle && <h1 className="hidden">{pageTitle}</h1>}
      <div className="mx-auto flex min-h-16 w-full max-w-7xl items-center justify-between gap-4 px-6">
        <a
          href="/"
          className="inline-flex items-center gap-2.5 transition-opacity hover:opacity-80"
          aria-label={`${brand.name} home`}
        >
          <Image src={brand.assets.logoPath} alt="" width={30} height={30} priority />
          <span className="text-[17px] font-black tracking-tight text-vera-fg">
            {brand.shortName}
          </span>
        </a>
        <nav className="hidden items-center gap-1 lg:flex" aria-label="Product">
          {productLinks.map(([label, href]) => (
            <a
              key={href}
              href={href}
              className="rounded-full px-3 py-2 text-sm font-medium text-vera-fg-muted transition hover:bg-vera-surface hover:text-vera-fg"
            >
              {label}
            </a>
          ))}
          <a
            href="/pricing"
            className="rounded-full px-3 py-2 text-sm font-semibold text-vera-fg transition hover:bg-vera-surface"
          >
            Pricing
          </a>
          <a
            href="/about"
            className="rounded-full px-3 py-2 text-sm font-medium text-vera-fg-muted transition hover:bg-vera-surface hover:text-vera-fg"
          >
            About
          </a>
          <a
            href="/help"
            className="rounded-full px-3 py-2 text-sm font-medium text-vera-fg-muted transition hover:bg-vera-surface hover:text-vera-fg"
          >
            Help
          </a>
        </nav>
        <div className="flex items-center gap-2.5">
          <ThemeToggle />
          <LanguageSwitcher />
          <AuthWidget />
        </div>
      </div>
    </header>
  );
}
