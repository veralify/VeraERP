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
import { joinGroupAction, leaveGroupAction } from './actions';

export const metadata: Metadata = { title: 'Groups' };
type SearchParams = Promise<{ q?: string; page?: string; error?: string }>;
type Group = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  goal_type: string | null;
  type: string;
  visibility: string;
  member_limit: number | null;
};
type Membership = { group_id: string; groups: { id: string; name: string; slug: string } | null };
const pageSize = 10;

export default async function GroupsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const query = (params.q ?? '').trim();
  const page = Math.max(1, Number(params.page) || 1);
  const from = (page - 1) * pageSize;
  const to = from + pageSize;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  let groupQuery = supabase
    .from('groups')
    .select('id, name, slug, description, goal_type, type, visibility, member_limit', {
      count: 'exact',
    })
    .eq('visibility', 'public')
    .eq('is_active', true)
    .order('created_at', { ascending: false });
  if (query.length >= 2) groupQuery = groupQuery.ilike('name', `%${query}%`);
  const [{ data: groups, count }, { data: memberships }] = await Promise.all([
    groupQuery.range(from, to).limit(pageSize + 1),
    supabase
      .from('group_members')
      .select('group_id, groups(id, name, slug)')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .order('joined_at', { ascending: false })
      .limit(25),
  ]);
  const rows = ((groups ?? []) as Group[]).slice(0, pageSize);
  const joinedIds = new Set(
    ((memberships ?? []) as Membership[]).map((membership) => membership.group_id),
  );
  const myGroups = ((memberships ?? []) as Membership[])
    .map((membership) => membership.groups)
    .filter((group): group is { id: string; name: string; slug: string } => Boolean(group));
  const hasNext = (groups?.length ?? 0) > pageSize || from + pageSize < (count ?? 0);

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Groups"
        title="Discover groups"
        body="Browse public communities, join with RLS-protected membership writes, and open group posts."
      />
      <ErrorMessage
        message={params.error ? 'We could not update that group. Try again.' : undefined}
      />
      <Card className="mt-4">
        <form action="/dashboard/groups" className="flex flex-col gap-3 sm:flex-row">
          <Field label="Search public groups">
            <input
              className={inputClass}
              name="q"
              defaultValue={query}
              placeholder="Search by group name"
            />
          </Field>
          <div className="flex items-end">
            <SubmitButton>Search</SubmitButton>
          </div>
        </form>
      </Card>
      <div className="mt-6 grid gap-6 xl:grid-cols-[1fr_360px]">
        <Card>
          <h2 className="text-xl font-bold">Public groups</h2>
          <div className="mt-4 space-y-4">
            {rows.length ? (
              rows.map((group) => (
                <article
                  key={group.id}
                  className="rounded-vera-xl border border-vera-border bg-vera-bg-subtle p-4"
                >
                  <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                    <div>
                      <a
                        className="text-lg font-bold hover:text-vera-primary"
                        href={`/dashboard/groups/${group.slug}`}
                      >
                        {group.name}
                      </a>
                      <p className="mt-1 text-sm text-vera-fg-muted">
                        {group.description ?? 'No description yet.'}
                      </p>
                      <p className="mt-2 text-xs uppercase tracking-wide text-vera-fg-subtle">
                        {group.type}
                        {group.goal_type ? ` · ${group.goal_type}` : ''}
                      </p>
                    </div>
                    <form action={joinedIds.has(group.id) ? leaveGroupAction : joinGroupAction}>
                      <input type="hidden" name="groupId" value={group.id} />
                      <button type="submit" className="btn-apple-secondary">
                        {joinedIds.has(group.id) ? 'Leave' : 'Join'}
                      </button>
                    </form>
                  </div>
                </article>
              ))
            ) : (
              <EmptyState
                title="No public groups found"
                body="Try a different search term or check back after communities are created."
              />
            )}
          </div>
          <Pager page={page} hasNext={hasNext} basePath="/dashboard/groups" query={{ q: query }} />
        </Card>
        <Card>
          <h2 className="text-xl font-bold">My groups</h2>
          {myGroups.length ? (
            <ul className="mt-4 space-y-3">
              {myGroups.map((group) => (
                <li key={group.id}>
                  <a
                    className="text-vera-primary underline"
                    href={`/dashboard/groups/${group.slug}`}
                  >
                    {group.name}
                  </a>
                </li>
              ))}
            </ul>
          ) : (
            <EmptyState title="No groups joined yet" body="Join a public group to see it here." />
          )}
        </Card>
      </div>
    </main>
  );
}
