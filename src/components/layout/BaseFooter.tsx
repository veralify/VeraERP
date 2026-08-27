'use client';

import { getActiveBrand } from '@config/brands';
import Image from 'next/image';

const columns = [
  {
    title: 'Product',
    links: [
      ['AI', '/ai'],
      ['Tracking', '/tracking'],
      ['Communities', '/communities'],
      ['Live rooms', '/live'],
      ['Coaches', '/coaches'],
    ],
  },
  {
    title: 'Company',
    links: [
      ['Pricing', '/pricing'],
      ['About', '/about'],
      ['Help', '/help'],
    ],
  },
  {
    title: 'Legal',
    links: [
      ['Privacy', '/privacy'],
      ['Terms', '/terms'],
    ],
  },
] as const;

export function BaseFooter() {
  const brand = getActiveBrand();
  const year = new Date().getFullYear();

  return (
    <footer className="border-t border-vera-border bg-vera-bg-subtle text-vera-fg-muted">
      <div className="mx-auto max-w-7xl px-6 py-14">
        <div className="grid gap-10 lg:grid-cols-[1.3fr_2fr]">
          <div>
            <a
              href="/"
              className="inline-flex items-center gap-2.5"
              aria-label={`${brand.name} home`}
            >
              <Image src={brand.assets.logoPath} alt="" width={32} height={32} />
              <span className="text-xl font-black tracking-tight text-vera-fg">{brand.name}</span>
            </a>
            <p className="mt-4 max-w-sm text-sm leading-6">
              Track. Connect. Transform. AI-powered fitness tracking, communities, live rooms, and
              coaches.
            </p>
          </div>
          <nav className="grid gap-8 sm:grid-cols-3" aria-label="Footer">
            {columns.map((column) => (
              <div key={column.title}>
                <h2 className="text-sm font-bold text-vera-fg">{column.title}</h2>
                <ul className="mt-4 space-y-3 text-sm">
                  {column.links.map(([label, href]) => (
                    <li key={href}>
                      <a className="hover:text-vera-primary" href={href}>
                        {label}
                      </a>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </nav>
        </div>
        <div className="mt-12 border-t border-vera-border pt-6 text-xs">
          © {year} Veralify · VERALIFY LTD · Company Number 17332341
        </div>
      </div>
    </footer>
  );
}
