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

  useEffect(() => {
    const supabase = createSupabaseBrowserClient();
    if (!supabase) return;
    supabase.auth.getUser().then(({ data }) => setUser(data.user ?? null));
    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const signOut = async () => {
    const supabase = createSupabaseBrowserClient();
    if (!supabase) return;
    await supabase.auth.signOut();
    setUser(null);
  };

  const sizing = variant === 'hero' ? 'h-[46px] px-6 text-[15px]' : 'h-9 px-4 text-[13px]';

  const primaryBtn = `inline-flex items-center justify-center rounded-full font-medium tracking-tight transition-transform duration-200 hover:scale-[1.03] active:scale-[0.97] ${sizing}`;
  const ghostBtn = `inline-flex items-center justify-center rounded-full border font-medium tracking-tight transition-colors hover:bg-white/10 ${sizing}`;

  return (
    <div className="flex items-center gap-3">
      {user ? (
        <>
          <span
            className="hidden max-w-[160px] truncate text-[13px] sm:inline"
            style={{ color: 'var(--text-muted)' }}
          >
            {user.email}
          </span>
          <button
            type="button"
            onClick={() => void signOut()}
            className={ghostBtn}
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
        <button
          type="button"
          onClick={() => setOpen(true)}
          className={primaryBtn}
          style={{ backgroundColor: 'var(--brand-primary)', color: '#ffffff' }}
        >
          Sign in
        </button>
      )}
      <AuthModal open={open} onClose={() => setOpen(false)} />
    </div>
  );
}
