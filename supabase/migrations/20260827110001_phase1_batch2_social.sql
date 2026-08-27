-- Phase 1 Batch 2 social feed domain.
-- Ambiguity resolved: non-group posts may be public/followers/private; group posts inherit §22 group visibility and require active group membership for writes.

create type public.follow_status as enum ('active', 'pending', 'blocked');
create type public.post_visibility as enum ('public', 'followers', 'private', 'group');
create type public.post_status as enum ('draft', 'published', 'archived', 'deleted');
create type public.post_type as enum ('text', 'photo', 'video', 'progress', 'nutrition', 'goal');
create type public.media_type as enum ('image', 'video');
create type public.comment_status as enum ('published', 'deleted', 'hidden');

create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followed_id uuid not null references public.profiles(id) on delete cascade,
  status public.follow_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (follower_id, followed_id),
  constraint follows_not_self_check check (follower_id <> followed_id)
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  content text,
  post_type public.post_type not null default 'text',
  visibility public.post_visibility not null default 'private',
  status public.post_status not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint posts_content_or_group_check check (content is not null or post_type <> 'text')
);

create table if not exists public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  storage_path text not null,
  media_type public.media_type not null,
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  duration_seconds integer check (duration_seconds is null or duration_seconds > 0),
  position integer not null default 0 check (position >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (post_id, position)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  parent_comment_id uuid references public.comments(id) on delete set null,
  content text not null,
  status public.comment_status not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, post_id),
  constraint comments_parent_same_post_fk foreign key (parent_comment_id, post_id) references public.comments(id, post_id) on delete set null (parent_comment_id)
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comment_likes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

create table if not exists public.post_bookmarks (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists idx_follows_follower_status on public.follows(follower_id, status);
create index if not exists idx_follows_followed_status on public.follows(followed_id, status);
create index if not exists idx_posts_group_created_at on public.posts(group_id, created_at desc);
create index if not exists idx_posts_author_created_at on public.posts(author_id, created_at desc);
create index if not exists idx_posts_status_visibility_created_at on public.posts(status, visibility, created_at desc);
create index if not exists idx_post_media_post_id on public.post_media(post_id);
create index if not exists idx_comments_post_created_at on public.comments(post_id, created_at);
create index if not exists idx_comments_author_created_at on public.comments(author_id, created_at desc);
create index if not exists idx_post_likes_user_id on public.post_likes(user_id);
create index if not exists idx_comment_likes_user_id on public.comment_likes(user_id);
create index if not exists idx_post_bookmarks_user_id on public.post_bookmarks(user_id);

create trigger set_follows_updated_at before update on public.follows for each row execute function public.set_updated_at();
create trigger set_posts_updated_at before update on public.posts for each row execute function public.set_updated_at();
create trigger set_post_media_updated_at before update on public.post_media for each row execute function public.set_updated_at();
create trigger set_comments_updated_at before update on public.comments for each row execute function public.set_updated_at();
create trigger set_post_likes_updated_at before update on public.post_likes for each row execute function public.set_updated_at();
create trigger set_comment_likes_updated_at before update on public.comment_likes for each row execute function public.set_updated_at();
create trigger set_post_bookmarks_updated_at before update on public.post_bookmarks for each row execute function public.set_updated_at();

alter table public.follows enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.comments enable row level security;
alter table public.post_likes enable row level security;
alter table public.comment_likes enable row level security;
alter table public.post_bookmarks enable row level security;
alter table public.follows force row level security;
alter table public.posts force row level security;
alter table public.post_media force row level security;
alter table public.comments force row level security;
alter table public.post_likes force row level security;
alter table public.comment_likes force row level security;
alter table public.post_bookmarks force row level security;

create or replace function public.owns_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.posts p
    where p.id = p_post_id
      and p.author_id = auth.uid()
  );
$$;

revoke all on function public.owns_post(uuid) from public;
revoke all on function public.owns_post(uuid) from anon;
grant execute on function public.owns_post(uuid) to authenticated;

create policy follows_select_involved on public.follows for select to authenticated
using (auth.uid() in (follower_id, followed_id));
create policy follows_insert_self on public.follows for insert to authenticated
with check (auth.uid() = follower_id);
create policy follows_update_self on public.follows for update to authenticated
using (auth.uid() = follower_id) with check (auth.uid() = follower_id);
create policy follows_delete_self on public.follows for delete to authenticated
using (auth.uid() = follower_id);

create policy posts_select_visible on public.posts for select to authenticated
using (
  status = 'published' and (
    author_id = auth.uid()
    or (group_id is not null and exists (select 1 from public.groups g where g.id = posts.group_id and g.is_active and (g.visibility = 'public' or public.is_group_member(g.id))))
    or (group_id is null and visibility = 'public')
    or (group_id is null and visibility = 'followers' and exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = posts.author_id and f.status = 'active'))
  )
);
create policy posts_insert_author on public.posts for insert to authenticated
with check (
  author_id = auth.uid()
  and (
    group_id is null
    or public.is_group_member(group_id)
  )
);
create policy posts_update_author_or_group_admin on public.posts for update to authenticated
using (public.owns_post(id) or (group_id is not null and public.is_group_admin(group_id)))
with check (author_id = auth.uid() or (group_id is not null and public.is_group_admin(group_id)));
create policy posts_delete_author_or_group_admin on public.posts for delete to authenticated
using (public.owns_post(id) or (group_id is not null and public.is_group_admin(group_id)));

