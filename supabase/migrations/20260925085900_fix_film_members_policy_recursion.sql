-- film_members_select_peer read film_members from inside a policy on
-- film_members. Postgres rejects that as infinite recursion the moment an
-- authenticated user touches the table — including indirectly, through the
-- film-shots storage upload policy. Because every insert policy on
-- storage.objects is evaluated together, that made *any* authenticated
-- upload fail, whatever the bucket (found while adding the receipts bucket).
--
-- The policy also compared `fm2.film_id = film_id`, where the unqualified
-- `film_id` resolved to fm2's own column, so it never restricted to the
-- same film.
--
-- A security-definer helper answers "is this user in this film?" without
-- re-entering row security, and the policy now compares against the row
-- being read.

create or replace function public.is_film_member(target_film_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.film_members
    where film_id = target_film_id
      and user_id = auth.uid()
  );
$$;

revoke all on function public.is_film_member(uuid) from public, anon;
grant execute on function public.is_film_member(uuid) to authenticated;

drop policy if exists film_members_select_peer on public.film_members;
create policy film_members_select_peer
  on public.film_members for select to authenticated
  using (public.is_film_member(film_members.film_id));
