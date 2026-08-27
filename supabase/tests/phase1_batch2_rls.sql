begin;

create extension if not exists pgtap with schema extensions;
select plan(39);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '50000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'batch2-a@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '50000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'batch2-b@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '50000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'batch2-c@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values
  ('50000000-0000-0000-0000-000000000001', 'batch2-a@example.test', 'batch2_a'),
  ('50000000-0000-0000-0000-000000000002', 'batch2-b@example.test', 'batch2_b'),
  ('50000000-0000-0000-0000-000000000003', 'batch2-c@example.test', 'batch2_c')
on conflict (id) do nothing;

insert into public.groups (id, owner_id, name, slug, visibility, type)
values
  ('51000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Private Batch2 Group', 'batch2-private-group', 'private', 'general'),
  ('51000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', 'Public Batch2 Group', 'batch2-public-group', 'public', 'general')
on conflict (id) do nothing;

insert into public.group_members (group_id, user_id, role, status)
values
  ('51000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'owner', 'active'),
  ('51000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 'member', 'active'),
  ('51000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', 'owner', 'active')
on conflict (group_id, user_id) do nothing;

insert into public.posts (id, author_id, group_id, content, post_type, visibility, status)
values
  ('52000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'private group post', 'text', 'group', 'published'),
  ('52000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', null, 'public post', 'text', 'public', 'published')
on conflict (id) do nothing;

insert into public.comments (id, post_id, author_id, content, status)
values ('53000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 'member comment', 'published')
on conflict (id) do nothing;

insert into public.conversations (id, type, created_by)
values ('54000000-0000-0000-0000-000000000001', 'direct', '50000000-0000-0000-0000-000000000001')
on conflict (id) do nothing;
insert into public.conversation_members (conversation_id, user_id, role)
values
  ('54000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'owner'),
  ('54000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 'member')
on conflict (conversation_id, user_id) do nothing;
insert into public.messages (id, conversation_id, sender_id, message_type, body)
values ('55000000-0000-0000-0000-000000000001', '54000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'text', 'hello b')
on conflict (id) do nothing;

insert into public.live_rooms (id, host_id, title, room_type, status, scheduled_at, agora_channel)
values ('56000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Public Live Room', 'public', 'live', now(), 'batch2-live-room')
on conflict (id) do nothing;
insert into public.live_room_participants (room_id, user_id, role, speak_state)
values
  ('56000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'host', 'speaking'),
  ('56000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 'listener', 'listener')
on conflict (room_id, user_id) do nothing;
insert into public.room_banned_users (room_id, user_id, banned_by, reason)
values ('56000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000001', 'test ban')
on conflict (room_id, user_id) do nothing;

select ok(relrowsecurity, 'RLS enabled: groups') from pg_class where oid = 'public.groups'::regclass;
select ok(relrowsecurity, 'RLS enabled: group_members') from pg_class where oid = 'public.group_members'::regclass;
select ok(relrowsecurity, 'RLS enabled: group_rules') from pg_class where oid = 'public.group_rules'::regclass;
select ok(relrowsecurity, 'RLS enabled: group_invites') from pg_class where oid = 'public.group_invites'::regclass;
select ok(relrowsecurity, 'RLS enabled: follows') from pg_class where oid = 'public.follows'::regclass;
select ok(relrowsecurity, 'RLS enabled: posts') from pg_class where oid = 'public.posts'::regclass;
select ok(relrowsecurity, 'RLS enabled: post_media') from pg_class where oid = 'public.post_media'::regclass;
select ok(relrowsecurity, 'RLS enabled: comments') from pg_class where oid = 'public.comments'::regclass;
select ok(relrowsecurity, 'RLS enabled: post_likes') from pg_class where oid = 'public.post_likes'::regclass;
select ok(relrowsecurity, 'RLS enabled: comment_likes') from pg_class where oid = 'public.comment_likes'::regclass;
select ok(relrowsecurity, 'RLS enabled: post_bookmarks') from pg_class where oid = 'public.post_bookmarks'::regclass;
select ok(relrowsecurity, 'RLS enabled: conversations') from pg_class where oid = 'public.conversations'::regclass;
select ok(relrowsecurity, 'RLS enabled: conversation_members') from pg_class where oid = 'public.conversation_members'::regclass;
select ok(relrowsecurity, 'RLS enabled: messages') from pg_class where oid = 'public.messages'::regclass;
select ok(relrowsecurity, 'RLS enabled: message_attachments') from pg_class where oid = 'public.message_attachments'::regclass;
select ok(relrowsecurity, 'RLS enabled: live_rooms') from pg_class where oid = 'public.live_rooms'::regclass;
select ok(relrowsecurity, 'RLS enabled: live_room_hosts') from pg_class where oid = 'public.live_room_hosts'::regclass;
select ok(relrowsecurity, 'RLS enabled: live_room_participants') from pg_class where oid = 'public.live_room_participants'::regclass;
select ok(relrowsecurity, 'RLS enabled: room_banned_users') from pg_class where oid = 'public.room_banned_users'::regclass;
select ok(relrowsecurity, 'RLS enabled: room_moderation_events') from pg_class where oid = 'public.room_moderation_events'::regclass;
select ok(relrowsecurity, 'RLS enabled: live_room_events') from pg_class where oid = 'public.live_room_events'::regclass;

set local role authenticated;
select set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000003', true);
select is((select count(*)::int from public.groups where id = '51000000-0000-0000-0000-000000000001'), 0, 'non-member cannot read private group');
select is((select count(*)::int from public.posts where id = '52000000-0000-0000-0000-000000000001'), 0, 'non-member cannot read private group post');
select is((select count(*)::int from public.messages where id = '55000000-0000-0000-0000-000000000001'), 0, 'non-participant cannot read conversation message');
select is((select count(*)::int from public.live_rooms where id = '56000000-0000-0000-0000-000000000001'), 0, 'banned user cannot read public live room');
select is((select count(*)::int from public.room_banned_users where room_id = '56000000-0000-0000-0000-000000000001'), 1, 'banned user can read own ban record');

select set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000002', true);
select is((select count(*)::int from public.groups where id = '51000000-0000-0000-0000-000000000001'), 1, 'member can read private group');
select is((select count(*)::int from public.posts where id = '52000000-0000-0000-0000-000000000001'), 1, 'member can read private group post');
select is((select count(*)::int from public.messages where id = '55000000-0000-0000-0000-000000000001'), 1, 'participant can read conversation message');
select throws_ok($$insert into public.live_room_participants (room_id, user_id, role, speak_state) values ('56000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 'speaker', 'speaking') on conflict (room_id, user_id) do update set role = excluded.role, speak_state = excluded.speak_state$$, '42501', null, 'user cannot self-promote live room role');
update public.live_room_participants set role = 'speaker', speak_state = 'speaking' where room_id = '56000000-0000-0000-0000-000000000001' and user_id = '50000000-0000-0000-0000-000000000002';
reset role;
select is((select role::text from public.live_room_participants where room_id = '56000000-0000-0000-0000-000000000001' and user_id = '50000000-0000-0000-0000-000000000002'), 'listener', 'self-promotion attempt leaves role unchanged');

set local role authenticated;
select set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000001', true);
update public.live_room_participants set role = 'speaker', speak_state = 'speaking' where room_id = '56000000-0000-0000-0000-000000000001' and user_id = '50000000-0000-0000-0000-000000000002';
reset role;
select is((select role::text from public.live_room_participants where room_id = '56000000-0000-0000-0000-000000000001' and user_id = '50000000-0000-0000-0000-000000000002'), 'speaker', 'room moderator can approve speaker role');

select isnt(has_function_privilege('anon', 'public.is_group_member(uuid)', 'execute'), true, 'is_group_member execute revoked from anon');
select isnt(has_function_privilege('anon', 'public.is_group_admin(uuid)', 'execute'), true, 'is_group_admin execute revoked from anon');
select isnt(has_function_privilege('anon', 'public.is_conversation_member(uuid)', 'execute'), true, 'is_conversation_member execute revoked from anon');
select isnt(has_function_privilege('anon', 'public.is_room_participant(uuid)', 'execute'), true, 'is_room_participant execute revoked from anon');
select isnt(has_function_privilege('anon', 'public.owns_post(uuid)', 'execute'), true, 'owns_post execute revoked from anon');
select isnt(has_function_privilege('anon', 'public.is_room_banned(uuid)', 'execute'), true, 'is_room_banned execute revoked from anon');
select isnt(has_function_privilege('anon', 'public.is_room_moderator(uuid)', 'execute'), true, 'is_room_moderator execute revoked from anon');

select * from finish();
rollback;
