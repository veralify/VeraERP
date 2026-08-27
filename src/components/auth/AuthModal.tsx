'use client';

import { authenticateWithPasskey, passkeysSupported } from '@lib/auth/passkey';
import { createSupabaseBrowserClient } from '@lib/supabase/client';
import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';

type Step = 'email' | 'password';
type Mode = 'signin' | 'signup';
type Busy = null | 'email' | 'google' | 'apple' | 'passkey';

type Props = {
  open: boolean;
  onClose: () => void;
};

export function AuthModal({ open, onClose }: Props) {
  const [step, setStep] = useState<Step>('email');
  const [mode, setMode] = useState<Mode>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState<Busy>(null);
  const [canUsePasskey, setCanUsePasskey] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    setCanUsePasskey(passkeysSupported());
  }, []);

  useEffect(() => {
    if (!open) {
      setStep('email');
      setMode('signin');
      setPassword('');
      setError(null);
      setNotice(null);
      setLoading(null);
    }
  }, [open]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    if (open) window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open || !mounted) return null;

  const supabase = createSupabaseBrowserClient();
  const busy = loading !== null;
  const emailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());

  const oauth = async (provider: 'google' | 'apple', which: Busy) => {
    if (!supabase) {
      setError('Authentication is temporarily unavailable.');
      return;
    }
    setError(null);
    setLoading(which);
    try {
      const { error: err } = await supabase.auth.signInWithOAuth({
        provider,
        options: { redirectTo: `${window.location.origin}/auth/callback` },
      });
      if (err) throw err;
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Sign-in failed.');
      setLoading(null);
    }
  };

  const handlePasskey = async () => {
    if (!emailValid) {
      setError('Enter a valid email first to use a passkey.');
      return;
    }
    setError(null);
    setLoading('passkey');
    try {
      await authenticateWithPasskey(email.trim());
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Passkey sign-in failed.');
    } finally {
      setLoading(null);
    }
  };

  const continueWithEmail = () => {
    if (!emailValid) {
      setError('Enter a valid email address.');
      return;
    }
    setError(null);
    setNotice(null);
    setStep('password');
  };

  const submitPassword = async () => {
    if (!supabase) {
      setError('Authentication is temporarily unavailable.');
      return;
    }
    if (password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }
    setError(null);
    setNotice(null);
    setLoading('email');
    try {
      if (mode === 'signup') {
        const { error: err } = await supabase.auth.signUp({
          email: email.trim(),
          password,
          options: { emailRedirectTo: `${window.location.origin}/auth/callback` },
        });
        if (err) throw err;
        setNotice('Check your inbox to confirm your email, then sign in.');
      } else {
        const { error: err } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        });
        if (err) throw err;
        onClose();
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Authentication failed.');
    } finally {
      setLoading(null);
    }
  };

  const inputStyle = {
    borderColor: 'var(--surface-border)',
    backgroundColor: 'var(--surface)',
    color: 'var(--text-main)',
  };

  return createPortal(
    <div className="fixed inset-0 z-[100] flex items-center justify-center overflow-y-auto p-4">
      <button
        type="button"
        aria-label="Close dialog"
        onClick={onClose}
        className="absolute inset-0 h-full w-full cursor-default backdrop-blur-md"
        style={{ backgroundColor: 'rgb(0 0 0 / 70%)' }}
      />
      <div
        className="relative w-full max-w-[440px] rounded-[22px] border p-8"
        style={{
          borderColor: 'var(--surface-border)',
          backgroundColor: 'var(--surface-elevated)',
          boxShadow: 'var(--shadow-lg)',
        }}
        role="dialog"
        aria-modal="true"
      >
        <button
          type="button"
          onClick={onClose}
          className="absolute end-5 top-5 flex h-8 w-8 items-center justify-center rounded-full border text-sm opacity-60 transition hover:opacity-100"
          style={{ borderColor: 'var(--surface-border)', color: 'var(--text-main)' }}
          aria-label="Close"
        >
          ✕
        </button>

        <h2
          className="text-[22px] font-semibold tracking-tight"
          style={{ color: 'var(--text-main)' }}
        >
          {mode === 'signup' ? 'Create your account' : 'Sign in or create an account'}
        </h2>
        <p className="mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
          {step === 'email'
            ? 'Use your Veralify account to access tracking, communities, live rooms, and coaches.'
            : mode === 'signup'
              ? `Set a password for ${email.trim()}.`
              : `Enter the password for ${email.trim()}.`}
        </p>

        {step === 'email' ? (
          <div className="mt-6 flex flex-col gap-4">
            <label className="flex flex-col gap-2">
              <span className="text-sm font-medium" style={{ color: 'var(--text-main)' }}>
                Email address
              </span>
              <input
                type="email"
                inputMode="email"
                placeholder="Enter your email address"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && continueWithEmail()}
                autoComplete="username webauthn"
                className="rounded-xl border px-4 py-3 text-sm outline-none transition focus:border-[color:var(--brand-primary)]"
                style={inputStyle}
              />
            </label>

            <button
              type="button"
              onClick={continueWithEmail}
              className="rounded-xl px-4 py-3 text-sm font-semibold transition hover:opacity-90"
              style={{ backgroundColor: 'var(--brand-primary)', color: '#ffffff' }}
            >
              Continue with email
            </button>

            <div className="my-1 text-center text-xs" style={{ color: 'var(--text-muted)' }}>
              or use one of these options
            </div>

            <div className="grid grid-cols-3 gap-3">
              <SocialTile
                label="Continue with Google"
                onClick={() => void oauth('google', 'google')}
                loading={loading === 'google'}
                disabled={busy}
              >
                <GoogleGlyph />
              </SocialTile>
              <SocialTile
                label="Continue with Apple"
                onClick={() => void oauth('apple', 'apple')}
                loading={loading === 'apple'}
                disabled={busy}
              >
                <AppleGlyph />
              </SocialTile>
              {canUsePasskey && (
                <SocialTile
                  label="Sign in with a passkey"
                  onClick={() => void handlePasskey()}
                  loading={loading === 'passkey'}
                  disabled={busy}
                >
                  <PasskeyGlyph />
                </SocialTile>
              )}
            </div>
          </div>
        ) : (
          <div className="mt-6 flex flex-col gap-4">
            <input
              type="password"
              placeholder={mode === 'signup' ? 'Create a password' : 'Password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && void submitPassword()}
              autoComplete={mode === 'signup' ? 'new-password' : 'current-password'}
              className="rounded-xl border px-4 py-3 text-sm outline-none transition focus:border-[color:var(--brand-primary)]"
              style={inputStyle}
            />

            <button
              type="button"
              disabled={busy}
              onClick={() => void submitPassword()}
              className="rounded-xl px-4 py-3 text-sm font-semibold transition hover:opacity-90 disabled:opacity-50"
              style={{ backgroundColor: 'var(--brand-primary)', color: '#ffffff' }}
            >
              {loading === 'email'
                ? 'Please wait…'
                : mode === 'signup'
                  ? 'Create account'
                  : 'Sign in'}
            </button>

            <div className="flex items-center justify-between text-xs">
              <button
                type="button"
                onClick={() => {
                  setStep('email');
                  setError(null);
                  setNotice(null);
                }}
                className="transition hover:opacity-100"
                style={{ color: 'var(--text-muted)' }}
              >
                ‹ Change email
              </button>
              <button
                type="button"
                onClick={() => {
                  setMode(mode === 'signin' ? 'signup' : 'signin');
                  setError(null);
                  setNotice(null);
                }}
                className="font-medium transition hover:opacity-90"
                style={{ color: 'var(--brand-primary)' }}
              >
                {mode === 'signin' ? 'Create an account' : 'I already have an account'}
              </button>
            </div>
          </div>
        )}

        {error && (
          <p className="mt-4 text-xs" style={{ color: 'var(--chip-text)' }}>
            {error}
          </p>
        )}
        {notice && (
          <p className="mt-4 text-xs" style={{ color: '#7ee787' }}>
            {notice}
          </p>
        )}

        <div
          className="mt-7 border-t pt-5 text-center text-xs leading-relaxed"
          style={{ borderColor: 'var(--surface-border)', color: 'var(--text-muted)' }}
        >
          By signing in or creating an account, you agree with our{' '}
          <a href="/terms" className="underline" style={{ color: 'var(--brand-primary)' }}>
            Terms &amp; Conditions
          </a>{' '}
          and{' '}
          <a href="/privacy" className="underline" style={{ color: 'var(--brand-primary)' }}>
            Privacy Statement
          </a>
          .
        </div>
      </div>
    </div>,
    document.body,
  );
}

