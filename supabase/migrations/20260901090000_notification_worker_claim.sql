-- Notification worker runtime support.
-- The deployed project should schedule the worker with pg_cron + pg_net after function URL and service key are available, e.g.:
-- select cron.schedule(
--   'notification-worker-every-minute',
--   '* * * * *',
--   $$select net.http_post(
--       url := 'https://<project-ref>.functions.supabase.co/notification-worker',
--       headers := jsonb_build_object('Authorization','Bearer <SUPABASE_SERVICE_ROLE_KEY>','Content-Type','application/json'),
--       body := jsonb_build_object('limit',50)
--     );$$
-- );
-- Do not hardcode service keys or project URLs in migrations.

alter type public.notification_job_status add value if not exists 'pending' before 'queued';
