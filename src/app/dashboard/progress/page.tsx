import {
  Card,
  ErrorMessage,
  Field,
  inputClass,
  PageHeader,
  Pager,
  SubmitButton,
} from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { createSupabaseServerClient } from '@lib/supabase/server';
import type { Metadata } from 'next';
import { addWeightEntryAction } from './actions';

export const metadata: Metadata = { title: 'Progress' };
type SearchParams = Promise<{ page?: string; error?: string }>;
type WeightEntry = { id: string; weight_kg: number; measured_at: string; notes: string | null };
const pageSize = 10;

function WeightTrendChart({ entries }: { entries: WeightEntry[] }) {
  if (entries.length < 2)
    return (
      <EmptyState
        title="Log your first weight trend"
        body="Add at least two weight entries to see a trend line."
      />
    );
  const ordered = [...entries].reverse();
  const min = Math.min(...ordered.map((entry) => entry.weight_kg));
  const max = Math.max(...ordered.map((entry) => entry.weight_kg));
  const span = Math.max(max - min, 1);
  const points = ordered
    .map((entry, index) => {
      const x = ordered.length === 1 ? 0 : (index / (ordered.length - 1)) * 100;
      const y = 90 - ((entry.weight_kg - min) / span) * 80;
      return `${x},${y}`;
    })
    .join(' ');
  return (
    <figure>
      <figcaption className="mb-3 text-sm text-vera-fg-muted">
        Weight trend from {ordered[0]?.weight_kg}kg to {ordered.at(-1)?.weight_kg}kg.
      </figcaption>
      <svg
        viewBox="0 0 100 100"
        role="img"
        aria-label={`Weight trend chart with ${ordered.length} entries`}
        className="h-64 w-full overflow-visible rounded-vera-lg border border-vera-border bg-vera-bg-subtle p-2"
      >
        <line x1="0" x2="100" y1="90" y2="90" stroke="var(--vera-color-border)" strokeWidth="0.5" />
        <line x1="0" x2="100" y1="10" y2="10" stroke="var(--vera-color-border)" strokeWidth="0.5" />
        <polyline
          points={points}
          fill="none"
          stroke="var(--vera-color-primary)"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        {ordered.map((entry, index) => {
          const [x, y] = points.split(' ')[index]?.split(',').map(Number) ?? [0, 0];
          return (
            <circle key={entry.id} cx={x} cy={y} r="2" fill="var(--vera-color-primary-strong)">
              <title>
                {entry.weight_kg}kg on {entry.measured_at.slice(0, 10)}
              </title>
            </circle>
          );
        })}
      </svg>
    </figure>
  );
}

export default async function ProgressPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const page = Math.max(1, Number(params.page) || 1);
  const from = (page - 1) * pageSize;
  const to = from + pageSize;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const [{ data: entries }, { count }] = await Promise.all([
    supabase
      .from('weight_entries')
      .select('id, weight_kg, measured_at, notes')
      .eq('user_id', user.id)
      .order('measured_at', { ascending: false })
      .range(from, to)
      .limit(pageSize + 1),
    supabase
      .from('weight_entries')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id),
  ]);
  const rows = ((entries ?? []) as WeightEntry[]).slice(0, pageSize);
  const hasNext = (entries?.length ?? 0) > pageSize || from + pageSize < (count ?? 0);

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Progress"
        title="Weight progress"
        body="Add real weight entries and review a lightweight SVG trend. Measurements, mood, and progress photos remain empty until those web flows ship."
      />
      <ErrorMessage
        message={
          params.error
            ? 'We could not save that weight entry. Check the value and try again.'
            : undefined
        }
      />
      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="space-y-6">
          <Card>
            <h2 className="mb-4 text-xl font-bold">Trend</h2>
            <WeightTrendChart entries={rows} />
          </Card>
          <Card>
            <h2 className="text-xl font-bold">Entries</h2>
            {rows.length ? (
              <div className="mt-4 divide-y divide-vera-border">
                {rows.map((entry) => (
                  <article key={entry.id} className="py-4">
                    <p className="font-semibold">{entry.weight_kg} kg</p>
                    <p className="text-sm text-vera-fg-muted">
                      {entry.measured_at.slice(0, 10)}
                      {entry.notes ? ` · ${entry.notes}` : ''}
                    </p>
                  </article>
                ))}
              </div>
            ) : (
              <EmptyState
                title="No weight entries yet"
                body="Add your first weight entry to begin your progress history."
              />
            )}
            <Pager page={page} hasNext={hasNext} basePath="/dashboard/progress" />
          </Card>
          <div className="grid gap-4 md:grid-cols-3">
            <EmptyState
              title="No measurements yet"
              body="Body measurements arrive in a later web phase."
            />
            <EmptyState title="No mood entries yet" body="Mood and energy logging arrives later." />
            <EmptyState
              title="No progress photos yet"
              body="Progress photo upload remains planned."
            />
          </div>
        </div>
        <Card>
          <h2 className="text-xl font-bold">Add weight</h2>
          <form action={addWeightEntryAction} className="mt-4 grid gap-4">
            <Field label="Weight (kg)">
              <input
                className={inputClass}
                name="weightKg"
                type="number"
                step="0.1"
                min="30"
                max="300"
                required
              />
            </Field>
            <Field label="Measured date">
              <input
                className={inputClass}
                name="measuredAt"
                type="date"
                defaultValue={new Date().toISOString().slice(0, 10)}
              />
            </Field>
            <Field label="Notes">
              <textarea className={inputClass} name="notes" rows={3} />
            </Field>
            <SubmitButton>Save weight</SubmitButton>
          </form>
        </Card>
      </div>
    </main>
  );
}
