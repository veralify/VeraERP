import {
  Card,
  ErrorMessage,
  inputClass,
  PageHeader,
  Pager,
  SubmitButton,
} from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { createSupabaseServerClient } from '@lib/supabase/server';
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { createGroupPostAction, joinGroupAction, leaveGroupAction } from '../actions';

type Props = {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ page?: string; error?: string }>;
};
type Post = { id: string; content: string | null; created_at: string };
const pageSize = 10;

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  return { title: `Group · ${slug}` };
}

export default async function GroupDetailPage({ params, searchParams }: Props) {
  const [{ slug }, query] = await Promise.all([params, searchParams]);
  const page = Math.max(1, Number(query.page) || 1);
  const from = (page - 1) * pageSize;
  const to = from + pageSize;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: group } = await supabase
    .from('groups')
    .select('id, name, slug, description, goal_type, type, visibility, member_limit')
    .eq('slug', slug)
    .eq('is_active', true)
    .maybeSingle();
  if (!group) notFound();

  const [{ data: membership }, { count: memberCount }, { data: posts, count: postCount }] =
    await Promise.all([
      supabase
        .from('group_members')
        .select('group_id, role, status')
        .eq('group_id', group.id)
        .eq('user_id', user.id)
        .maybeSingle(),
      supabase
        .from('group_members')
        .select('user_id', { count: 'exact', head: true })
        .eq('group_id', group.id)
        .eq('status', 'active'),
      supabase
        .from('posts')
        .select('id, content, created_at', { count: 'exact' })
        .eq('group_id', group.id)
        .eq('status', 'published')
        .order('created_at', { ascending: false })
        .range(from, to)
        .limit(pageSize + 1),
    ]);
  const isMember = membership?.status === 'active';
  const postRows = ((posts ?? []) as Post[]).slice(0, pageSize);
  const hasNext = (posts?.length ?? 0) > pageSize || from + pageSize < (postCount ?? 0);

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Group"
        title={group.name}
        body={group.description ?? 'No description yet.'}
        action={
          <form action={isMember ? leaveGroupAction : joinGroupAction}>
            <input type="hidden" name="groupId" value={group.id} />
            <input type="hidden" name="slug" value={slug} />
            <button className="btn-apple" type="submit">
              {isMember ? 'Leave group' : 'Join group'}
            </button>
          </form>
        }
      />
      <ErrorMessage
        message={query.error ? 'We could not save that group update. Try again.' : undefined}
      />
      <div className="grid gap-6 xl:grid-cols-[1fr_360px]">
        <div className="space-y-6">
          <Card>
            <h2 className="text-xl font-bold">Posts</h2>
            {isMember ? (
              <form action={createGroupPostAction} className="mt-4 grid gap-3">
                <input type="hidden" name="groupId" value={group.id} />
                <input type="hidden" name="slug" value={slug} />
                <textarea
                  className={inputClass}
                  name="content"
                  rows={4}
                  maxLength={1000}
                  placeholder="Share a text update with this group"
                  required
                />
                <SubmitButton>Post update</SubmitButton>
              </form>
            ) : (
              <p className="mt-3 text-sm text-vera-fg-muted">
                Join this group to create text posts.
              </p>
            )}
            <div className="mt-6 space-y-4">
              {postRows.length ? (
                postRows.map((post) => (
                  <article
                    key={post.id}
                    className="rounded-vera-xl border border-vera-border bg-vera-bg-subtle p-4"
                  >
                    <p className="whitespace-pre-wrap text-sm leading-6">{post.content}</p>
                    <p className="mt-3 text-xs text-vera-fg-muted">
                      {new Date(post.created_at).toLocaleString()}
                    </p>
                  </article>
                ))
              ) : (
                <EmptyState
                  title="No posts yet"
                  body={
                    isMember
                      ? 'Create the first text post for this group.'
                      : 'Posts will appear here when available and permitted by group rules.'
                  }
                />
              )}
            </div>
            <Pager page={page} hasNext={hasNext} basePath={`/dashboard/groups/${slug}`} />
          </Card>
        </div>
        <Card>
          <h2 className="text-xl font-bold">About this group</h2>
          <dl className="mt-4 space-y-3 text-sm">
            <div>
              <dt className="text-vera-fg-muted">Members</dt>
              <dd className="font-semibold">
                {memberCount ?? 0}
                {group.member_limit ? ` / ${group.member_limit}` : ''}
              </dd>
            </div>
            <div>
              <dt className="text-vera-fg-muted">Visibility</dt>
              <dd className="font-semibold">{group.visibility}</dd>
            </div>
            <div>
              <dt className="text-vera-fg-muted">Type</dt>
              <dd className="font-semibold">{group.type}</dd>
            </div>
            {group.goal_type ? (
              <div>
                <dt className="text-vera-fg-muted">Goal</dt>
                <dd className="font-semibold">{group.goal_type}</dd>
              </div>
            ) : null}
          </dl>
        </Card>
      </div>
    </main>
  );
}
