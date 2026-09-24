import { Banner } from '@components/generic/Banner';
import { LocalDateTime } from '@components/generic/LocalDateTime';
import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import {
  Card,
  ErrorMessage,
  inputClass,
  PageHeader,
  SubmitButton,
} from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { Link2 } from 'lucide-react';
import type { Metadata } from 'next';
import { connectProviderAction, setAutoSyncAction, setSyncScopeAction } from './actions';
import { DisconnectButton } from './components/DisconnectButton';
import { MappingEditor } from './components/MappingEditor';
import {
  CALLBACK_ERRORS,
  CONNECTION_COLUMNS,
  type ConnectionRow,
  type MappingRow,
  PROVIDER_INFO,
  PROVIDERS,
  type ProviderOptions,
  STATUS_LABEL,
  untyped,
} from './lib';

export const metadata: Metadata = { title: 'Integrations · Money' };

type SearchParams = Promise<{
  status?: string;
  provider?: string;
  companies?: string;
  error?: string;
  saved?: string;
  map?: string;
}>;

const STATUS_TONE: Record<ConnectionRow['status'], string> = {
  active: 'border-vera-success/40 bg-vera-success/10 text-vera-success',
  needs_reauth: 'border-vera-warning/40 bg-vera-warning/10 text-vera-warning',
  revoked: 'border-vera-border bg-vera-bg-subtle text-vera-fg-muted',
  error: 'border-vera-danger/40 bg-vera-danger/10 text-vera-danger',
};

const PAGE_ERRORS: Record<string, string> = {
  save: 'We couldn’t save that change. Please try again.',
  invalid: 'That request wasn’t valid. Please try again.',
  connect: 'We couldn’t start the connection. Please try again in a moment.',
  disconnect: 'We couldn’t disconnect that integration. Please try again.',
};

function banner(
  params: Awaited<SearchParams>,
): { variant: 'success' | 'error'; message: string } | null {
  if (params.status === 'connected') {
    const count = Number(params.companies) || 1;
    return {
      variant: 'success',
      message:
        count > 1
          ? `Connected ${count} companies. They start paused so expenses are not sent to all of them — turn on sync for the right one and map its accounts.`
          : 'Connected. Map your accounts below so expenses land in the right place.',
    };
  }
  if (params.status === 'disconnected') {
    return { variant: 'success', message: 'Disconnected. Nothing more will be sent.' };
  }
  if (params.status === 'error') {
    return {
      variant: 'error',
      message: CALLBACK_ERRORS[params.error ?? ''] ?? CALLBACK_ERRORS.exchange,
    };
  }
  if (params.saved) return { variant: 'success', message: 'Saved.' };
  return null;
}

async function loadMappingEditor(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
  connection: ConnectionRow,
): Promise<{ options: ProviderOptions; mappings: MappingRow[] } | { error: string }> {
  if (connection.status !== 'active') {
    return { error: 'Reconnect this integration to edit its account mapping.' };
  }
  const [{ data: options, error }, { data: mappingRows }] = await Promise.all([
    supabase.functions.invoke<ProviderOptions>('accounting-accounts', {
      body: { connection_id: connection.id },
    }),
    untyped(supabase)
      .from('accounting_mappings')
      .select('kind, local_key, external_id, external_name')
      .eq('connection_id', connection.id),
  ]);
  if (error || !options) {
    return {
      error: `We couldn’t load the accounts from ${PROVIDER_INFO[connection.provider].name}. Try again, or reconnect if this keeps happening.`,
    };
  }
  return { options, mappings: (mappingRows ?? []) as MappingRow[] };
}

