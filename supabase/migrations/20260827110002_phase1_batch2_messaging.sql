-- Phase 1 Batch 2 messaging domain. Conversations/messages are PARTICIPANT-scoped.
-- Ambiguity resolved: direct membership management is limited to conversation creator at creation time; message deletion is soft via deleted_at.

create type public.conversation_type as enum ('direct', 'group', 'coach_client');
create type public.conversation_member_role as enum ('owner', 'admin', 'member');
create type public.message_type as enum ('text', 'image', 'video', 'system');

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  type public.conversation_type not null,
  group_id uuid references public.groups(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conversations_group_type_check check ((type = 'group' and group_id is not null) or (type <> 'group' and group_id is null))
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.conversation_member_role not null default 'member',
  last_read_message_id uuid,
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message_type public.message_type not null default 'text',
  body text,
  metadata jsonb not null default '{}'::jsonb,
  reply_to_id uuid references public.messages(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  constraint messages_body_or_metadata_check check (body is not null or metadata <> '{}'::jsonb)
);

alter table public.conversation_members
  add constraint conversation_members_last_read_message_fk
  foreign key (last_read_message_id) references public.messages(id) on delete set null;

create table if not exists public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  storage_path text not null,
  media_type public.media_type not null,
  size_bytes bigint not null check (size_bytes > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_conversations_group_id on public.conversations(group_id);
create index if not exists idx_conversations_created_by on public.conversations(created_by);
create index if not exists idx_conversation_members_user_id on public.conversation_members(user_id);
create index if not exists idx_conversation_members_last_read_message_id on public.conversation_members(last_read_message_id);
create index if not exists idx_messages_conversation_created_at on public.messages(conversation_id, created_at desc);
create index if not exists idx_messages_sender_created_at on public.messages(sender_id, created_at desc);
create index if not exists idx_messages_reply_to_id on public.messages(reply_to_id);
create index if not exists idx_message_attachments_message_id on public.message_attachments(message_id);

create trigger set_conversations_updated_at before update on public.conversations for each row execute function public.set_updated_at();
create trigger set_conversation_members_updated_at before update on public.conversation_members for each row execute function public.set_updated_at();
create trigger set_messages_updated_at before update on public.messages for each row execute function public.set_updated_at();
create trigger set_message_attachments_updated_at before update on public.message_attachments for each row execute function public.set_updated_at();

create or replace function public.prevent_client_conversation_member_escalation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if auth.role() = 'authenticated' and (new.conversation_id <> old.conversation_id or new.user_id <> old.user_id or new.role <> old.role) then
    raise exception 'conversation member role and identity changes are server-authorized' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger prevent_client_conversation_member_escalation
before update on public.conversation_members
for each row execute function public.prevent_client_conversation_member_escalation();

create or replace function public.prevent_client_message_identity_changes()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if auth.role() = 'authenticated' and (new.conversation_id <> old.conversation_id or new.sender_id <> old.sender_id) then
    raise exception 'message sender and conversation are immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger prevent_client_message_identity_changes
before update on public.messages
for each row execute function public.prevent_client_message_identity_changes();

alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_attachments enable row level security;
alter table public.conversations force row level security;
alter table public.conversation_members force row level security;
alter table public.messages force row level security;
alter table public.message_attachments force row level security;

create or replace function public.is_conversation_member(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = auth.uid()
  );
$$;

revoke all on function public.is_conversation_member(uuid) from public;
revoke all on function public.is_conversation_member(uuid) from anon;
grant execute on function public.is_conversation_member(uuid) to authenticated;

create policy conversations_select_participant on public.conversations for select to authenticated
using (public.is_conversation_member(id));
create policy conversations_insert_creator on public.conversations for insert to authenticated
with check (created_by = auth.uid() and (group_id is null or public.is_group_member(group_id)));
create policy conversations_update_creator on public.conversations for update to authenticated
using (created_by = auth.uid()) with check (created_by = auth.uid());

create policy conversation_members_select_participant on public.conversation_members for select to authenticated
using (public.is_conversation_member(conversation_id));
create policy conversation_members_insert_creator on public.conversation_members for insert to authenticated
with check (exists (select 1 from public.conversations c where c.id = conversation_id and c.created_by = auth.uid()));
create policy conversation_members_update_self_read_state on public.conversation_members for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy conversation_members_delete_self on public.conversation_members for delete to authenticated
using (user_id = auth.uid());

create policy messages_select_participant on public.messages for select to authenticated
using (public.is_conversation_member(conversation_id));
create policy messages_insert_participant_sender on public.messages for insert to authenticated
with check (sender_id = auth.uid() and public.is_conversation_member(conversation_id));
create policy messages_update_own_soft_delete_or_edit on public.messages for update to authenticated
using (sender_id = auth.uid() and public.is_conversation_member(conversation_id))
with check (sender_id = auth.uid() and public.is_conversation_member(conversation_id));

create policy message_attachments_select_participant on public.message_attachments for select to authenticated
using (exists (select 1 from public.messages m where m.id = message_attachments.message_id and public.is_conversation_member(m.conversation_id)));
create policy message_attachments_insert_own_message on public.message_attachments for insert to authenticated
with check (exists (select 1 from public.messages m where m.id = message_attachments.message_id and m.sender_id = auth.uid() and public.is_conversation_member(m.conversation_id)));
create policy message_attachments_delete_own_message on public.message_attachments for delete to authenticated
using (exists (select 1 from public.messages m where m.id = message_attachments.message_id and m.sender_id = auth.uid() and public.is_conversation_member(m.conversation_id)));

grant select, insert, update, delete on public.conversations, public.conversation_members, public.messages, public.message_attachments to authenticated;
