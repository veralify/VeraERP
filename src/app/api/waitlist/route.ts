import { getActiveBrand } from '@config/brands';
import { ReferralNotificationEmail } from '@emails/referral-notification';
import { WaitlistWelcomeEmail } from '@emails/waitlist-welcome';
import { render } from '@react-email/components';
import { NextResponse } from 'next/server';

const CONSENT_TEXT =
  'I agree to receive product and launch updates from Veralify Ltd and accept the Privacy Policy.';

const isValidEmail = (email: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

const getClientIp = (request: Request) => {
  const fwd = request.headers.get('x-forwarded-for');
  if (fwd) return fwd.split(',')[0]?.trim() ?? null;
  return request.headers.get('x-real-ip');
};

export async function POST(request: Request) {
  const brand = getActiveBrand();

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const resendApiKey = process.env.RESEND_API_KEY;
  const from = process.env.RESEND_FROM || 'Veralify <hello@veralify.com>';

  let payload: { email?: string; consent?: boolean; source?: string; ref?: string };
  try {
    payload = await request.json();
  } catch {
    payload = {};
  }

  const email = payload.email?.trim().toLowerCase() ?? '';
  const source = payload.source?.trim() || 'waitlist';
  const ref = payload.ref?.trim() || null;

  if (!email || !isValidEmail(email)) {
    return NextResponse.json({ error: 'Please enter a valid email address.' }, { status: 400 });
  }

  // GDPR: explicit consent is required before we store or contact anyone.
  if (payload.consent !== true) {
    return NextResponse.json(
      { error: 'Please tick the consent box to join the waitlist.' },
      { status: 400 },
    );
  }

  if (!supabaseUrl || !serviceRoleKey || serviceRoleKey === 'your_service_role_key') {
    return NextResponse.json(
      { error: 'Waitlist storage is not configured on the server.' },
      { status: 500 },
    );
  }

  // Detect whether this is a brand-new signup (so referral credit is only
  // given once, never on a re-submit of an existing email).
  const existingRes = await fetch(
    `${supabaseUrl}/rest/v1/newsletter_subscribers?email=eq.${encodeURIComponent(email)}&select=referral_code,status`,
    {
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  );
  const existing = (await existingRes.json().catch(() => []))?.[0];
  const isNewSignup = !existing;
  // Someone is "already subscribed" only if a record exists AND it is still
  // active. A previously unsubscribed email counts as a fresh (re)subscribe,
  // so it should receive the welcome email again.
  const alreadySubscribed = Boolean(existing) && existing?.status === 'subscribed';

  // 1) Persist the subscriber (with proof-of-consent) in Supabase.
  const now = new Date().toISOString();
  const record: Record<string, unknown> = {
    email,
    brand: brand.id,
    source,
    status: 'subscribed',
    consent: true,
    consent_at: now,
    consent_text: CONSENT_TEXT,
    ip_address: getClientIp(request),
    user_agent: request.headers.get('user-agent'),
    updated_at: now,
  };
  // Only stamp the referrer on the very first signup.
  if (isNewSignup && ref) {
    record.referred_by = ref;
  }

  const dbRes = await fetch(`${supabaseUrl}/rest/v1/newsletter_subscribers?on_conflict=email`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify(record),
  });

  if (!dbRes.ok) {
    const detail = await dbRes.text();
    return NextResponse.json(
      { error: 'Could not save your email. Please try again.', detail },
      { status: 502 },
    );
  }

  const saved = (await dbRes.json().catch(() => []))?.[0];
  const unsubscribeUrl = saved?.unsubscribe_token
    ? `${brand.websiteUrl}/api/unsubscribe?token=${saved.unsubscribe_token}`
    : brand.websiteUrl;

  const rpc = (fn: string, body: unknown) =>
    fetch(`${supabaseUrl}/rest/v1/rpc/${fn}`, {
      method: 'POST',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

  // Credit the referrer (only for a genuine new signup, never self-referral).
  const isReferredSignup = isNewSignup && Boolean(ref) && ref !== saved?.referral_code;
  if (isReferredSignup) {
    await rpc('increment_referral', { p_code: ref }).catch(() => {});
  }

  // Compute this subscriber's live waitlist position.
  let position = 0;
  try {
    const posRes = await rpc('waitlist_position', { p_email: email });
    const posVal = await posRes.json();
    position = typeof posVal === 'number' ? posVal : Number.parseInt(posVal, 10) || 0;
  } catch {
    position = 0;
  }

  const referralCode = saved?.referral_code ?? '';
  const referralUrl = referralCode ? `${brand.websiteUrl}/?ref=${referralCode}` : brand.websiteUrl;

  // 2) Send the branded welcome email — but only for genuinely new (or
  //    re-activated) subscribers. If the email is already actively subscribed,
  //    we skip the send and just show the welcome screen.
  let emailSent = false;
  if (!alreadySubscribed && resendApiKey && resendApiKey !== 're_xxxxxxxxx') {
    try {
      const element = WaitlistWelcomeEmail({
        brandName: brand.name,
        primaryColor: brand.theme.primary,
        websiteUrl: brand.websiteUrl,
        logoUrl: `${brand.websiteUrl}/veralify-logo.png`,
        unsubscribeUrl,
        position,
        referralUrl,
      });
      const html = await render(element);
      const text = await render(element, { plainText: true });

      const mailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: email,
          subject: `Welcome to ${brand.name} — you're on the list`,
          html,
          text,
          headers: {
            'List-Unsubscribe': `<${unsubscribeUrl}>`,
            'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
          },
        }),
      });
      emailSent = mailRes.ok;
    } catch {
      emailSent = false;
    }
  }

  // 3) Notify the referrer that a friend joined with their link and they moved
  //    up. Best-effort; skipped for self-referrals and unsubscribed referrers.
  if (isReferredSignup && resendApiKey && resendApiKey !== 're_xxxxxxxxx') {
    try {
      const referrerRes = await fetch(
        `${supabaseUrl}/rest/v1/newsletter_subscribers?referral_code=eq.${encodeURIComponent(ref as string)}&select=email,referral_count,referral_code,unsubscribe_token,status`,
        {
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
          },
        },
      );
      const referrer = (await referrerRes.json().catch(() => []))?.[0];
      if (referrer?.email && referrer.status !== 'unsubscribed') {
        let referrerPosition = 0;
        try {
          const rp = await rpc('waitlist_position', { p_email: referrer.email });
          const rpVal = await rp.json();
          referrerPosition = typeof rpVal === 'number' ? rpVal : Number.parseInt(rpVal, 10) || 0;
        } catch {
          referrerPosition = 0;
        }

        const referrerUnsub = referrer.unsubscribe_token
          ? `${brand.websiteUrl}/api/unsubscribe?token=${referrer.unsubscribe_token}`
          : brand.websiteUrl;

        const refElement = ReferralNotificationEmail({
          brandName: brand.name,
          primaryColor: brand.theme.primary,
          websiteUrl: brand.websiteUrl,
          logoUrl: `${brand.websiteUrl}/veralify-logo.png`,
          unsubscribeUrl: referrerUnsub,
          position: referrerPosition,
          referralCount: Number(referrer.referral_count) || 1,
          referralUrl: `${brand.websiteUrl}/?ref=${referrer.referral_code}`,
        });
        const refHtml = await render(refElement);
        const refText = await render(refElement, { plainText: true });

        await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${resendApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from,
            to: referrer.email,
            subject: `🎉 A friend just joined ${brand.name} — you moved up`,
            html: refHtml,
            text: refText,
            headers: {
              'List-Unsubscribe': `<${referrerUnsub}>`,
              'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
            },
          }),
        });
      }
    } catch {
      // Notifying the referrer is a nice-to-have; never fail the signup for it.
    }
  }

  return NextResponse.json({
    success: true,
    emailSent,
    alreadySubscribed,
    position,
    referralCode,
    referralUrl,
    message: alreadySubscribed
      ? "You're already on the list — welcome back!"
      : "You're on the list!",
  });
}
