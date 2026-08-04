-- ============================================================
-- Film Feature Tables
-- Created: 2026-08-04
-- Adds: films, film_members, film_shots, film_invites tables
--       + Supabase Storage bucket for film shots with RLS
-- All tables are created first; all RLS policies follow so
-- cross-table references in USING clauses always resolve.
-- ============================================================

-- ── 1. TABLE DEFINITIONS ────────────────────────────────────

create table if not exists public.films (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    creator_id      uuid not null references auth.users(id) on delete cascade,
    shot_limit      integer not null default 30 check (shot_limit > 0),
    member_limit    integer not null default 25 check (member_limit > 0),
    reveal_at       timestamptz not null,
    status          text not null default 'shooting'
                        check (status in ('shooting', 'revealed')),
    created_at      timestamptz not null default now()
);

create index if not exists idx_films_creator_id on public.films(creator_id);
create index if not exists idx_films_reveal_at  on public.films(reveal_at);
create index if not exists idx_films_status     on public.films(status);

create table if not exists public.film_members (
    id              uuid primary key default gen_random_uuid(),
    film_id         uuid not null references public.films(id) on delete cascade,
    user_id         uuid references auth.users(id) on delete set null,
    guest_token     text,
    display_name    text not null,
    shots_used      integer not null default 0 check (shots_used >= 0),
    joined_at       timestamptz not null default now(),
    constraint film_members_unique_user    unique (film_id, user_id),
    constraint film_members_unique_guest   unique (film_id, guest_token),
    constraint film_members_identity_check check (
        user_id is not null or guest_token is not null
    )
);

create index if not exists idx_film_members_film_id     on public.film_members(film_id);
create index if not exists idx_film_members_user_id     on public.film_members(user_id);
create index if not exists idx_film_members_guest_token on public.film_members(guest_token);

create table if not exists public.film_shots (
    id              uuid primary key default gen_random_uuid(),
    film_id         uuid not null references public.films(id) on delete cascade,
    member_id       uuid not null references public.film_members(id) on delete cascade,
    storage_path    text not null,
    captured_at     timestamptz not null default now(),
    is_revealed     boolean not null default false
);

create index if not exists idx_film_shots_film_id   on public.film_shots(film_id);
create index if not exists idx_film_shots_member_id on public.film_shots(member_id);

create table if not exists public.film_invites (
    id          uuid primary key default gen_random_uuid(),
    film_id     uuid not null references public.films(id) on delete cascade,
    token       text not null unique,
    expires_at  timestamptz,
    created_at  timestamptz not null default now()
);

create index if not exists idx_film_invites_film_id on public.film_invites(film_id);
create index if not exists idx_film_invites_token   on public.film_invites(token);

-- ── 2. ENABLE RLS ────────────────────────────────────────────

alter table public.films        enable row level security;
alter table public.film_members enable row level security;
alter table public.film_shots   enable row level security;
alter table public.film_invites enable row level security;

-- ── 3. RLS POLICIES ─────────────────────────────────────────
-- All four tables exist before any policy is created so
-- cross-table USING references resolve without error.

-- films: creator full access
do $$ begin
    if not exists (select 1 from pg_policies where tablename = 'films' and policyname = 'films_all_creator') then
        create policy films_all_creator
        on public.films for all to authenticated
        using (auth.uid() = creator_id)
        with check (auth.uid() = creator_id);
    end if;
end $$;

-- films: members can read films they belong to
do $$ begin
    if not exists (select 1 from pg_policies where tablename = 'films' and policyname = 'films_select_member') then
        create policy films_select_member
        on public.films for select to authenticated
        using (
            exists (
                select 1 from public.film_members fm
                where fm.film_id = id
                  and fm.user_id = auth.uid()
            )
        );
    end if;
end $$;

-- film_members: authenticated users can insert their own membership
do $$ begin
    if not exists (select 1 from pg_policies where tablename = 'film_members' and policyname = 'film_members_insert_self') then
        create policy film_members_insert_self
        on public.film_members for insert to authenticated
        with check (user_id = auth.uid());
    end if;
end $$;

-- film_members: members can read peers in the same film
do $$ begin
    if not exists (select 1 from pg_policies where tablename = 'film_members' and policyname = 'film_members_select_peer') then
        create policy film_members_select_peer
        on public.film_members for select to authenticated
        using (
            exists (
                select 1 from public.film_members fm2
                where fm2.film_id = film_id
                  and fm2.user_id = auth.uid()
            )
        );
    end if;
end $$;

-- film_members: users can update their own row (shots_used counter)
do $$ begin
    if not exists (select 1 from pg_policies where tablename = 'film_members' and policyname = 'film_members_update_own') then
        create policy film_members_update_own
        on public.film_members for update to authenticated
        using (user_id = auth.uid())
        with check (user_id = auth.uid());
    end if;
