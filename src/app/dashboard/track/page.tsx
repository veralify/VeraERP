import {
  Card,
  ErrorMessage,
  Field,
  inputClass,
  MacroBars,
  PageHeader,
  SubmitButton,
} from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { createSupabaseServerClient } from '@lib/supabase/server';
import type { Metadata } from 'next';
import { deleteFoodItemAction, logFoodAction, updateFoodItemAction } from './actions';

export const metadata: Metadata = { title: 'Track' };

type SearchParams = Promise<{ date?: string; q?: string; error?: string }>;
type Food = {
  id: string;
  name: string;
  brand: string | null;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  serving_size: number;
  serving_unit: string;
};
type Serving = { id: string; food_id: string; label: string; grams: number };
type Log = { id: string; meal_group_id: string | null; logged_at: string; notes: string | null };
type Item = {
  id: string;
  food_log_id: string;
  name: string;
  quantity: number;
  unit: string;
  grams: number | null;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
};
type MealGroup = { id: string; name: string; meal_type: string };

const mealTypes = ['breakfast', 'lunch', 'dinner', 'snack', 'other'] as const;

function validDate(value?: string) {
  return value && /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : new Date().toISOString().slice(0, 10);
}

function addDays(date: string, days: number) {
  const d = new Date(`${date}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function errorText(code?: string) {
  if (!code) return undefined;
  return 'We could not save that change. Check the fields and try again.';
}

export default async function TrackPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const date = validDate(params.date);
  const query = (params.q ?? '').trim();
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const start = `${date}T00:00:00.000Z`;
  const end = `${date}T23:59:59.999Z`;
  const [{ data: logs }, { data: activeGoal }, { data: foods }] = await Promise.all([
    supabase
      .from('food_logs')
      .select('id, meal_group_id, logged_at, notes')
      .eq('user_id', user.id)
      .gte('logged_at', start)
      .lte('logged_at', end)
      .order('logged_at', { ascending: true })
      .limit(100),
    supabase
      .from('goals')
      .select('id, title, goal_targets(metric, target_value, unit, period)')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
    query.length >= 2
      ? supabase
          .from('foods')
          .select(
            'id, name, brand, calories, protein_g, carbs_g, fat_g, serving_size, serving_unit',
          )
          .ilike('name', `%${query}%`)
          .order('name')
          .limit(10)
      : Promise.resolve({ data: [] as Food[] | null }),
  ]);

  const typedLogs = (logs ?? []) as Log[];
  const logIds = typedLogs.map((log) => log.id);
  const mealGroupIds = [
    ...new Set(typedLogs.map((log) => log.meal_group_id).filter(Boolean)),
  ] as string[];
  const [{ data: items }, { data: mealGroups }, { data: servings }] = await Promise.all([
    logIds.length
      ? supabase
          .from('food_log_items')
          .select(
            'id, food_log_id, name, quantity, unit, grams, calories, protein_g, carbs_g, fat_g, fiber_g',
          )
          .in('food_log_id', logIds)
          .order('created_at')
          .limit(500)
      : Promise.resolve({ data: [] as Item[] | null }),
    mealGroupIds.length
      ? supabase.from('meal_groups').select('id, name, meal_type').in('id', mealGroupIds).limit(100)
      : Promise.resolve({ data: [] as MealGroup[] | null }),
    foods?.length
      ? supabase
          .from('food_servings')
          .select('id, food_id, label, grams')
          .in(
            'food_id',
            foods.map((food) => food.id),
          )
          .order('grams')
          .limit(100)
      : Promise.resolve({ data: [] as Serving[] | null }),
  ]);

  const typedItems = (items ?? []) as Item[];
  const totals = typedItems.reduce(
    (sum, item) => ({
      calories: sum.calories + item.calories,
      protein: sum.protein + item.protein_g,
      carbs: sum.carbs + item.carbs_g,
      fat: sum.fat + item.fat_g,
    }),
    { calories: 0, protein: 0, carbs: 0, fat: 0 },
  );
  const targets: Record<string, number> = {};
  for (const target of (activeGoal?.goal_targets ?? []) as {
    metric: string;
    target_value: number;
    period: string;
  }[]) {
    if (target.period === 'daily') targets[target.metric] = target.target_value;
  }
  const groupById = new Map(((mealGroups ?? []) as MealGroup[]).map((group) => [group.id, group]));
  const itemsByLog = new Map<string, Item[]>();
  for (const item of typedItems)
    itemsByLog.set(item.food_log_id, [...(itemsByLog.get(item.food_log_id) ?? []), item]);
  const logsByMeal = new Map<string, Log[]>();
  for (const log of typedLogs) {
    const group = log.meal_group_id ? groupById.get(log.meal_group_id) : undefined;
    const key = group?.meal_type ?? 'other';
    logsByMeal.set(key, [...(logsByMeal.get(key) ?? []), log]);
  }

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Track"
        title="Today view"
        body="Manual web logging uses internal foods and snapshots nutrition values at log time. AI camera is intentionally omitted on web this phase."
      />
      <ErrorMessage message={errorText(params.error)} />
      <Card className="mt-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <a
            className="btn-apple-secondary"
            href={`/dashboard/track?date=${addDays(date, -1)}${query ? `&q=${encodeURIComponent(query)}` : ''}`}
          >
            Previous day
          </a>
          <form className="flex items-center gap-2" action="/dashboard/track">
            <input className={inputClass} type="date" name="date" defaultValue={date} />
            {query ? <input type="hidden" name="q" value={query} /> : null}
            <SubmitButton>Go</SubmitButton>
          </form>
          <a
            className="btn-apple-secondary"
            href={`/dashboard/track?date=${addDays(date, 1)}${query ? `&q=${encodeURIComponent(query)}` : ''}`}
          >
            Next day
          </a>
        </div>
      </Card>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="space-y-6">
          <Card>
            <h2 className="text-xl font-bold">
              Daily totals{activeGoal ? ` vs ${activeGoal.title}` : ''}
            </h2>
            <div className="mt-5">
              <MacroBars
                calories={Math.round(totals.calories)}
                protein={Math.round(totals.protein)}
                carbs={Math.round(totals.carbs)}
                fat={Math.round(totals.fat)}
                targets={{
                  calories: targets.calories,
                  protein_g: targets.protein_g,
                  carbs_g: targets.carbs_g,
                  fat_g: targets.fat_g,
                }}
              />
            </div>
          </Card>

          {typedLogs.length === 0 ? (
            <EmptyState
              title="No meals logged yet"
              body="Search for a food, choose a portion, and save it to create your first meal entry for this date."
            />
          ) : (
            mealTypes.map((meal) => {
              const mealLogs = logsByMeal.get(meal) ?? [];
              if (mealLogs.length === 0) return null;
              return (
                <Card key={meal}>
                  <h2 className="text-xl font-bold capitalize">{meal}</h2>
                  <div className="mt-4 space-y-4">
                    {mealLogs.map((log) =>
                      (itemsByLog.get(log.id) ?? []).map((item) => (
                        <article
                          key={item.id}
                          className="rounded-vera-xl border border-vera-border bg-vera-bg-subtle p-4"
                        >
                          <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                            <div>
                              <h3 className="font-semibold">{item.name}</h3>
                              <p className="text-sm text-vera-fg-muted">
                                {item.quantity} {item.unit} · {item.grams ?? 0}g ·{' '}
                                {Math.round(item.calories)} kcal · P {Math.round(item.protein_g)}g C{' '}
                                {Math.round(item.carbs_g)}g F {Math.round(item.fat_g)}g
                              </p>
                            </div>
                            <form action={deleteFoodItemAction}>
                              <input type="hidden" name="itemId" value={item.id} />
                              <input type="hidden" name="logId" value={log.id} />
                              <input type="hidden" name="date" value={date} />
                              <button
                                className="text-sm font-semibold text-vera-danger"
                                type="submit"
                              >
                                Delete
                              </button>
                            </form>
                          </div>
                          <form
                            action={updateFoodItemAction}
                            className="mt-4 flex flex-wrap items-end gap-3"
                          >
                            <input type="hidden" name="itemId" value={item.id} />
                            <input type="hidden" name="date" value={date} />
                            <Field label="Quantity">
                              <input
                                className={inputClass}
                                name="quantity"
                                type="number"
                                step="0.25"
                                min="0.25"
                                defaultValue={item.quantity}
                              />
                            </Field>
                            <SubmitButton>Update item</SubmitButton>
                          </form>
                        </article>
                      )),
                    )}
                  </div>
                </Card>
              );
            })
          )}
        </div>

        <Card>
          <h2 className="text-xl font-bold">Add food</h2>
          <form className="mt-4 flex gap-2" action="/dashboard/track">
            <input type="hidden" name="date" value={date} />
            <input
              className={`${inputClass} flex-1`}
              name="q"
              defaultValue={query}
              placeholder="Search internal foods"
            />
            <SubmitButton>Search</SubmitButton>
          </form>
          <div className="mt-5 space-y-4">
            {query.length < 2 ? (
              <p className="text-sm text-vera-fg-muted">
                Enter at least two characters to search foods.
              </p>
            ) : null}
            {query.length >= 2 && (!foods || foods.length === 0) ? (
              <p className="text-sm text-vera-fg-muted">No matching foods found.</p>
            ) : null}
            {((foods ?? []) as Food[]).map((food) => {
              const foodServings = ((servings ?? []) as Serving[]).filter(
                (serving) => serving.food_id === food.id,
              );
              const options = foodServings.length
                ? foodServings
                : [
                    {
                      id: 'default',
                      food_id: food.id,
                      label: `${food.serving_size} ${food.serving_unit}`,
                      grams: food.serving_size,
                    },
                  ];
              return (
                <form
                  key={food.id}
                  action={logFoodAction}
                  className="rounded-vera-xl border border-vera-border bg-vera-bg-subtle p-4"
                >
                  <input type="hidden" name="foodId" value={food.id} />
                  <input type="hidden" name="date" value={date} />
                  <h3 className="font-semibold">{food.name}</h3>
                  <p className="text-sm text-vera-fg-muted">
                    {food.brand ?? 'Internal food'} · {food.calories} kcal per {food.serving_size}
                    {food.serving_unit}
                  </p>
                  <div className="mt-4 grid gap-3 sm:grid-cols-2">
                    <Field label="Meal">
                      <select className={inputClass} name="mealType" defaultValue="breakfast">
                        {mealTypes.map((meal) => (
                          <option key={meal} value={meal}>
                            {meal}
                          </option>
                        ))}
                      </select>
                    </Field>
                    <Field label="Portion">
                      <select className={inputClass} name="servingGrams">
                        {options.map((serving) => (
                          <option key={serving.id} value={serving.grams}>
                            {serving.label} ({serving.grams}g)
                          </option>
                        ))}
                      </select>
                    </Field>
                    <Field label="Quantity">
                      <input
                        className={inputClass}
                        name="quantity"
                        type="number"
                        step="0.25"
                        min="0.25"
                        defaultValue="1"
                      />
                    </Field>
                    <div className="flex items-end">
                      <SubmitButton>Log food</SubmitButton>
                    </div>
                  </div>
                </form>
              );
            })}
          </div>
        </Card>
      </div>
    </main>
  );
}
