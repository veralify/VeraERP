// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });

const getApiKey = (req: Request) => {
  const bearer = req.headers.get('authorization');
  if (bearer?.startsWith('Bearer ')) {
    return bearer.replace('Bearer ', '').trim();
  }
  return req.headers.get('x-api-key')?.trim() || '';
};

const normalizeEmail = (email: string) => email.trim().toLowerCase();

const escapeHtml = (value: string) =>
  value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const adminApiKey = Deno.env.get('VERA_ADMIN_API_KEY');
  const resendApiKey = Deno.env.get('RESEND_API_KEY');
  const fromEmail = Deno.env.get('VERA_EMAIL_FROM');

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.' }, 500);
  }

  try {
    const payload = (await req.json()) as {
      action?:
        | 'dashboard_bootstrap'
        | 'list_subscribers'
        | 'update_subscriber_status'
        | 'delete_subscriber'
        | 'stats'
        | 'send_campaign';
      privyUserId?: string;
      email?: string;
      status?: 'subscribed' | 'unsubscribed';
      brand?: string;
      query?: string;
      limit?: number;
      offset?: number;
      subject?: string;
      body?: string;
    };

    const action = payload.action;
    if (!action) {
      return jsonResponse({ error: 'Missing action.' }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const hasApiKeyAccess = Boolean(adminApiKey) && getApiKey(req) === adminApiKey;
    let adminUserId: string | null = null;

    if (payload.privyUserId?.trim()) {
      const { data: adminUser, error: adminUserError } = await supabase
        .from('vera_users')
        .select('id, role')
        .eq('privy_user_id', payload.privyUserId.trim())
        .maybeSingle();

      if (adminUserError) {
        throw new Error(`Failed to authorize user: ${adminUserError.message}`);
      }
      if (adminUser?.role === 'admin') {
        adminUserId = adminUser.id;
      }
    }

    if (!hasApiKeyAccess && !adminUserId) {
      return jsonResponse({ error: 'Unauthorized.' }, 401);
    }

    if (action === 'dashboard_bootstrap') {
      const { count: subscribedCount, error: subscribedError } = await supabase
        .from('newsletter_subscribers')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'subscribed');

      if (subscribedError) {
        throw new Error(`Failed to fetch subscriber count: ${subscribedError.message}`);
      }

      const { data: campaigns, error: campaignsError } = await supabase
        .from('newsletter_campaigns')
        .select(
          'id, brand, subject, status, target_count, sent_count, failed_count, created_at, completed_at',
        )
        .order('created_at', { ascending: false })
        .limit(10);

      if (campaignsError) {
        throw new Error(`Failed to load campaigns: ${campaignsError.message}`);
      }

      return jsonResponse({
        success: true,
        data: {
          subscribedCount: subscribedCount || 0,
          campaigns: campaigns || [],
        },
      });
    }

    if (action === 'send_campaign') {
      const subject = payload.subject?.trim() || '';
      const body = payload.body?.trim() || '';
      const brand = payload.brand?.trim() || 'default';

      if (!subject || !body) {
        return jsonResponse({ error: 'Subject and body are required.' }, 400);
      }
      if (!resendApiKey || !fromEmail) {
        return jsonResponse(
          { error: 'Missing RESEND_API_KEY or VERA_EMAIL_FROM in function secrets.' },
          500,
        );
      }

      const { data: subscribers, error: subscribersError } = await supabase
        .from('newsletter_subscribers')
        .select('email')
        .eq('status', 'subscribed')
        .eq('brand', brand);

      if (subscribersError) {
        throw new Error(`Failed to load subscribers: ${subscribersError.message}`);
      }

      const recipientEmails = (subscribers || [])
        .map((subscriber) => subscriber.email)
        .filter(Boolean);
      if (!recipientEmails.length) {
        return jsonResponse({ error: `No subscribed emails found for brand "${brand}".` }, 400);
      }

      const { data: campaign, error: campaignInsertError } = await supabase
        .from('newsletter_campaigns')
        .insert({
          created_by_user_id: adminUserId,
          brand,
          subject,
          body,
          status: 'sending',
          target_count: recipientEmails.length,
          provider: 'resend',
          started_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .select('id')
        .single();

      if (campaignInsertError || !campaign?.id) {
        throw new Error(`Failed to create campaign: ${campaignInsertError?.message}`);
      }

      const html = `<div style="font-family:Arial,sans-serif;line-height:1.6">${escapeHtml(body).replaceAll('\n', '<br/>')}</div>`;
      let sentCount = 0;
      let failedCount = 0;
      const deliveries: Array<{
        campaign_id: string;
        subscriber_email: string;
        status: string;
        provider_message_id?: string | null;
        error?: string | null;
      }> = [];

      for (const email of recipientEmails) {
        try {
          const response = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${resendApiKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              from: fromEmail,
              to: [email],
              subject,
              html,
            }),
          });

          const json = (await response.json().catch(() => null)) as {
            id?: string;
            message?: string;
          } | null;
          if (!response.ok) {
            failedCount += 1;
            deliveries.push({
              campaign_id: campaign.id,
              subscriber_email: email,
              status: 'failed',
              error: json?.message || `HTTP ${response.status}`,
            });
            continue;
          }

          sentCount += 1;
          deliveries.push({
            campaign_id: campaign.id,
            subscriber_email: email,
            status: 'sent',
            provider_message_id: json?.id || null,
          });
        } catch (sendError) {
          failedCount += 1;
          deliveries.push({
            campaign_id: campaign.id,
            subscriber_email: email,
            status: 'failed',
            error: sendError instanceof Error ? sendError.message : 'Unexpected send error.',
          });
        }
      }

      const { error: deliveriesError } = await supabase
        .from('newsletter_campaign_deliveries')
        .insert(deliveries);
      if (deliveriesError) {
        throw new Error(`Failed to save campaign deliveries: ${deliveriesError.message}`);
      }

      const finalStatus = failedCount > 0 ? (sentCount > 0 ? 'partial' : 'failed') : 'sent';
      const { error: campaignUpdateError } = await supabase
        .from('newsletter_campaigns')
        .update({
          status: finalStatus,
          sent_count: sentCount,
          failed_count: failedCount,
          completed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', campaign.id);

      if (campaignUpdateError) {
        throw new Error(`Failed to update campaign status: ${campaignUpdateError.message}`);
      }

      return jsonResponse({
        success: true,
        data: {
          campaignId: campaign.id,
          targetCount: recipientEmails.length,
          sentCount,
          failedCount,
          status: finalStatus,
        },
      });
    }

    if (action === 'list_subscribers') {
      const limit = Math.min(Math.max(payload.limit || 50, 1), 200);
      const offset = Math.max(payload.offset || 0, 0);
      const query = payload.query?.trim() || '';
      const brand = payload.brand?.trim() || '';
      const status = payload.status;

      let request = supabase
        .from('newsletter_subscribers')
        .select('id, email, brand, source, status, created_at, updated_at', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (brand) {
        request = request.eq('brand', brand);
      }
      if (status === 'subscribed' || status === 'unsubscribed') {
        request = request.eq('status', status);
      }
      if (query) {
        request = request.ilike('email', `%${query}%`);
      }

      const { data, count, error } = await request;
      if (error) {
        throw new Error(`Failed to list subscribers: ${error.message}`);
      }

      return jsonResponse({
        success: true,
        data: data || [],
        pagination: { limit, offset, count: count || 0 },
      });
    }

    if (action === 'update_subscriber_status') {
      const rawEmail = payload.email?.trim();
      if (!rawEmail) {
        return jsonResponse({ error: 'Missing email.' }, 400);
      }
      if (payload.status !== 'subscribed' && payload.status !== 'unsubscribed') {
        return jsonResponse({ error: 'Status must be subscribed or unsubscribed.' }, 400);
      }

      const email = normalizeEmail(rawEmail);
      const { data, error } = await supabase
        .from('newsletter_subscribers')
        .update({
          status: payload.status,
          updated_at: new Date().toISOString(),
        })
        .eq('email', email)
        .select('id, email, status, updated_at')
        .maybeSingle();

      if (error) {
        throw new Error(`Failed to update subscriber: ${error.message}`);
      }
      if (!data) {
        return jsonResponse({ error: 'Subscriber not found.' }, 404);
      }

      return jsonResponse({ success: true, data });
    }

    if (action === 'delete_subscriber') {
      const rawEmail = payload.email?.trim();
      if (!rawEmail) {
        return jsonResponse({ error: 'Missing email.' }, 400);
      }

      const email = normalizeEmail(rawEmail);
      const { data, error } = await supabase
        .from('newsletter_subscribers')
        .delete()
        .eq('email', email)
        .select('id, email');

      if (error) {
        throw new Error(`Failed to delete subscriber: ${error.message}`);
      }
      if (!data?.length) {
        return jsonResponse({ error: 'Subscriber not found.' }, 404);
      }

      return jsonResponse({ success: true, data: data[0] });
    }

    if (action === 'stats') {
      const { count: totalCount, error: totalError } = await supabase
        .from('newsletter_subscribers')
        .select('id', { count: 'exact', head: true });
      if (totalError) {
        throw new Error(`Failed to fetch total subscribers: ${totalError.message}`);
      }

      const { count: subscribedCount, error: subscribedError } = await supabase
        .from('newsletter_subscribers')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'subscribed');
      if (subscribedError) {
        throw new Error(`Failed to fetch subscribed count: ${subscribedError.message}`);
      }

      return jsonResponse({
        success: true,
        data: {
          total: totalCount || 0,
          subscribed: subscribedCount || 0,
          unsubscribed: Math.max((totalCount || 0) - (subscribedCount || 0), 0),
        },
      });
    }

    return jsonResponse({ error: 'Unsupported action.' }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected newsletter API error.';
    return jsonResponse({ error: message }, 500);
  }
});
