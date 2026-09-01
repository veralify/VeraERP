import {
  Card,
  ErrorMessage,
  Field,
  inputClass,
  PageHeader,
  SubmitButton,
} from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { GoalForm } from '@components/member/GoalForm';
import { createSupabaseServerClient } from '@lib/supabase/server';
import type { Metadata } from 'next';
import { updateGoalAction } from './actions';

export const metadata: Metadata = { title: 'Goals' };
type SearchParams = Promise<{ error?: string }>;

type Goal = {
  id: string;
  title: string;
  type: string;
  starting_value: number | null;
  target_value: number | null;
  unit: string | null;
  status: string;
  start_date: string | null;
  target_date: string | null;
  goal_targets?: { metric: string; target_value: number; unit: string | null; period: string }[];
};

export default async function GoalsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const { data: goals } = await supabase
    .from('goals')
    .select(
      'id, title, type, starting_value, target_value, unit, status, start_date, target_date, goal_targets(metric, target_value, unit, period)',
    )
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(25);

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Goals"
        title="Goals and daily targets"
        body="Create goals and deterministic nutrition targets. All queries are scoped to your user through RLS."
        action={
          <a className="btn-apple-secondary" href="/dashboard/goals/new">
            Setup flow
          </a>
        }
      />
      <ErrorMessage
        message={
          params.error
            ? 'We could not save that goal. Check the required fields and try again.'
            : undefined
        }
      />
      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="space-y-5">
          {goals?.length ? (
            (goals as Goal[]).map((goal) => (
              <Card key={goal.id}>
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div>
                    <p className="text-sm font-semibold uppercase text-vera-primary">
                      {goal.status}
                    </p>
                    <h2 className="mt-1 text-2xl font-bold">{goal.title}</h2>
                    <p className="mt-2 text-sm text-vera-fg-muted">
                      {goal.type} · {goal.starting_value ?? '—'}
                      {goal.unit ?? ''} → {goal.target_value ?? '—'}
                      {goal.unit ?? ''}
                      {goal.target_date ? ` by ${goal.target_date}` : ''}
                    </p>
                  </div>
                </div>
                <div className="mt-5 grid gap-3 sm:grid-cols-4">
                  {(goal.goal_targets ?? [])
                    .filter((target) => target.period === 'daily')
                    .map((target) => (
                      <div key={target.metric} className="rounded-vera-lg bg-vera-bg-subtle p-3">
                        <p className="text-xs text-vera-fg-muted">{target.metric}</p>
                        <p className="mt-1 font-black">
                          {target.target_value}
                          {target.unit ?? ''}
                        </p>
                      </div>
                    ))}
                </div>
                <form action={updateGoalAction} className="mt-5 grid gap-3 md:grid-cols-4">
                  <input type="hidden" name="goalId" value={goal.id} />
                  <Field label="Title">
                    <input className={inputClass} name="title" defaultValue={goal.title} required />
                  </Field>
                  <Field label="Target">
                    <input
                      className={inputClass}
                      name="targetValue"
                      type="number"
                      step="0.1"
                      defaultValue={goal.target_value ?? ''}
                    />
                  </Field>
                  <Field label="Status">
                    <select className={inputClass} name="status" defaultValue={goal.status}>
                      <option value="active">active</option>
                      <option value="paused">paused</option>
                      <option value="completed">completed</option>
                      <option value="cancelled">cancelled</option>
                    </select>
                  </Field>
                  <div className="flex items-end">
                    <SubmitButton>Save</SubmitButton>
                  </div>
                </form>
              </Card>
            ))
          ) : (
            <EmptyState
              title="No goals set yet"
              body="Create a goal to generate daily nutrition targets and unlock dashboard guidance."
              ctaHref="/dashboard/goals/new"
              ctaLabel="Set up your plan"
            />
          )}
        </div>
        <GoalForm />
      </div>
    </main>
  );
}