function SocialTile({
  children,
  label,
  onClick,
  loading,
  disabled,
}: {
  children: React.ReactNode;
  label: string;
  onClick: () => void;
  loading: boolean;
  disabled: boolean;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={onClick}
      disabled={disabled}
      className="flex h-14 items-center justify-center rounded-xl border transition hover:opacity-90 disabled:opacity-50"
      style={{ borderColor: 'var(--surface-border)', backgroundColor: 'var(--surface)' }}
    >
      {loading ? <span className="text-xs opacity-70">…</span> : children}
    </button>
  );
}

function GoogleGlyph() {
  return (
    <svg width="22" height="22" viewBox="0 0 48 48" aria-hidden="true">
      <path
        fill="#EA4335"
        d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"
      />
      <path
        fill="#4285F4"
        d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"
      />
      <path
        fill="#FBBC05"
        d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"
      />
      <path
        fill="#34A853"
        d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"
      />
    </svg>
  );
}

function AppleGlyph() {
  return (
    <svg
      width="20"
      height="24"
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
      style={{ color: 'var(--text-main)' }}
    >
      <path d="M16.36 12.9c-.02-2.02 1.65-2.99 1.72-3.04-.94-1.37-2.4-1.56-2.92-1.58-1.24-.13-2.42.73-3.05.73-.63 0-1.6-.71-2.63-.69-1.35.02-2.6.79-3.29 2-1.4 2.43-.36 6.03 1 8 .67.97 1.46 2.05 2.5 2.01 1-.04 1.38-.65 2.59-.65 1.21 0 1.55.65 2.61.63 1.08-.02 1.76-.98 2.42-1.96.76-1.12 1.08-2.2 1.09-2.26-.02-.01-2.09-.8-2.11-3.17zM14.4 6.86c.55-.67.92-1.6.82-2.53-.79.03-1.75.53-2.32 1.19-.51.59-.96 1.54-.84 2.44.88.07 1.79-.45 2.34-1.1z" />
    </svg>
  );
}

function PasskeyGlyph() {
  return (
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      style={{ color: 'var(--text-main)' }}
    >
      <circle cx="8" cy="8" r="4" stroke="currentColor" strokeWidth="1.8" />
      <path
        d="M8 12c-2.5 0-4 1.8-4 4v3h8"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      <path
        d="M16 10.5v6m0 0 1.5 1.5M16 16.5l-1.5 1.5M16 10.5a2 2 0 1 1 0 4 2 2 0 0 1 0-4z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
