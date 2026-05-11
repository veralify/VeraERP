import { activeBrand } from '@config/brands';
import {
  createUserWithEmailAndPassword,
  sendEmailVerification,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { useEffect, useState } from 'react';
import { auth } from './firebaseConfig';

type AuthMode = 'login' | 'signup' | 'reset-password' | 'verify-email';
type AuthFormProps = {
  variant?: 'navbar' | 'hero';
};

export function AuthForm({ variant = 'navbar' }: AuthFormProps) {
  const [mode, setMode] = useState<AuthMode>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [showModal, setShowModal] = useState(false);
  const [verificationSent, setVerificationSent] = useState(false);

  useEffect(() => {
    const unsubscribe = auth.onAuthStateChanged((currentUser) => {
      setUser(currentUser);
    });
    return () => unsubscribe();
  }, []);

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const userCredential = await createUserWithEmailAndPassword(auth, email, password);
      const user = userCredential.user;

      if (user) {
        await sendEmailVerification(user);
        setVerificationSent(true);
        setMode('verify-email');
        setEmail('');
        setPassword('');
        setError('Verification email sent! Check your inbox.');
      }
    } catch (err: any) {
      const msg = err.code === 'auth/email-already-in-use' 
        ? 'Email already registered' 
        : err.message || 'Failed to create account';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      const user = userCredential.user;

      await user.reload();

      if (!user.emailVerified) {
        await signOut(auth);
        setError('Please verify your email. Check your inbox for a verification link.');
        setEmail('');
        setPassword('');
        setMode('verify-email');
        await sendEmailVerification(userCredential.user);
        return;
      }

      setEmail('');
      setPassword('');
      setShowModal(false);
    } catch (err: any) {
      const msg = err.code === 'auth/user-not-found'
        ? 'Email not found'
        : err.code === 'auth/wrong-password'
        ? 'Wrong password'
        : err.message || 'Failed to sign in';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      await sendPasswordResetEmail(auth, email, {
        url: `${window.location.origin}/?mode=login`,
      });
      setError(null);
      setEmail('');
      setMode('login');
      alert('Password reset email sent! Check your inbox and click the link to reset your password.');
    } catch (err: any) {
      const msg = err.code === 'auth/user-not-found'
        ? 'Email not found'
        : err.message || 'Failed to send reset email';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      await signOut(auth);
      setUser(null);
      setShowModal(false);
    } catch (err: any) {
      setError('Failed to sign out');
    }
  };

  const openModal = () => {
    setShowModal(true);
    setMode('login');
    setError(null);
  };

  const closeModal = () => {
    setShowModal(false);
    setError(null);
    setEmail('');
    setPassword('');
  };

  // Render button and modal separately
  const getButton = () => {
    if (user && user.emailVerified) {
      if (variant === 'navbar') {
        return (
          <div className="flex flex-col items-end gap-2">
            <div className="flex items-center gap-2">
              <span
                className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
                style={{
                  borderColor: activeBrand.theme.authAccent,
                  color: '#f3ddad',
                  backgroundColor: '#141414',
                }}
              >
                {user.email}
              </span>
              <button
                type="button"
                className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
                style={{ borderColor: 'var(--surface-border)' }}
                onClick={handleLogout}
              >
                Sign Out
              </button>
            </div>
          </div>
        );
      }

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
              onClick={handleLogout}
            >
              Sign Out
            </button>
            <span className="matrix-text text-sm" style={{ color: 'var(--text-muted)' }}>
              Welcome, {user.email}
            </span>
          </div>
        );
      }
    }

    // Not authenticated
    if (variant === 'navbar') {
      return (
        <button
          type="button"
          className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
          style={{
            borderColor: activeBrand.theme.authAccent,
            color: '#f3ddad',
            backgroundColor: '#141414',
          }}
          onClick={() => {
            console.log('Sign In clicked');
            openModal();
          }}
        >
          Sign In
        </button>
      );
    }

    if (variant === 'hero') {
      return (
        <button
          type="button"
          className="matrix-text inline-flex h-[46px] items-center rounded-xl border px-6 font-semibold"
          style={{
            borderColor: activeBrand.theme.authAccent,
            color: '#f3ddad',
            backgroundColor: '#141414',
          }}
          onClick={openModal}
        >
          Sign In / Register
        </button>
      );
    }

    return null;
  };

  return (
    <>
      {getButton()}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div
        className="relative w-full max-w-md rounded-lg p-6"
        style={{ backgroundColor: '#1a1a1a', border: `1px solid ${activeBrand.theme.authAccent}` }}
      >
        <button
          type="button"
          className="absolute right-4 top-4 text-gray-400 hover:text-white"
          onClick={closeModal}
        >
          ✕
        </button>

        {mode === 'login' && (
          <div>
            <h2 className="mb-4 text-xl font-bold text-white">Sign In</h2>
            <form onSubmit={handleSignIn} className="space-y-4">
              <input
                type="email"
                placeholder="Email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full rounded-lg bg-gray-800 px-4 py-2 text-white placeholder-gray-500"
                required
              />
              <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full rounded-lg bg-gray-800 px-4 py-2 text-white placeholder-gray-500"
                required
              />
              {error && <p className="text-sm text-red-400">{error}</p>}
              <button
                type="submit"
                disabled={loading}
                className="w-full rounded-lg font-semibold py-2"
                style={{
                  backgroundColor: activeBrand.theme.authAccent,
                  color: '#000',
                  opacity: loading ? 0.5 : 1,
                }}
              >
                {loading ? 'Signing In...' : 'Sign In'}
              </button>
            </form>
            <div className="mt-4 space-y-2 text-center text-sm">
              <button
                type="button"
                onClick={() => {
                  setMode('signup');
                  setError(null);
                }}
                className="block w-full text-gray-400 hover:text-white"
              >
                Don't have an account? Sign up
              </button>
              <button
                type="button"
                onClick={() => {
                  setMode('reset-password');
                  setError(null);
                }}
                className="block w-full text-gray-400 hover:text-white"
              >
                Forgot password?
              </button>
            </div>
          </div>
        )}

        {mode === 'signup' && (
          <div>
            <h2 className="mb-4 text-xl font-bold text-white">Create Account</h2>
            <form onSubmit={handleSignUp} className="space-y-4">
              <input
                type="email"
                placeholder="Email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full rounded-lg bg-gray-800 px-4 py-2 text-white placeholder-gray-500"
                required
              />
              <input
                type="password"
                placeholder="Password (min 6 characters)"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full rounded-lg bg-gray-800 px-4 py-2 text-white placeholder-gray-500"
                minLength={6}
                required
              />
              {error && <p className="text-sm text-red-400">{error}</p>}
              <button
                type="submit"
                disabled={loading}
                className="w-full rounded-lg font-semibold py-2"
                style={{
                  backgroundColor: activeBrand.theme.authAccent,
                  color: '#000',
                  opacity: loading ? 0.5 : 1,
                }}
              >
                {loading ? 'Creating Account...' : 'Sign Up'}
              </button>
            </form>
            <div className="mt-4 text-center text-sm">
              <button
                type="button"
                onClick={() => {
                  setMode('login');
                  setError(null);
                }}
                className="text-gray-400 hover:text-white"
              >
                Already have an account? Sign in
              </button>
            </div>
          </div>
        )}

        {mode === 'reset-password' && (
          <div>
            <h2 className="mb-4 text-xl font-bold text-white">Reset Password</h2>
            <form onSubmit={handleResetPassword} className="space-y-4">
              <input
                type="email"
                placeholder="Email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full rounded-lg bg-gray-800 px-4 py-2 text-white placeholder-gray-500"
                required
              />
              {error && <p className="text-sm text-red-400">{error}</p>}
              <button
                type="submit"
                disabled={loading}
                className="w-full rounded-lg font-semibold py-2"
                style={{
                  backgroundColor: activeBrand.theme.authAccent,
                  color: '#000',
                  opacity: loading ? 0.5 : 1,
                }}
              >
                {loading ? 'Sending Email...' : 'Send Reset Email'}
              </button>
            </form>
            <div className="mt-4 text-center text-sm">
              <button
                type="button"
                onClick={() => {
                  setMode('login');
                  setError(null);
                }}
                className="text-gray-400 hover:text-white"
              >
                Back to sign in
              </button>
            </div>
          </div>
        )}

        {mode === 'verify-email' && (
          <div>
            <h2 className="mb-4 text-xl font-bold text-white">Verify Your Email</h2>
            <p className="mb-4 text-gray-300">
              {verificationSent
                ? 'We sent a verification email to your inbox. Please check your email and click the verification link to complete your signup.'
                : 'Please verify your email before signing in. Check your inbox for a verification link.'}
            </p>
            <button
              type="button"
              onClick={() => {
                setMode('login');
                setError(null);
              }}
              className="w-full rounded-lg font-semibold py-2"
              style={{
                backgroundColor: activeBrand.theme.authAccent,
                color: '#000',
              }}
            >
              Back to Sign In
            </button>
          </div>
        )}
      </div>
    </div>
      )}
    </>
  );
}
