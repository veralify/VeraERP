# Agora Token Service and Notification Worker

## Edge Function endpoints

- `POST /functions/v1/agora-token`
  - Actions: `token`, `request-to-speak`, `approve-speaker`, `demote-to-listener`, `ban-user`.
  - Authenticated user endpoint. The server derives `uid`, channel, and role from database state. `requested_role = speaker` is granted only when the participant is already `approved_speaker`/`speaking` with a speaker/host/moderator role.
- `POST /functions/v1/notification-worker`
  - Service-role only. Claims notification outbox rows and dispatches APNs, email, or web notifications.

## Environment variables

Agora:

- `AGORA_APP_ID`
- `AGORA_APP_CERTIFICATE`

Notification worker:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_BUNDLE_ID`
- `APNS_PRIVATE_KEY`
- `APNS_ENV` (`production` default, or `sandbox`)
- `RESEND_API_KEY`
- `VERA_EMAIL_FROM` (optional; defaults to `Veralify <notifications@veralify.com>`)

## pg_cron schedule

Apply in the deployed project after function URL and service key are available:

```sql
select cron.schedule(
  'notification-worker-every-minute',
  '* * * * *',
  $$select net.http_post(
      url := 'https://<project-ref>.functions.supabase.co/notification-worker',
      headers := jsonb_build_object(
        'Authorization', 'Bearer <SUPABASE_SERVICE_ROLE_KEY>',
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object('limit', 50)
    );$$
);
```

The worker claims rows through `public.claim_notification_jobs(limit)`, which uses `FOR UPDATE SKIP LOCKED` and marks rows `processing` before dispatch.

## Verification

```bash
SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io supabase db reset --local
SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io supabase test db
deno check supabase/functions/agora-token/index.ts supabase/functions/notification-worker/index.ts
deno test --allow-env supabase/functions/agora-token supabase/functions/notification-worker
SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io supabase gen types typescript --local > src/lib/api/database.types.ts
pnpm exec tsc --noEmit
```
