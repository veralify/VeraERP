import {
  PRIVY_APP_ID,
  privyConfig,
  SUPABASE_ANON_KEY,
  SUPABASE_URL,
} from '@components/auth/privyConfig';
import { getDisplayIdentity, syncPrivyUserToSupabase } from '@components/auth/userSync';
import { PrivyProvider, usePrivy } from '@privy-io/react-auth';
import { useCallback, useEffect, useMemo, useState } from 'react';

type VeraUser = {
  id: string;
  display_name: string | null;
  email: string | null;
  account_identifier: string;
  role: 'user' | 'admin';
};

type CrmNote = {
  id: string;
  ticket_id: string;
  body: string;
  created_at: string;
  author_user_id: string;
};

type CrmAction = {
  id: string;
  ticket_id: string;
  title: string;
  details: string | null;
  status: 'pending' | 'in_progress' | 'done';
  due_at: string | null;
  owner_user_id: string | null;
};

type CrmTicket = {
  id: string;
  title: string;
  description: string | null;
  status: 'open' | 'in_progress' | 'resolved' | 'closed';
  priority: 'low' | 'normal' | 'high' | 'critical';
  asset_id: string | null;
  subject_user_id: string;
  assigned_to: string | null;
  created_at: string;
  notes: CrmNote[];
  actions: CrmAction[];
};

type BootstrapResponse = {
  user: VeraUser;
  users: VeraUser[];
  tickets: CrmTicket[];
};

const postAdminAction = async <T,>(payload: Record<string, unknown>) => {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error('Missing PUBLIC_SUPABASE_URL or PUBLIC_SUPABASE_ANON_KEY.');
  }

  const response = await fetch(`${SUPABASE_URL}/functions/v1/vera-admin-crm`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      apikey: SUPABASE_ANON_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const json = (await response.json().catch(() => null)) as { error?: string; data?: T } | null;
  if (!response.ok || !json) {
    throw new Error(json?.error || `Admin request failed (HTTP ${response.status})`);
  }

  if (json.error) {
    throw new Error(json.error);
  }

  return json.data as T;
};

