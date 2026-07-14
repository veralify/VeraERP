import { activeBrand } from '@config/brands';

import { useState } from 'react';

type AuthWidgetProps = {
  variant?: 'navbar' | 'hero';
};

const AuthWidgetInner = ({ variant = 'navbar' }: AuthWidgetProps) => {
  const [error, setError] = useState<string | null>(null);
  const [authenticated] = useState(false);

  const startLogin = async () => {
    try {
      setError(null);
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
          {authenticated ? 'Manage Secure Access' : 'Sign In / Register'}
        </button>
 
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
      {error && <span className="text-xs text-[#ffb5a8]">{error}</span>}
    </div>
  );
};

export function AuthWidget(props: AuthWidgetProps) {
  return <AuthWidgetInner {...props} />;
}
