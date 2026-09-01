import { Card, MacroBars, PageHeader } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { createSupabaseServerClient } from '@lib/supabase/server';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Dashboard',
  description: 'Your Veralify member dashboard.',
};

type Goal = {
  id: string;
  title: string;
  target_value: number | null;
  unit: string | null;
  goal_targets?: { metric: string; target_value: number; period: string }[];
};
type Summary = {
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  meal_count: number;
};
type Weight = { weight_kg: number; measured_at: string };
type GroupMember = { group_id: string; groups: { name: string; slug: string } | null };

export default async function DashboardPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const today = new Date().toISOString().slice(0, 10);
  const [
    { data: profile },
    { data: summary },
    { data: goal },
    { data: latestWeight },
    { data: memberships },
  ] = await Promise.all([
    supabase
      .from('profiles')
      .select('display_name, onboarding_completed')
      .eq('id', user.id)
      .maybeSingle(),
    supabase
      .from('daily_nutrition_summaries')
      .select('calories, protein_g, carbs_g, fat_g, meal_count')
      .eq('user_id', user.id)
      .eq('date', today)
      .maybeSingle(),
    supabase
      .from('goals')
      .select('id, title, target_value, unit, goal_targets(metric, target_value, period)')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase
      .from('weight_entries')
      .select('weight_kg, measured_at')
      .eq('user_id', user.id)
      .order('measured_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase
      .from('group_members')
      .select('group_id, groups(name, slug)')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .order('joined_at', { ascending: false })
      .limit(5),
  ]);
  const targets: Record<string, number> = {};
  for (const target of ((goal as Goal | null)?.goal_targets ?? []) as {
    metric: string;
    target_value: number;
    period: string;
  }[]) {
    if (target.period === 'daily') targets[target.metric] = target.target_value;
  }
  const typedSummary = summary as Summary | null;
  const typedWeight = latestWeight as Weight | null;
  const typedMemberships = (memberships ?? []) as GroupMember[];
  const needsGoal = !goal || !profile?.onboarding_completed;

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Member dashboard"
        title={`Welcome${profile?.display_name ? `, ${profile.display_name}` : user.email ? `, ${user.email}` : ''}.`}
        body="Real nutrition, goals, progress, and groups will appear here as you use Veralify."
      />
      {needsGoal ? (
        <Card className="mb-6 border-vera-warning/60 bg-vera-warning/10">
          <h2 className="text-xl font-bold">Set up your plan</h2>
          <p className="mt-2 text-sm text-vera-fg-muted">
            Create your first goal to generate daily calorie and macro targets for tracking.
          </p>
          <a className="btn-apple mt-5" href="/dashboard/goals/new">
            Set up your plan
          </a>
        </Card>
      ) : null}
      <div className="grid gap-6 xl:grid-cols-2">
        <Card>
          <h2 className="text-xl font-bold">Today's nutrition</h2>
          {typedSummary ? (
            <div className="mt-5">
              <MacroBars
                calories={Math.round(typedSummary.calories)}
                protein={Math.round(typedSummary.protein_g)}
                carbs={Math.round(typedSummary.carbs_g)}
                fat={Math.round(typedSummary.fat_g)}
                targets={{
                  calories: targets.calories,
                  protein_g: targets.protein_g,
                  carbs_g: targets.carbs_g,
                  fat_g: targets.fat_g,
                }}
              />
              <p className="mt-4 text-sm text-vera-fg-muted">
                Meals logged: {typedSummary.meal_count}
              </p>
            </div>
          ) : (
            <EmptyState
              title="No meals logged today"
              body="Log a food item to create today's nutrition summary."
              ctaHref="/dashboard/track"
              ctaLabel="Start tracking"
            />
          )}
        </Card>
        <Card>
          <h2 className="text-xl font-bold">Current goal</h2>
          {goal ? (
            <div className="mt-4">
              <p className="text-2xl font-black">{(goal as Goal).title}</p>
              <p className="mt-2 text-sm text-vera-fg-muted">
                Target: {(goal as Goal).target_value ?? '—'}
                {(goal as Goal).unit ?? ''}
              </p>
              <a className="btn-apple-secondary mt-5" href="/dashboard/goals">
                Manage goals
              </a>
            </div>
          ) : (
            <EmptyState
              title="No active goal"
              body="Create a goal to make the dashboard useful."
              ctaHref="/dashboard/goals/new"
              ctaLabel="Create goal"
            />
          )}
        </Card>
        <Card>
          <h2 className="text-xl font-bold">Latest weight</h2>
          {typedWeight ? (
            <div className="mt-4">
              <p className="text-4xl font-black">{typedWeight.weight_kg} kg</p>
              <p className="mt-2 text-sm text-vera-fg-muted">
                Measured {typedWeight.measured_at.slice(0, 10)}
              </p>
              <a className="btn-apple-secondary mt-5" href="/dashboard/progress">
                View progress
              </a>
            </div>
          ) : (
            <EmptyState
              title="No weight entries"
              body="Add a weight entry to begin progress tracking."
              ctaHref="/dashboard/progress"
              ctaLabel="Add weight"
            />
          )}
        </Card>
        <Card>
          <h2 className="text-xl font-bold">Joined groups</h2>
          {typedMemberships.length ? (
            <ul className="mt-4 space-y-3">
              {typedMemberships.map((membership) =>
                membership.groups ? (
                  <li key={membership.group_id}>
                    <a
                      className="text-vera-primary underline"
                      href={`/dashboard/groups/${membership.groups.slug}`}
                    >
                      {membership.groups.name}
                    </a>
                  </li>
                ) : null,
              )}
            </ul>
          ) : (
            <EmptyState
              title="No groups joined"
              body="Join a group to add community accountability to your loop."
              ctaHref="/dashboard/groups"
              ctaLabel="Discover groups"
            />
          )}
        </Card>
      </div>
    </main>
  );
}
