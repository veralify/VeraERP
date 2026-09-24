'use client';

import { createSupabaseBrowserClient } from '@lib/supabase/client';
import type { User } from '@supabase/supabase-js';
import { useEffect, useState } from 'react';
import { AuthModal } from './AuthModal';

type AuthWidgetProps = {
  variant?: 'navbar' | 'hero';
};

export function AuthWidget({ variant = 'navbar' }: AuthWidgetProps) {
  const [user, setUser] = useState<User | null>(null);
  const [open, setOpen] = useState(false);
  const [next, setNext] = useState<string | undefined>(undefined);

  useEffect(() => {
    const supabase = createSupabaseBrowserClient();
    if (!supabase) return;
    supabase.auth.getUser().then(({ data }) => setUser(data.user ?? null));
    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  // A signed-out visitor was sent here from a gated action (e.g. "Book & pay"
  // on a coach page) via `?auth=required&next=/coaches/<id>` — open the modal
  // immediately and carry `next` through so sign-in returns them there.
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get('auth') === 'required') {
      setNext(params.get('next') ?? undefined);
      setOpen(true);
    }
  }, []);

  const signOut = async () => {
    const supabase = createSupabaseBrowserClient();
    if (!supabase) return;
    await supabase.auth.signOut();
    setUser(null);
  };

  const sizing = variant === 'hero' ? 'h-[46px] px-6 text-[15px]' : 'h-9 px-4 text-[13px]';

  const primaryBtn = `items-center justify-center rounded-full font-medium tracking-tight transition-transform duration-200 hover:scale-[1.03] active:scale-[0.97] ${sizing}`;
  const ghostBtn = `items-center justify-center rounded-full border font-medium tracking-tight transition-colors hover:bg-white/10 ${sizing}`;

  return (
    <div className="flex items-center gap-2 sm:gap-3">
      {user ? (
        <>
          <span
            className="hidden max-w-[160px] truncate text-[13px] sm:inline"
            style={{ color: 'var(--text-muted)' }}
          >
            {user.email}
          </span>
          <a
            href="/dashboard"
            className={`${primaryBtn} inline-flex`}
            style={{
              backgroundColor: 'var(--brand-primary)',
              color: 'var(--vera-color-on-primary)',
            }}
          >
            Dashboard
          </a>
          <button
            type="button"
            onClick={() => void signOut()}
            className={`${ghostBtn} inline-flex`}
            style={{
              borderColor: 'var(--surface-border)',
              backgroundColor: 'var(--surface)',
              color: 'var(--text-main)',
            }}
          >
            Sign out
          </button>
        </>
      ) : (
        <>
          <button
            type="button"
            onClick={() => setOpen(true)}
            className={`${ghostBtn} inline-flex`}
            style={{
              borderColor: 'var(--surface-border)',
              backgroundColor: 'var(--surface)',
              color: 'var(--text-main)',
            }}
          >
            Sign in
          </button>
          <button
            type="button"
            onClick={() => setOpen(true)}
            className={`${primaryBtn} hidden sm:inline-flex`}
            style={{
              backgroundColor: 'var(--brand-primary)',
              color: 'var(--vera-color-on-primary)',
            }}
          >
            Get started
          </button>
        </>
      )}
      <AuthModal open={open} onClose={() => setOpen(false)} next={next} />
    </div>
  );
}