const AdminCRMInner = () => {
  const { authenticated, ready, user, login, logout } = usePrivy();

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [forbidden, setForbidden] = useState(false);
  const [bootstrap, setBootstrap] = useState<BootstrapResponse | null>(null);

  const [ticketTitle, setTicketTitle] = useState('');
  const [ticketDescription, setTicketDescription] = useState('');
  const [ticketPriority, setTicketPriority] = useState<CrmTicket['priority']>('normal');
  const [ticketSubjectUserId, setTicketSubjectUserId] = useState('');
  const [ticketAssetId, setTicketAssetId] = useState('');

  const identityLabel = user ? getDisplayIdentity(user) : null;

  const usersById = useMemo(() => {
    const map = new Map<string, VeraUser>();
    for (const crmUser of bootstrap?.users || []) {
      map.set(crmUser.id, crmUser);
    }
    return map;
  }, [bootstrap?.users]);

  const reload = useCallback(async () => {
    if (!user?.id) {
      return;
    }

    setLoading(true);
    setError(null);
    setForbidden(false);

    try {
      const data = await postAdminAction<BootstrapResponse>({
        action: 'bootstrap',
        privyUserId: user.id,
      });
      setBootstrap(data);
    } catch (requestError) {
      const message = requestError instanceof Error ? requestError.message : 'Failed to load CRM.';
      if (/not authorized/i.test(message)) {
        setForbidden(true);
      } else {
        setError(message);
      }
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  useEffect(() => {
    if (!ready || !authenticated || !user) {
      return;
    }

    void syncPrivyUserToSupabase({ user });
    void reload();
  }, [authenticated, ready, user, reload]);

  const createTicket = async () => {
    if (!user?.id) {
      return;
    }
    if (!ticketTitle.trim() || !ticketSubjectUserId) {
      setError('Title and subject user are required.');
      return;
    }

    setError(null);
    try {
      await postAdminAction({
        action: 'create_ticket',
        privyUserId: user.id,
        title: ticketTitle.trim(),
        description: ticketDescription.trim() || null,
        priority: ticketPriority,
        subjectUserId: ticketSubjectUserId,
        assetId: ticketAssetId.trim() || null,
      });
      setTicketTitle('');
      setTicketDescription('');
      setTicketAssetId('');
      await reload();
    } catch (createError) {
      const message =
        createError instanceof Error ? createError.message : 'Failed to create ticket.';
      setError(message);
    }
  };

  const updateTicketStatus = async (ticketId: string, status: CrmTicket['status']) => {
    if (!user?.id) {
      return;
    }
    try {
      await postAdminAction({
        action: 'update_ticket_status',
        privyUserId: user.id,
        ticketId,
        status,
      });
      await reload();
    } catch (updateError) {
      const message =
        updateError instanceof Error ? updateError.message : 'Failed to update ticket.';
      setError(message);
    }
  };

  const addNote = async (ticketId: string, body: string) => {
    if (!user?.id || !body.trim()) {
      return;
    }
    try {
      await postAdminAction({
        action: 'add_note',
        privyUserId: user.id,
        ticketId,
        body: body.trim(),
      });
      await reload();
    } catch (noteError) {
      const message = noteError instanceof Error ? noteError.message : 'Failed to add note.';
      setError(message);
    }
  };

  const addAction = async (ticketId: string, title: string) => {
    if (!user?.id || !title.trim()) {
      return;
    }
    try {
      await postAdminAction({
        action: 'add_action',
        privyUserId: user.id,
        ticketId,
        title: title.trim(),
      });
      await reload();
    } catch (actionError) {
      const message = actionError instanceof Error ? actionError.message : 'Failed to add action.';
      setError(message);
    }
  };

  const updateActionStatus = async (actionId: string, status: CrmAction['status']) => {
    if (!user?.id) {
      return;
    }
    try {
      await postAdminAction({
        action: 'update_action_status',
        privyUserId: user.id,
        actionId,
        status,
      });
      await reload();
    } catch (updateError) {
      const message =
        updateError instanceof Error ? updateError.message : 'Failed to update action.';
      setError(message);
    }
  };

  if (!ready || !authenticated || !user) {
    return (
      <section className="mx-auto mt-10 w-full max-w-6xl rounded-2xl border p-8">
        <h1 className="matrix-heading text-3xl font-semibold">Admin CRM</h1>
        <p className="matrix-text mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
          Sign in to access dashboard controls.
        </p>
        <button
          type="button"
          className="matrix-text mt-6 inline-flex rounded-xl border px-5 py-2 text-sm font-semibold"
          style={{ borderColor: '#c6a15b', color: '#f3ddad', backgroundColor: '#141414' }}
          onClick={() => login()}
        >
          Sign In
        </button>
      </section>
    );
  }

  return (
    <section className="mx-auto mt-10 w-full max-w-6xl rounded-2xl border p-8">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="matrix-heading text-3xl font-semibold">Admin CRM</h1>
          <p className="matrix-text mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
            Signed in as {identityLabel}
          </p>
        </div>
        <button
          type="button"
          className="matrix-text inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
          style={{ borderColor: 'var(--surface-border)' }}
          onClick={() => logout()}
        >
          Sign Out
        </button>
      </div>

      {forbidden && (
        <p className="mt-4 text-sm" style={{ color: '#ffb5a8' }}>
          Not authorized: your user role is not admin.
        </p>
      )}
      {error && !forbidden && (
        <p className="mt-4 text-sm" style={{ color: '#ffb5a8' }}>
          {error}
        </p>
      )}
      {loading && (
        <p className="mt-4 text-sm" style={{ color: 'var(--text-muted)' }}>
          Loading CRM...
        </p>
      )}

      {!forbidden && bootstrap && (
        <>
          <div
            className="mt-8 rounded-2xl border p-5"
            style={{ borderColor: 'var(--surface-border)' }}
          >
            <h2 className="matrix-heading text-xl font-semibold">Create Ticket</h2>
            <div className="mt-4 grid gap-3 md:grid-cols-2">
              <input
                value={ticketTitle}
                onChange={(event) => setTicketTitle(event.target.value)}
                placeholder="Ticket title"
                className="rounded-xl border px-4 py-3 text-sm"
                style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
              />
              <select
                value={ticketSubjectUserId}
                onChange={(event) => setTicketSubjectUserId(event.target.value)}
                className="rounded-xl border px-4 py-3 text-sm"
                style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
              >
                <option value="">Select subject user</option>
                {bootstrap.users.map((crmUser) => (
                  <option key={crmUser.id} value={crmUser.id}>
                    {crmUser.display_name || crmUser.email || crmUser.id.slice(0, 10)}
                  </option>
                ))}
              </select>
              <select
                value={ticketPriority}
                onChange={(event) => setTicketPriority(event.target.value as CrmTicket['priority'])}
                className="rounded-xl border px-4 py-3 text-sm"
                style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
              >
                <option value="low">Low</option>
                <option value="normal">Normal</option>
                <option value="high">High</option>
                <option value="critical">Critical</option>
              </select>
              <input
                value={ticketAssetId}
                onChange={(event) => setTicketAssetId(event.target.value)}
                placeholder="Asset ID (optional)"
                className="rounded-xl border px-4 py-3 text-sm"
                style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
              />
            </div>
            <textarea
              value={ticketDescription}
              onChange={(event) => setTicketDescription(event.target.value)}
              placeholder="Describe the case"
              className="mt-3 min-h-24 w-full rounded-xl border px-4 py-3 text-sm"
              style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
            />
            <button
              type="button"
              className="matrix-text mt-4 inline-flex rounded-xl border px-4 py-2 text-xs font-semibold"
              style={{ borderColor: '#c6a15b', color: '#f3ddad', backgroundColor: '#141414' }}
              onClick={() => void createTicket()}
            >
              Create Ticket
            </button>
          </div>

          <div className="mt-8 space-y-4">
            {bootstrap.tickets.map((ticket) => (
              <TicketCard
                key={ticket.id}
                ticket={ticket}
                usersById={usersById}
                onUpdateStatus={updateTicketStatus}
                onAddNote={addNote}
                onAddAction={addAction}
                onUpdateActionStatus={updateActionStatus}
              />
            ))}
          </div>
        </>
      )}
    </section>
  );
};

const TicketCard = (props: {
  ticket: CrmTicket;
  usersById: Map<string, VeraUser>;
  onUpdateStatus: (ticketId: string, status: CrmTicket['status']) => Promise<void>;
  onAddNote: (ticketId: string, body: string) => Promise<void>;
  onAddAction: (ticketId: string, title: string) => Promise<void>;
  onUpdateActionStatus: (actionId: string, status: CrmAction['status']) => Promise<void>;
}) => {
  const [noteBody, setNoteBody] = useState('');
  const [actionTitle, setActionTitle] = useState('');

  const subjectUser = props.usersById.get(props.ticket.subject_user_id);

  return (
    <article className="rounded-2xl border p-5" style={{ borderColor: 'var(--surface-border)' }}>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="matrix-heading text-lg font-semibold">{props.ticket.title}</h3>
          <p className="matrix-text mt-1 text-xs" style={{ color: 'var(--text-muted)' }}>
            Subject: {subjectUser?.display_name || subjectUser?.email || 'Unknown user'}
          </p>
        </div>
        <select
          value={props.ticket.status}
          onChange={(event) =>
            void props.onUpdateStatus(
              event.currentTarget.value ? props.ticket.id : props.ticket.id,
              event.currentTarget.value as CrmTicket['status'],
            )
          }
          className="rounded-xl border px-3 py-2 text-xs"
          style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
        >
          <option value="open">Open</option>
          <option value="in_progress">In Progress</option>
          <option value="resolved">Resolved</option>
          <option value="closed">Closed</option>
        </select>
      </div>

      {props.ticket.description && (
        <p className="matrix-text mt-3 text-sm" style={{ color: 'var(--text-muted)' }}>
          {props.ticket.description}
        </p>
      )}

      <div className="mt-4 grid gap-4 md:grid-cols-2">
        <div>
          <h4 className="matrix-text text-xs font-semibold uppercase tracking-wide">Notes</h4>
          <div className="mt-2 space-y-2">
            {props.ticket.notes.map((note) => (
              <p
                key={note.id}
                className="matrix-text rounded-lg border px-3 py-2 text-xs"
                style={{ borderColor: 'var(--surface-border)', color: 'var(--text-muted)' }}
              >
                {note.body}
              </p>
            ))}
          </div>
          <div className="mt-2 flex gap-2">
            <input
              value={noteBody}
              onChange={(event) => setNoteBody(event.target.value)}
              placeholder="Add note"
              className="w-full rounded-xl border px-3 py-2 text-xs"
              style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
            />
            <button
              type="button"
              className="matrix-text rounded-xl border px-3 py-2 text-xs"
              style={{ borderColor: 'var(--surface-border)' }}
              onClick={() => {
                void props.onAddNote(props.ticket.id, noteBody);
                setNoteBody('');
              }}
            >
              Add
            </button>
          </div>
        </div>

        <div>
          <h4 className="matrix-text text-xs font-semibold uppercase tracking-wide">Actions</h4>
          <div className="mt-2 space-y-2">
            {props.ticket.actions.map((action) => (
              <div
                key={action.id}
                className="flex items-center justify-between gap-2 rounded-lg border px-3 py-2"
                style={{ borderColor: 'var(--surface-border)' }}
              >
                <span className="matrix-text text-xs" style={{ color: 'var(--text-muted)' }}>
                  {action.title}
                </span>
                <select
                  value={action.status}
                  onChange={(event) =>
                    void props.onUpdateActionStatus(
                      action.id,
                      event.currentTarget.value as CrmAction['status'],
                    )
                  }
                  className="rounded-lg border px-2 py-1 text-xs"
                  style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
                >
                  <option value="pending">Pending</option>
                  <option value="in_progress">In Progress</option>
                  <option value="done">Done</option>
                </select>
              </div>
            ))}
          </div>
          <div className="mt-2 flex gap-2">
            <input
              value={actionTitle}
              onChange={(event) => setActionTitle(event.target.value)}
              placeholder="Add action"
              className="w-full rounded-xl border px-3 py-2 text-xs"
              style={{ borderColor: 'var(--surface-border)', backgroundColor: 'transparent' }}
            />
            <button
              type="button"
              className="matrix-text rounded-xl border px-3 py-2 text-xs"
              style={{ borderColor: 'var(--surface-border)' }}
              onClick={() => {
                void props.onAddAction(props.ticket.id, actionTitle);
                setActionTitle('');
              }}
            >
              Add
            </button>
          </div>
        </div>
      </div>
    </article>
  );
};

export function AdminCRM() {
  if (!PRIVY_APP_ID) {
    return (
      <section className="mx-auto mt-10 w-full max-w-6xl rounded-2xl border p-8">
        <p className="matrix-text text-sm" style={{ color: 'var(--text-muted)' }}>
          Authentication is unavailable. Set PUBLIC_PRIVY_APP_ID to use Admin CRM.
        </p>
      </section>
    );
  }

  return (
    <PrivyProvider appId={PRIVY_APP_ID} config={privyConfig}>
      <AdminCRMInner />
    </PrivyProvider>
  );
}
