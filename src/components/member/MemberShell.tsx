'use client';

import { usePathname } from 'next/navigation';
import type { ReactNode } from 'react';

const navItems = [
  ['Dashboard', '/dashboard'],
  ['Track', '/dashboard/track'],
  ['Nutrition', '/dashboard/nutrition'],
  ['Progress', '/dashboard/progress'],
  ['Goals', '/dashboard/goals'],
  ['Groups', '/dashboard/groups'],
  ['Live', '/dashboard/live'],
  ['Messages', '/dashboard/messages'],
  ['AI', '/dashboard/ai'],
  ['Profile', '/dashboard/profile'],
  ['Billing', '/dashboard/billing'],
  ['Coach', '/dashboard/coach'],
] as const;

export function MemberShell({ children, email }: { children: ReactNode; email: string | null }) {
  const pathname = usePathname();

  return (
    <div className="min-h-screen bg-vera-bg text-vera-fg lg:grid lg:grid-cols-[280px_1fr]">
      <aside className="hidden border-r border-vera-border bg-vera-bg-subtle/80 p-5 lg:block">
        <a href="/" className="text-xl font-black tracking-tight">
          Veralify
        </a>
        <p className="mt-2 truncate text-sm text-vera-fg-muted">{email ?? 'Member app'}</p>
        <nav className="mt-8 space-y-1" aria-label="Member">
          {navItems.map(([label, href]) => {
            const current = pathname === href;
            return (
              <a
                key={href}
                href={href}
                aria-current={current ? 'page' : undefined}
                className={`block min-h-11 rounded-vera-lg px-4 py-3 text-sm font-semibold transition ${current ? 'bg-vera-primary text-vera-on-primary' : 'text-vera-fg-muted hover:bg-vera-surface-muted hover:text-vera-fg'}`}
              >
                {label}
              </a>
            );
          })}
        </nav>
      </aside>
      <div className="min-w-0">
        <header className="sticky top-0 z-40 border-b border-vera-border bg-vera-glass px-4 py-3 backdrop-blur lg:px-8">
          <div className="flex items-center justify-between gap-4">
            <a href="/dashboard" className="font-bold lg:hidden">
              Veralify
            </a>
            <p className="hidden text-sm text-vera-fg-muted lg:block">Track. Connect. Transform.</p>
            <a className="btn-apple-secondary h-10" href="/pricing">
              Pro
            </a>
          </div>
          <nav
            className="mt-3 flex gap-2 overflow-x-auto pb-1 lg:hidden"
            aria-label="Member mobile"
          >
            {navItems.map(([label, href]) => (
              <a
                key={href}
                href={href}
                aria-current={pathname === href ? 'page' : undefined}
                className={`shrink-0 rounded-full px-4 py-2 text-sm ${pathname === href ? 'bg-vera-primary text-vera-on-primary' : 'bg-vera-surface text-vera-fg-muted'}`}
              >
                {label}
              </a>
            ))}
          </nav>
        </header>
        {children}
      </div>
    </div>
  );
}
