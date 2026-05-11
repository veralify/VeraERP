import { auth } from '@components/auth/firebaseConfig';
import { activeBrand } from '@config/brands';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { useCallback, useEffect, useState } from 'react';

type Campaign = {
  id: string;
  subject: string;
  status: string;
  target_count: number;
  sent_count: number;
  failed_count: number;
  created_at: string;
};

type BootstrapData = {
  subscribedCount: number;
  campaigns: Campaign[];
};

const SUPABASE_URL = import.meta.env.PUBLIC_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

const postAction = async <T,>(url: string, payload: Record<string, unknown>) => {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error('Missing PUBLIC_SUPABASE_URL or PUBLIC_SUPABASE_ANON_KEY.');
  }
  const response = await fetch(`${SUPABASE_URL}/functions/v1/${url}`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_ANON_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const json = (await response.json().catch(() => null)) as { error?: string; data?: T } | null;
  if (!response.ok || !json) {
    throw new Error(json?.error || `Request failed (HTTP ${response.status})`);
  }
  if (json.error) {
    throw new Error(json.error);
  }
  return json.data as T;
};

const NewsletterControlInner = () => {
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [bootstrap, setBootstrap] = useState<BootstrapData | null>(null);
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const twentyUrl = import.meta.env.PUBLIC_TWENTY_URL || 'https://crm.veralify.com';

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  const reload = useCallback(async (userId: string) => {
    setLoading(true);
    setError(null);
    try {
      const newsletterData = await postAction<BootstrapData>('vera-newsletter-api', {
        action: 'dashboard_bootstrap',
        privyUserId: userId,
      });
      setBootstrap(newsletterData);
    } catch (reloadError) {
      setError(
        reloadError instanceof Error ? reloadError.message : 'Failed to load dashboard controls.',
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!user) {
      return;
    }
    void reload(user.uid);
  }, [user, reload]);

  const sendCampaign = async () => {
    if (!user) {
      return;
    }
    if (!subject.trim() || !body.trim()) {
      setError('Subject and body are required.');
      return;
    }

    setSending(true);
    setError(null);
    try {
      await postAction('vera-newsletter-api', {
        action: 'send_campaign',
        privyUserId: user.uid,
        brand: activeBrand.id,
        subject: subject.trim(),
        body: body.trim(),
      });
      setSubject('');
      setBody('');
      await reload(user.uid);
    } catch (sendError) {
      setError(sendError instanceof Error ? sendError.message : 'Failed to send campaign.');
    } finally {
      setSending(false);
    }
  };

  const handleLogout = async () => {
    try {
      await signOut(auth);
      setUser(null);
    } catch (err) {
      setError('Failed to sign out');
    }
  };

  if (loading) {
    return (
      <section className="mx-auto mt-10 w-full max-w-5xl rounded-2xl border p-8">
        <p className="matrix-text text-sm" style={{ color: 'var(--text-muted)' }}>
          Loading authentication...
        </p>
      </section>
    );
  }

  if (!user || !user.emailVerified) {
    return (
      <section className="mx-auto mt-10 w-full max-w-5xl rounded-2xl border p-8">
        <h1 className="matrix-heading text-3xl font-semibold">Admin Dashboard</h1>
        <p className="matrix-text mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
          Sign in to control newsletter and CRM.
        </p>
        <p className="matrix-text mt-4 text-xs" style={{ color: '#ffb5a8' }}>
          {user && !user.emailVerified ? 'Please verify your email to access the dashboard.' : ''}
        </p>
      </section>
    );
  }

  return (
    <section className="mx-auto mt-10 w-full max-w-5xl rounded-2xl border p-8">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="matrix-heading text-3xl font-semibold">Admin Dashboard</h1>
          <p className="matrix-text mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
            Signed in as {user.email}
          </p>
        </div>
        <button
          type="button"
          className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
          style={{ borderColor: 'var(--surface-border)' }}
          onClick={handleLogout}
        >
          Sign Out
        </button>
      </div>

      {error && (
        <p className="mt-4 text-sm" style={{ color: '#ffb5a8' }}>
          {error}
        </p>
      )}

      {loading && (
        <p className="mt-4 text-sm" style={{ color: 'var(--text-muted)' }}>
          Loading dashboard...
        </p>
      )}

      <div className="mt-8 rounded-2xl border p-5" style={{ borderColor: 'var(--surface-border)' }}>
        <h2 className="matrix-heading text-xl font-semibold">CRM</h2>
        <p className="matrix-text mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
          We switched to Twenty CRM. Use it for all customer pipelines and ticket operations.
        </p>
        <a
          href={twentyUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="matrix-text mt-4 inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
          style={{ borderColor: '#c6a15b', color: '#f3ddad', backgroundColor: '#141414' }}
        >
          Open Twenty CRM
        </a>
      </div>

      <div className="mt-8 rounded-2xl border p-5" style={{ borderColor: 'var(--surface-border)' }}>
        <h2 className="matrix-heading text-xl font-semibold">Send Campaign</h2>
        <p className="matrix-text mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
          Active list: {bootstrap?.subscribedCount ?? 0} subscribed contacts ({activeBrand.id})
        </p>
        <div className="mt-4 space-y-3">
          <input
            value={subject}
            onChange={(event) => setSubject(event.target.value)}
            placeholder="Email subject"
            className="w-full rounded-xl border px-4 py-3 text-sm"
            style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
          />
          <textarea
            value={body}
            onChange={(event) => setBody(event.target.value)}
            placeholder="Write your email message..."
            className="min-h-32 w-full rounded-xl border px-4 py-3 text-sm"
            style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
          />
        </div>
        <button
          type="button"
          className="matrix-text mt-4 inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
          style={{ borderColor: '#c6a15b', color: '#f3ddad', backgroundColor: '#141414' }}
          onClick={() => void sendCampaign()}
          disabled={sending}
        >
          {sending ? 'Sending campaign...' : 'Send to Email List'}
        </button>
      </div>

      <div className="mt-8">
        <h2 className="matrix-heading text-xl font-semibold">Recent Campaigns</h2>
        <div className="mt-3 space-y-2">
          {(bootstrap?.campaigns || []).map((campaign) => (
            <article
              key={campaign.id}
              className="rounded-xl border px-4 py-3 text-sm"
              style={{ borderColor: 'var(--surface-border)' }}
            >
              <p className="matrix-text text-xs" style={{ color: 'var(--text-muted)' }}>
                {new Date(campaign.created_at).toLocaleString()}
              </p>
              <p className="matrix-heading mt-1 text-base">{campaign.subject}</p>
              <p className="matrix-text mt-1 text-xs" style={{ color: 'var(--text-muted)' }}>
                Status: {campaign.status} · Sent {campaign.sent_count}/{campaign.target_count} ·
                Failed {campaign.failed_count}
              </p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
};

export function NewsletterControl() {
  return <NewsletterControlInner />;
}
