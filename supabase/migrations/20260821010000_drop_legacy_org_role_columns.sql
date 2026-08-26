-- `profiles.organization_id` and `profiles.role` were added directly to the
-- live database outside of tracked migrations (leftover from an earlier
-- organization/worker-based schema). Nothing in the app reads or writes
-- them, but being NOT NULL with no default, every new-user insert from
-- `handle_new_user()` violates them, causing Supabase Auth signups to fail
-- with "Database error saving new user". Drop them so signup works again.

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  drop column if exists role;

alter table public.profiles
  drop column if exists organization_id;
