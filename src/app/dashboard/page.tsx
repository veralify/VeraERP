import { EmptyState } from '@components/member/EmptyState';
import { createSupabaseServerClient } from '@lib/supabase/server';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Dashboard',
  description: 'Your Veralify member dashboard.',
};

async function getUser() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}

export default async function DashboardPage() {
  const user = await getUser();
  return (
    <main className="px-4 py-8 lg:px-8">
      <section className="mb-8 rounded-vera-2xl border border-vera-border bg-vera-surface p-6">
        <p className="text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">
          Member dashboard
        </p>
        <h1 className="mt-2 text-3xl font-black tracking-tight sm:text-5xl">
          Welcome{user?.email ? `, ${user.email}` : ''}.
        </h1>
        <p className="mt-3 max-w-2xl text-vera-fg-muted">
          Start with a meal, progress photo, or goal check-in. Your dashboard will fill in as you
          track real activity.
        </p>
      </section>
      <EmptyState
        title="No entries yet"
        body="Your meals, progress updates, goals, groups, live rooms, messages, and AI insights will appear here after you add them."
        ctaHref="/dashboard/track"
        ctaLabel="Start tracking"
      />
    </main>
  );
}
