import { activeBrand } from '@config/brands';
import { PrivyProvider, usePrivy } from '@privy-io/react-auth';
import { useEffect, useState } from 'react';
import { PRIVY_APP_ID, privyConfig } from './privyConfig';
import { getDisplayIdentity, syncPrivyUserToSupabase } from './userSync';

type AuthWidgetProps = {
  variant?: 'navbar' | 'hero';
};

const AuthWidgetInner = ({ variant = 'navbar' }: AuthWidgetProps) => {
  const { authenticated, ready, user, login, logout } = usePrivy();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!ready || !authenticated || !user) {
      return;
    }

    void syncPrivyUserToSupabase({ user });
  }, [authenticated, ready, user]);

  const displayIdentity = user ? getDisplayIdentity(user) : null;

  const startLogin = async () => {
    try {
      setError(null);
      login({ loginMethods: ['google'] });
    } catch (loginError) {
      const message = loginError instanceof Error ? loginError.message : 'Sign in failed.';
      setError(message);
    }
  };

  if (variant === 'hero') {
    return (
      <div className="flex flex-wrap items-center gap-3">
        <button
          type="button"
          className="matrix-text inline-flex h-[46px] items-center rounded-xl border px-6 font-semibold"
          style={{
            borderColor: activeBrand.theme.authAccent,
            color: '#f3ddad',
            backgroundColor: '#141414',
          }}
          onClick={() => void startLogin()}
        >
          {authenticated ? 'Manage Secure Access' : 'Sign In'}
        </button>
        {authenticated && displayIdentity && (
          <span className="matrix-text text-sm" style={{ color: 'var(--text-muted)' }}>
            Welcome, {displayIdentity}
          </span>
        )}
        {error && (
          <span className="matrix-text text-xs" style={{ color: '#ffb5a8' }}>
            {error}
          </span>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-col items-end gap-2">
      {authenticated && displayIdentity ? (
        <div className="flex items-center gap-2">
          <span
            className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
            style={{
              borderColor: activeBrand.theme.authAccent,
              color: '#f3ddad',
              backgroundColor: '#141414',
            }}
          >
            {displayIdentity}
          </span>
          <button
            type="button"
            className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
            style={{ borderColor: 'var(--surface-border)' }}
            onClick={() => logout()}
          >
            Sign Out
          </button>
        </div>
      ) : (
        <button
          type="button"
          className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
          style={{
            borderColor: activeBrand.theme.authAccent,
            color: '#f3ddad',
            backgroundColor: '#141414',
          }}
          onClick={() => void startLogin()}
        >
          Sign In
        </button>
      )}

      {error && <span className="text-xs text-[#ffb5a8]">{error}</span>}
    </div>
  );
};

export function AuthWidget(props: AuthWidgetProps) {
  if (!PRIVY_APP_ID) {
    return (
      <button
        type="button"
        className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
        style={{ borderColor: 'var(--surface-border)', color: 'var(--text-muted)' }}
        disabled
      >
        Auth unavailable
      </button>
    );
  }

  return (
    <PrivyProvider appId={PRIVY_APP_ID} config={privyConfig}>
      <AuthWidgetInner {...props} />
    </PrivyProvider>
  );
}
