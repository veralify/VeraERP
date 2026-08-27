# Phase 1 Database Foundation — Batch 2

## Tables

- Communities: `groups`, `group_members`, `group_rules`, `group_invites`
- Social feed: `follows`, `posts`, `post_media`, `comments`, `post_likes`, `comment_likes`, `post_bookmarks`
- Messaging: `conversations`, `conversation_members`, `messages`, `message_attachments`
- Live rooms: `live_rooms`, `live_room_hosts`, `live_room_participants`, `room_banned_users`, `room_moderation_events`, `live_room_events`

## RLS ownership classification

| Table | Class |
|---|---|
| `groups` | PUBLIC when `visibility = public`; GROUP-MEMBER when private |
| `group_members`, `group_rules`, `group_invites` | GROUP-MEMBER/admin-scoped writes |
| `follows` | SELF: both involved users can read; follower owns writes |
| `posts`, `comments`, `post_likes`, `comment_likes`, `post_bookmarks` | GROUP-MEMBER for group content; non-group posts use author/public/follower visibility |
| `post_media` | PARENT-OWNED via post visibility/ownership |
| `conversations`, `conversation_members`, `messages`, `message_attachments` | PARTICIPANT |
| `live_rooms`, `live_room_hosts`, `live_room_participants` | PARTICIPANT/public-room/group-member visibility with banned-user exclusion |
| `room_banned_users` | Moderator-scoped writes; banned user can read own ban record |
| `room_moderation_events` | Moderator-scoped writes; involved-user/moderator reads |
| `live_room_events` | SERVER-ONLY |

## Helper functions

Implemented in Batch 2:

- `is_group_member(group_id)` — active group member check.
- `is_group_admin(group_id)` — active owner/admin/moderator check.
- `owns_post(post_id)` — post author check.
- `is_conversation_member(conversation_id)` — conversation participant check.
- `is_room_participant(room_id)` — active room participant excluding banned users.
- `is_room_banned(room_id)` — internal live-room ban check.
- `is_room_moderator(room_id)` — active host/moderator check.

All security-definer helpers set `search_path = public, pg_temp`, revoke `EXECUTE` from both `PUBLIC` and `anon`, then grant only to `authenticated`.

## Security notes and ambiguities resolved

- Group visibility is constrained to `public`/`private`.
- Group moderators are treated as admins for moderation/update/delete policy checks.
- Non-group posts support `public`, `followers`, and `private`; group posts inherit group visibility and require active group membership for writes.
- Messaging role changes are not client-self-service; authenticated updates to `conversation_members` can only affect read state, enforced by trigger.
- Live-room role changes are server/moderator-authorized. Users cannot self-promote from listener to speaker; moderators/hosts can update other participants.
- Banned users cannot read the room itself, but can read their own ban row for explanation/support flows.
- `coach_client` live rooms reserve `coach_session_id` without an FK because coaching tables arrive in a later batch.

## Running locally

```bash
SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io supabase db reset --local
SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io supabase test db
SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io supabase gen types typescript --local > src/lib/api/database.types.ts
pnpm exec tsc --noEmit
```
