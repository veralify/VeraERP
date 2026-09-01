// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';
import { corsHeaders, json, requireEnv } from '../_shared/http.ts';
import { apnsPayload, jobFailurePatch, signApnsJwt } from '../_shared/notification.ts';

const serviceClient = () => createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false, autoRefreshToken: false } });

async function sendApns(pushToken: string, notification: any) {
  const jwt = await signApnsJwt({ teamId: requireEnv('APNS_TEAM_ID'), keyId: requireEnv('APNS_KEY_ID'), privateKeyPem: requireEnv('APNS_PRIVATE_KEY') });
  const bundleId = requireEnv('APNS_BUNDLE_ID');
  const host = (Deno.env.get('APNS_ENV') ?? 'production') === 'sandbox' ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com';
  const res = await fetch(`${host}/3/device/${pushToken}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${jwt}`,
      'apns-topic': bundleId,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json',
    },
    body: JSON.stringify(apnsPayload({ title: notification.title, body: notification.body, data: notification.data })),
  });
  if (!res.ok) throw new Error(`APNs ${res.status}: ${await res.text()}`);
}

async function sendEmail(to: string, notification: any) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { authorization: `Bearer ${requireEnv('RESEND_API_KEY')}`, 'content-type': 'application/json' },
    body: JSON.stringify({ from: Deno.env.get('VERA_EMAIL_FROM') ?? 'Veralify <notifications@veralify.com>', to, subject: notification.title, text: notification.body }),
  });
  if (!res.ok) throw new Error(`Resend ${res.status}: ${await res.text()}`);
}

async function dispatch(supabase: any, job: any) {
  const { data: notification, error } = await supabase.from('notifications').select('id,user_id,type,title,body,data').eq('id', job.notification_id).single();
  if (error) throw error;
  if (job.provider === 'apns') {
    const { data: devices, error: deviceError } = await supabase.from('user_devices').select('push_token').eq('user_id', job.user_id).eq('platform', 'ios').not('push_token', 'is', null);
    if (deviceError) throw deviceError;
    if (!devices?.length) throw new Error('No APNs device tokens for user');
    for (const device of devices) await sendApns(device.push_token, notification);
  } else if (job.provider === 'email') {
    const { data: profile, error: profileError } = await supabase.from('profiles').select('email').eq('id', job.user_id).single();
    if (profileError) throw profileError;
    if (!profile?.email) throw new Error('No email for user');
    await sendEmail(profile.email, notification);
  } else if (job.provider === 'web') {
    // Web notifications are delivered through the notifications table/realtime; marking sent is sufficient.
    return;
  } else {
    throw new Error(`Unsupported notification provider ${job.provider}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);
  const auth = req.headers.get('authorization') ?? '';
  if (auth !== `Bearer ${requireEnv('SUPABASE_SERVICE_ROLE_KEY')}`) return json({ error: 'Unauthorized.' }, 401);
  const body = await req.json().catch(() => ({}));
  const limit = Math.max(1, Math.min(Number(body.limit ?? 50), 100));
  const supabase = serviceClient();
  const { data: jobs, error } = await supabase.rpc('claim_notification_jobs', { p_limit: limit });
  if (error) throw error;
  const results = [];
  for (const job of jobs ?? []) {
    try {
      await dispatch(supabase, job);
      await supabase.from('notification_jobs').update({ status: 'sent', sent_at: new Date().toISOString(), last_error: null }).eq('id', job.id);
      results.push({ id: job.id, status: 'sent' });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const patch = jobFailurePatch(job, message);
      await supabase.from('notification_jobs').update(patch).eq('id', job.id);
      results.push({ id: job.id, status: patch.status, error: message });
    }
  }
  return json({ ok: true, claimed: jobs?.length ?? 0, results });
});
