import { StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { EmptyState } from '@components/member/EmptyState';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { CalendarX2 } from 'lucide-react';

type AvailableSession = {
  id: string;
  title: string;
  description: string | null;
  session_type: string;
  scheduled_at: string;
  duration_minutes: number;
};

/**
 * Isolated as its own async server component so `coaches/[id]/page.tsx` can
 * stream the profile header immediately and let this list resolve behind a
 * `<Suspense>` skeleton.
 */
export async function SessionsList({
  coachId,
  hourlyRate,
  currency,
  isSignedIn,
}: {
  coachId: string;
  hourlyRate: number | null;
  currency: string;
  isSignedIn: boolean;
}) {
  const supabase = await createSupabaseServerClient();
  const { data: sessions } = await supabase
    .from('coach_sessions')
    .select('id, title, description, session_type, scheduled_at, duration_minutes')
    .eq('coach_id', coachId)
    .eq('status', 'available')
    .gt('scheduled_at', new Date().toISOString())
    .order('scheduled_at', { ascending: true })
    .limit(25);
  const availableSessions = (sessions ?? []) as AvailableSession[];

  if (!availableSessions.length) {
    return (
      <EmptyState
        icon={<CalendarX2 className="h-6 w-6" strokeWidth={1.75} />}
        title="No open sessions"
        body="This coach has no available session slots right now."
      />
    );
  }

  return (
    <StaggerGroup className="mt-4 divide-y divide-vera-border">
      {availableSessions.map((session) => {
        const priceLabel =
          hourlyRate != null
            ? `${currency.toUpperCase()} ${((hourlyRate * session.duration_minutes) / 60).toFixed(2)}`
            : null;
        return (
          <StaggerItem
            key={session.id}
            as="article"
            className="flex flex-wrap items-center justify-between gap-3 py-4"
          >
            <div>
              <p className="font-semibold">{session.title}</p>
              <p className="text-sm text-vera-fg-muted">
                {new Date(session.scheduled_at).toLocaleString()} · {session.duration_minutes} min ·{' '}
                {session.session_type}
                {priceLabel ? ` · ${priceLabel}` : ''}
              </p>
            </div>
            {isSignedIn ? (
              <form action="/api/stripe/bookings/checkout" method="POST">
                <input type="hidden" name="sessionId" value={session.id} />
                <button type="submit" className="btn-apple">
                  Book &amp; pay
                </button>
              </form>
            ) : (
              <a className="btn-apple-secondary" href="/?auth=required">
                Sign in to book
              </a>
            )}
          </StaggerItem>
        );
      })}
    </StaggerGroup>
  );
}
