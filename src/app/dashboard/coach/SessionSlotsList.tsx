import { StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { EmptyState } from '@components/member/EmptyState';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { CalendarPlus } from 'lucide-react';

type CoachSession = {
  id: string;
  title: string;
  session_type: string;
  scheduled_at: string;
  duration_minutes: number;
  status: string;
};

/** Streams behind `<Suspense>` on the coach portal page — see page.tsx. */
export async function SessionSlotsList({ coachId }: { coachId: string }) {
  const supabase = await createSupabaseServerClient();
  const { data: sessions } = await supabase
    .from('coach_sessions')
    .select('id, title, session_type, scheduled_at, duration_minutes, status')
    .eq('coach_id', coachId)
    .order('scheduled_at', { ascending: true })
    .limit(20);
  const sessionRows = (sessions ?? []) as CoachSession[];

  if (!sessionRows.length) {
    return (
      <EmptyState
        icon={<CalendarPlus className="h-6 w-6" strokeWidth={1.75} />}
        title="No session slots yet"
        body="Publish a slot below so it appears on your public coach profile for booking."
      />
    );
  }

  return (
    <StaggerGroup className="mt-4 divide-y divide-vera-border">
      {sessionRows.map((session) => (
        <StaggerItem
          key={session.id}
          as="article"
          className="flex items-center justify-between gap-3 py-3"
        >
          <div>
            <p className="font-semibold">{session.title}</p>
            <p className="text-sm text-vera-fg-muted">
              {new Date(session.scheduled_at).toLocaleString()} · {session.duration_minutes} min ·{' '}
              {session.session_type}
            </p>
          </div>
          <span className="rounded-full bg-vera-primary/15 px-3 py-1 text-xs font-semibold text-vera-primary">
            {session.status}
          </span>
        </StaggerItem>
      ))}
    </StaggerGroup>
  );
}
