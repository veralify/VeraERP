-- M0.1 (docs/EXECUTION_PLAN.md): the marketplace cannot acquire clients if
-- browsing requires a paid subscription. Allow anonymous visitors to read
-- verified coach profiles and their available session slots only — client
-- data, bookings, and session notes remain authenticated-only, unchanged.

create policy coach_profiles_select_verified_anon on public.coach_profiles
  for select to anon
  using (verification_status = 'verified');

create policy coach_sessions_select_available_anon on public.coach_sessions
  for select to anon
  using (status = 'available');

grant select on public.coach_profiles to anon;
grant select on public.coach_sessions to anon;
