import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { RowActions } from '@components/generic/RowActions';
import {
  Card,
  ErrorMessage,
  Field,
  inputClass,
  PageHeader,
  SubmitButton,
} from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { daysUntil } from '@lib/money/format';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { CheckCircle2, Circle, ClipboardList } from 'lucide-react';
import type { Metadata } from 'next';
import {
  addAdminTaskAction,
  deleteAdminTaskAction,
  toggleAdminTaskStatusAction,
  updateAdminTaskAction,
} from '../actions/admin-tasks';

export const metadata: Metadata = { title: 'Admin tasks · Money' };
type SearchParams = Promise<{ error?: string; saved?: string }>;

function dueBadge(dueDate: string | null, status: string) {
  if (!dueDate || status === 'done') return null;
  const days = daysUntil(dueDate);
  if (days === null) return null;
  if (days < 0) return { text: 'Overdue', tone: 'text-vera-danger' };
  if (days <= 3) return { text: `Due in ${days}d`, tone: 'text-vera-warning' };
  return null;
}

export default async function AdminTasksPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: rows } = await supabase
    .from('money_admin_tasks')
    .select('id, title, category, due_date, notes, status')
    .eq('user_id', user.id)
    .order('due_date', { ascending: true, nullsFirst: false });
  const tasks = rows ?? [];

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Money"
        title="Admin tasks"
        body="Money-related to-dos and appointments — renewals, filings, calls to make."
      />
      <ErrorMessage
        message={
          params.error === 'save'
            ? 'We couldn’t save that change. Please try again.'
            : params.error
              ? 'Enter a title for the task.'
              : undefined
        }
      />

      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <Reveal variants={fadeUp}>
          <Card>
            <h2 className="text-xl font-bold">Your tasks</h2>
            {tasks.length ? (
              <StaggerGroup className="mt-4 divide-y divide-vera-border">
                {tasks.map((row) => {
                  const badge = dueBadge(row.due_date, row.status);
                  return (
                    <StaggerItem
                      key={row.id}
                      as="div"
                      className="flex items-center justify-between gap-3 py-4"
                    >
                      <div className="flex items-start gap-3">
                        <form action={toggleAdminTaskStatusAction}>
                          <input type="hidden" name="id" value={row.id} />
                          <input
                            type="hidden"
                            name="status"
                            value={row.status === 'done' ? 'open' : 'done'}
                          />
                          <button
                            type="submit"
                            aria-label={row.status === 'done' ? 'Mark as open' : 'Mark as done'}
                            className="mt-0.5 text-vera-primary transition-opacity hover:opacity-70"
                          >
                            {row.status === 'done' ? (
                              <CheckCircle2 className="h-5 w-5" strokeWidth={1.75} />
                            ) : (
                              <Circle className="h-5 w-5 text-vera-fg-subtle" strokeWidth={1.75} />
                            )}
                          </button>
                        </form>
                        <div>
                          <p
                            className={`font-semibold ${row.status === 'done' ? 'text-vera-fg-muted line-through' : ''}`}
                          >
                            {row.title}
                          </p>
                          <p className="text-sm text-vera-fg-muted">
                            {row.category}
                            {row.due_date ? ` · due ${row.due_date}` : ''}
                            {badge ? (
                              <span className={`ml-2 font-semibold ${badge.tone}`}>
                                {badge.text}
                              </span>
                            ) : null}
                          </p>
                        </div>
                      </div>
                      <RowActions
                        id={row.id}
                        itemLabel={row.title}
                        editTitle="Edit task"
                        updateAction={updateAdminTaskAction}
                        deleteAction={deleteAdminTaskAction}
                      >
                        <Field label="Title">
                          <input
                            className={inputClass}
                            name="title"
                            required
                            defaultValue={row.title}
                          />
                        </Field>
                        <Field label="Category">
                          <input
                            className={inputClass}
                            name="category"
                            defaultValue={row.category}
                          />
                        </Field>
                        <Field label="Due date (optional)">
                          <input
                            className={inputClass}
                            name="due_date"
                            type="date"
                            defaultValue={row.due_date ?? ''}
                          />
                        </Field>
                        <Field label="Notes">
                          <textarea
                            className={inputClass}
                            name="notes"
                            rows={2}
                            defaultValue={row.notes}
                          />
                        </Field>
                        <Field label="Status">
                          <select className={inputClass} name="status" defaultValue={row.status}>
                            <option value="open">Open</option>
                            <option value="done">Done</option>
                          </select>
                        </Field>
                      </RowActions>
                    </StaggerItem>
                  );
                })}
              </StaggerGroup>
            ) : (
              <EmptyState
                icon={<ClipboardList className="h-6 w-6" strokeWidth={1.75} />}
                title="No admin tasks yet"
                body="Add a money-related task or appointment to keep track of it."
              />
            )}
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.05}>
          <form
            action={addAdminTaskAction}
            className="grid gap-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6"
          >
            <h2 className="text-xl font-bold">Add task</h2>
            <Field label="Title">
              <input
                className={inputClass}
                name="title"
                required
                placeholder="Renew car insurance"
              />
            </Field>
            <Field label="Category">
              <input className={inputClass} name="category" defaultValue="General" />
            </Field>
            <Field label="Due date (optional)">
              <input className={inputClass} name="due_date" type="date" />
            </Field>
            <Field label="Notes">
              <textarea className={inputClass} name="notes" rows={2} />
            </Field>
            <SubmitButton>Add task</SubmitButton>
          </form>
        </Reveal>
      </div>
    </main>
  );
}
