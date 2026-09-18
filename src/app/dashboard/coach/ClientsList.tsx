import { StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { EmptyState } from '@components/member/EmptyState';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { Users } from 'lucide-react';

type CoachClient = {
  client_id: string;
  status: string;
  started_at: string;
  ended_at: string | null;
};

/** Streams behind `<Suspense>` on the coach portal page — see page.tsx. */
export async function ClientsList({ coachId }: { coachId: string }) {
  const supabase = await createSupabaseServerClient();
  const { data: clients } = await supabase
    .from('coach_clients')
    .select('client_id, status, started_at, ended_at')
    .eq('coach_id', coachId)
    .order('started_at', { ascending: false })
    .limit(25);
  const clientRows = (clients ?? []) as CoachClient[];

  if (!clientRows.length) {
    return (
      <EmptyState
        icon={<Users className="h-6 w-6" strokeWidth={1.75} />}
        title="No clients granted yet"
        body="Clients who grant coach access will appear here. No sample clients are shown."
      />
    );
  }

  return (
    <StaggerGroup className="mt-4 divide-y divide-vera-border">
      {clientRows.map((client) => (
        <StaggerItem key={client.client_id} as="article" className="py-4">
          <p className="font-semibold">Client {client.client_id}</p>
          <p className="text-sm text-vera-fg-muted">
            {client.status} · started {client.started_at.slice(0, 10)}
            {client.ended_at ? ` · ended ${client.ended_at.slice(0, 10)}` : ''}
          </p>
        </StaggerItem>
      ))}
    </StaggerGroup>
  );
}
