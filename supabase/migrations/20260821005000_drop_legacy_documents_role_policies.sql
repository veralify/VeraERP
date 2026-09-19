-- Two policies on a legacy `public.documents` table (added directly to the
-- live database outside of tracked migrations, alongside `profiles.role` —
-- see 20260821010000) still reference `profiles.role`, which blocks that
-- column from being dropped. Nothing in the app queries `public.documents`
-- (grep for `.from('documents')` in src/ turns up nothing — the current
-- document-log feature, if any, is `money_documents`, a distinct table).
-- Drop just the two dependent policies so the role/organization_id cleanup
-- can proceed; the table itself is left untouched.

drop policy if exists "Admins can access org documents" on public.documents;
drop policy if exists "Admins can insert org documents" on public.documents;