create policy post_media_select_visible_post on public.post_media for select to authenticated
using (exists (select 1 from public.posts p where p.id = post_media.post_id and p.status = 'published' and (p.author_id = auth.uid() or (p.group_id is not null and exists (select 1 from public.groups g where g.id = p.group_id and g.is_active and (g.visibility = 'public' or public.is_group_member(g.id)))) or (p.group_id is null and p.visibility = 'public') or (p.group_id is null and p.visibility = 'followers' and exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = p.author_id and f.status = 'active')))));
create policy post_media_all_post_owner on public.post_media for all to authenticated
using (public.owns_post(post_id)) with check (public.owns_post(post_id));

create policy comments_select_visible_post on public.comments for select to authenticated
using (status = 'published' and exists (select 1 from public.posts p where p.id = comments.post_id and p.status = 'published' and (p.author_id = auth.uid() or (p.group_id is not null and exists (select 1 from public.groups g where g.id = p.group_id and g.is_active and (g.visibility = 'public' or public.is_group_member(g.id)))) or (p.group_id is null and p.visibility = 'public') or (p.group_id is null and p.visibility = 'followers' and exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = p.author_id and f.status = 'active')))));
create policy comments_insert_member_or_visible on public.comments for insert to authenticated
with check (author_id = auth.uid() and exists (select 1 from public.posts p where p.id = comments.post_id and p.status = 'published' and ((p.group_id is not null and public.is_group_member(p.group_id)) or (p.group_id is null and (p.author_id = auth.uid() or p.visibility = 'public' or (p.visibility = 'followers' and exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = p.author_id and f.status = 'active')))))));
create policy comments_update_author_or_group_admin on public.comments for update to authenticated
using (author_id = auth.uid() or exists (select 1 from public.posts p where p.id = comments.post_id and p.group_id is not null and public.is_group_admin(p.group_id)))
with check (author_id = auth.uid() or exists (select 1 from public.posts p where p.id = comments.post_id and p.group_id is not null and public.is_group_admin(p.group_id)));
create policy comments_delete_author_or_group_admin on public.comments for delete to authenticated
using (author_id = auth.uid() or exists (select 1 from public.posts p where p.id = comments.post_id and p.group_id is not null and public.is_group_admin(p.group_id)));

create policy post_likes_select_visible_post on public.post_likes for select to authenticated
using (exists (select 1 from public.posts p where p.id = post_likes.post_id and p.status = 'published' and (p.author_id = auth.uid() or (p.group_id is not null and exists (select 1 from public.groups g where g.id = p.group_id and g.is_active and (g.visibility = 'public' or public.is_group_member(g.id)))) or (p.group_id is null and p.visibility = 'public') or (p.group_id is null and p.visibility = 'followers' and exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = p.author_id and f.status = 'active')))));
create policy post_likes_insert_own_visible on public.post_likes for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.posts p where p.id = post_likes.post_id and p.status = 'published' and ((p.group_id is not null and public.is_group_member(p.group_id)) or (p.group_id is null and (p.author_id = auth.uid() or p.visibility = 'public' or (p.visibility = 'followers' and exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = p.author_id and f.status = 'active')))))));
create policy post_likes_delete_own on public.post_likes for delete to authenticated using (user_id = auth.uid());

create policy comment_likes_select_visible_comment on public.comment_likes for select to authenticated
using (exists (select 1 from public.comments c join public.posts p on p.id = c.post_id where c.id = comment_likes.comment_id and c.status = 'published' and p.status = 'published' and (p.author_id = auth.uid() or (p.group_id is not null and exists (select 1 from public.groups g where g.id = p.group_id and g.is_active and (g.visibility = 'public' or public.is_group_member(g.id)))) or (p.group_id is null and p.visibility = 'public') or (p.group_id is null and p.visibility = 'followers' and exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = p.author_id and f.status = 'active')))));
create policy comment_likes_insert_own_visible on public.comment_likes for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.comments c join public.posts p on p.id = c.post_id where c.id = comment_likes.comment_id and c.status = 'published' and p.status = 'published' and ((p.group_id is not null and public.is_group_member(p.group_id)) or (p.group_id is null and (p.author_id = auth.uid() or p.visibility = 'public' or (p.visibility = 'followers' and exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = p.author_id and f.status = 'active')))))));
create policy comment_likes_delete_own on public.comment_likes for delete to authenticated using (user_id = auth.uid());

create policy post_bookmarks_select_own on public.post_bookmarks for select to authenticated using (user_id = auth.uid());
create policy post_bookmarks_insert_own_visible on public.post_bookmarks for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.posts p where p.id = post_bookmarks.post_id and p.status = 'published' and ((p.group_id is not null and public.is_group_member(p.group_id)) or (p.group_id is null and (p.author_id = auth.uid() or p.visibility = 'public' or (p.visibility = 'followers' and exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = p.author_id and f.status = 'active')))))));
create policy post_bookmarks_delete_own on public.post_bookmarks for delete to authenticated using (user_id = auth.uid());

grant select, insert, update, delete on public.follows, public.posts, public.post_media, public.comments, public.post_likes, public.comment_likes, public.post_bookmarks to authenticated;
