import { LocalDateTime } from '@components/generic/LocalDateTime';
import { StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { Pager } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { CalendarClock } from 'lucide-react';

type Booking = {
  id: string;
  status: string;
  payment_method: string;
  booked_at: string;
  cancelled_at: string | null;
  coach_sessions: {
    title: string;
    scheduled_at: string;
    duration_minutes: number;
    session_type: string;
    status: string;
    client_id: string | null;
  } | null;
};
const pageSize = 10;

/** Streams behind `<Suspense>` on the coach portal page — see page.tsx. */
export async function BookingsList({ coachId, page }: { coachId: string; page: number }) {
  const from = (page - 1) * pageSize;
  const to = from + pageSize;
  const supabase = await createSupabaseServerClient();
  const { data: bookings, count: bookingCount } = await supabase
    .from('session_bookings')
    .select(
      'id, status, payment_method, booked_at, cancelled_at, coach_sessions!inner(title, scheduled_at, duration_minutes, session_type, status, client_id, coach_id)',
      { count: 'exact' },
    )
    .eq('coach_sessions.coach_id', coachId)
    .order('booked_at', { ascending: false })
    .range(from, to)
    .limit(pageSize + 1);
  const bookingRows = ((bookings ?? []) as unknown as Booking[]).slice(0, pageSize);
  const hasNext = (bookings?.length ?? 0) > pageSize || from + pageSize < (bookingCount ?? 0);

  if (!bookingRows.length) {
    return (
      <EmptyState
        icon={<CalendarClock className="h-6 w-6" strokeWidth={1.75} />}
        title="No session bookings yet"
        body="Bookings will appear after clients request or pay for coach sessions."
      />
    );
  }

  return (
    <>
      <StaggerGroup className="mt-5 divide-y divide-vera-border">
        {bookingRows.map((booking) => (
          <StaggerItem key={booking.id} as="article" className="py-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h3 className="font-semibold">
                  {booking.coach_sessions?.title ?? 'Untitled session'}
                </h3>
                <p className="mt-1 text-sm text-vera-fg-muted">
                  {booking.coach_sessions?.scheduled_at ? (
                    <LocalDateTime iso={booking.coach_sessions.scheduled_at} />
                  ) : (
                    'Unscheduled'
                  )}{' '}
                  · {booking.coach_sessions?.duration_minutes ?? 0} min · {booking.payment_method}
                </p>
              </div>
              <span className="rounded-full bg-vera-primary/15 px-3 py-1 text-xs font-semibold text-vera-primary">
                {booking.status}
              </span>
            </div>
          </StaggerItem>
        ))}
      </StaggerGroup>
      <Pager page={page} hasNext={hasNext} basePath="/dashboard/coach" />
    </>
  );
}