export default async function IntegrationsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: rows } = await untyped(supabase)
    .from('accounting_connections')
    .select(CONNECTION_COLUMNS)
    .eq('user_id', user.id)
    .order('created_at', { ascending: true });
  const connections = (rows ?? []) as ConnectionRow[];
  const mapping = connections.find((c) => c.id === params.map) ?? null;
  const editor = mapping ? await loadMappingEditor(supabase, mapping) : null;
  const notice = banner(params);

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Integrations"
        body="Send business expenses, with their receipts, to your accounting software as you record them."
      />
      {notice ? <Banner variant={notice.variant} message={notice.message} /> : null}
      <ErrorMessage message={params.error ? PAGE_ERRORS[params.error] : undefined} />

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">Your connections</h2>
            {connections.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {connections.map((connection) => (
                  <StaggerItem key={connection.id} as="div" className="grid gap-3 py-4">
                    <ConnectionSummary connection={connection} />
                    <ConnectionControls connection={connection} />
                  </StaggerItem>
                ))}
              </StaggerGroup>
            ) : (
              <EmptyState
                icon={<Link2 className="h-6 w-6" strokeWidth={1.75} />}
                title="No integrations yet"
                body="Connect your accounting software and business expenses will be sent there automatically."
              />
            )}
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.05}>
          <Card>
            <h2 className="text-xl font-bold">Connect</h2>
            <p className="mt-1 text-sm text-vera-fg-muted">
              You’ll sign in with the provider and choose what Veralify may access.
            </p>
            <div className="mt-4 grid gap-3">
              {PROVIDERS.map((provider) => (
                <form
                  key={provider}
                  action={connectProviderAction}
                  className="flex items-center justify-between gap-3 rounded-vera-md border border-vera-border p-4"
                >
                  <input type="hidden" name="provider" value={provider} />
                  <div>
                    <p className="font-semibold">{PROVIDER_INFO[provider].name}</p>
                    <p className="text-sm text-vera-fg-muted">{PROVIDER_INFO[provider].blurb}</p>
                  </div>
                  <SubmitButton pendingLabel="Opening…">Connect</SubmitButton>
                </form>
              ))}
            </div>
          </Card>
        </Reveal>
      </div>

      {mapping && editor ? (
        <div className="mt-6">
          {'error' in editor ? (
            <ErrorMessage message={editor.error} />
          ) : (
            <MappingEditor
              connection={mapping}
              options={editor.options}
              mappings={editor.mappings}
            />
          )}
        </div>
      ) : null}
    </main>
  );
}

function ConnectionSummary({ connection }: { connection: ConnectionRow }) {
  const paused = connection.status === 'active' && !connection.auto_sync;
  return (
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div>
        <p className="font-semibold">
          {connection.company_name || PROVIDER_INFO[connection.provider].name}
        </p>
        <p className="text-sm text-vera-fg-muted">
          {PROVIDER_INFO[connection.provider].name}
          {connection.home_currency ? ` · ${connection.home_currency}` : ''}
          {' · '}
          {connection.sync_scope === 'business' ? 'Business expenses' : 'Personal expenses'}
        </p>
        <p className="mt-1 text-sm text-vera-fg-muted">
          {connection.last_synced_at ? (
            <>
              Last sync <LocalDateTime iso={connection.last_synced_at} />
            </>
          ) : (
            'Not synced yet'
          )}
        </p>
        {connection.last_error && connection.status !== 'revoked' ? (
          <p className="mt-1 text-sm text-vera-danger">{connection.last_error}</p>
        ) : null}
      </div>
      <span
        className={`rounded-full border px-3 py-1 text-xs font-semibold ${
          paused ? STATUS_TONE.revoked : STATUS_TONE[connection.status]
        }`}
      >
        {paused ? 'Paused' : STATUS_LABEL[connection.status]}
      </span>
    </div>
  );
}

function ConnectionControls({ connection }: { connection: ConnectionRow }) {
  const name = connection.company_name || PROVIDER_INFO[connection.provider].name;
  if (connection.status !== 'active') {
    // Reconnecting the same company reuses this row, its mapping and its links.
    return (
      <form action={connectProviderAction} className="flex flex-wrap items-center gap-3">
        <input type="hidden" name="provider" value={connection.provider} />
        <SubmitButton pendingLabel="Opening…">Reconnect</SubmitButton>
      </form>
    );
  }
  return (
    <div className="flex flex-wrap items-center gap-3">
      <a className="btn-apple-secondary" href={`?map=${connection.id}#mapping`}>
        Map accounts
      </a>
      <form action={setAutoSyncAction}>
        <input type="hidden" name="id" value={connection.id} />
        <input type="hidden" name="auto_sync" value={connection.auto_sync ? 'false' : 'true'} />
        <button type="submit" className="btn-apple-secondary">
          {connection.auto_sync ? 'Pause sync' : 'Resume sync'}
        </button>
      </form>
      <form action={setSyncScopeAction} className="flex items-center gap-2">
        <input type="hidden" name="id" value={connection.id} />
        <label className="sr-only" htmlFor={`scope-${connection.id}`}>
          Which expenses to send
        </label>
        <select
          id={`scope-${connection.id}`}
          name="sync_scope"
          defaultValue={connection.sync_scope}
          className={inputClass}
        >
          <option value="business">Business expenses</option>
          <option value="personal">Personal expenses</option>
        </select>
        <button type="submit" className="btn-apple-secondary">
          Save
        </button>
      </form>
      <DisconnectButton id={connection.id} name={name} />
    </div>
  );
}