end $$;

-- film_members: guest participants (no account) can insert
do $$ begin
    if not exists (select 1 from pg_policies where tablename = 'film_members' and policyname = 'film_members_insert_guest') then
        create policy film_members_insert_guest
        on public.film_members for insert to anon
        with check (user_id is null and guest_token is not null);
    end if;
end $$;

-- film_shots: members can insert shots for their own membership
do $$ begin
    if not exists (select 1 from pg_policies where tablename = 'film_shots' and policyname = 'film_shots_insert_member') then
        create policy film_shots_insert_member
        on public.film_shots for insert to authenticated
        with check (
            exists (
                select 1 from public.film_members fm
                where fm.id = member_id
                  and fm.user_id = auth.uid()
            )
        );
    end if;
end $$;

-- film_shots: shots readable only after the film is revealed
do $$ begin
    if not exists (select 1 from pg_policies where tablename = 'film_shots' and policyname = 'film_shots_select_revealed') then
        create policy film_shots_select_revealed
        on public.film_shots for select to authenticated
        using (
            exists (
                select 1 from public.films f
                join public.film_members fm on fm.film_id = f.id
                where f.id = film_id
                  and f.status = 'revealed'
                  and fm.user_id = auth.uid()
            )
        );
    end if;
end $$;

-- film_invites: creator can manage invites for their films
do $$ begin
    if not exists (select 1 from pg_policies where tablename = 'film_invites' and policyname = 'film_invites_all_creator') then
        create policy film_invites_all_creator
        on public.film_invites for all to authenticated
        using (
            exists (select 1 from public.films f where f.id = film_id and f.creator_id = auth.uid())
        )
        with check (
            exists (select 1 from public.films f where f.id = film_id and f.creator_id = auth.uid())
        );
    end if;
end $$;

-- film_invites: anyone (including anon) can look up an invite by token
do $$ begin
    if not exists (select 1 from pg_policies where tablename = 'film_invites' and policyname = 'film_invites_select_by_token') then
        create policy film_invites_select_by_token
        on public.film_invites for select to anon, authenticated
        using (true);
    end if;
end $$;

-- ── 4. STORAGE BUCKET: film-shots ───────────────────────────

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'film-shots',
    'film-shots',
    false,
    10485760,
    array['image/jpeg', 'image/heic', 'image/png']
)
on conflict (id) do nothing;

-- Storage upload: authenticated members during active filming
do $$ begin
    if not exists (
        select 1 from pg_policies
        where schemaname = 'storage' and tablename = 'objects' and policyname = 'film_shots_upload'
    ) then
        create policy film_shots_upload
        on storage.objects for insert to authenticated
        with check (
            bucket_id = 'film-shots'
            and exists (
                select 1
                from public.film_members fm
                join public.films f on f.id = fm.film_id
                where fm.user_id = auth.uid()
                  and (storage.foldername(name))[1] = f.id::text
                  and (storage.foldername(name))[2] = fm.id::text
                  and f.status = 'shooting'
            )
        );
    end if;
end $$;

-- Storage upload: guest participants (anon)
do $$ begin
    if not exists (
        select 1 from pg_policies
        where schemaname = 'storage' and tablename = 'objects' and policyname = 'film_shots_upload_guest'
    ) then
        create policy film_shots_upload_guest
        on storage.objects for insert to anon
        with check (
            bucket_id = 'film-shots'
            and exists (
                select 1 from public.films f
                where f.id::text = (storage.foldername(name))[1]
                  and f.status = 'shooting'
            )
        );
    end if;
end $$;

-- Storage read: only after film is revealed and requester is a member
do $$ begin
    if not exists (
        select 1 from pg_policies
        where schemaname = 'storage' and tablename = 'objects' and policyname = 'film_shots_read_revealed'
    ) then
        create policy film_shots_read_revealed
        on storage.objects for select to authenticated
        using (
            bucket_id = 'film-shots'
            and exists (
                select 1
                from public.films f
                join public.film_members fm on fm.film_id = f.id
                where f.id::text = (storage.foldername(name))[1]
                  and f.status = 'revealed'
                  and fm.user_id = auth.uid()
            )
        );
    end if;
end $$;

-- ── 5. AUTO-REVEAL CRON (optional) ──────────────────────────
--
-- Enable pg_cron in Supabase Dashboard → Database → Extensions, then run:
--
--   select cron.schedule(
--     'reveal-due-films',
--     '* * * * *',
--     $$
--       update public.films
--       set status = 'revealed'
--       where status = 'shooting' and reveal_at <= now();
--
--       update public.film_shots fs
--       set is_revealed = true
--       from public.films f
--       where fs.film_id = f.id
--         and f.status = 'revealed'
--         and fs.is_revealed = false;
--     $$
--   );
