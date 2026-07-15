import type { Locale } from '@i18n/config';
import {
  Body,
  Container,
  Head,
  Html,
  Img,
  Link,
  Preview,
  Section,
  Text,
} from '@react-email/components';
import { fmt, getEmailDir, getEmailStrings } from './i18n';
import { renderRich } from './rich';

type ReferralNotificationEmailProps = {
  brandName?: string;
  primaryColor?: string;
  websiteUrl?: string;
  logoUrl?: string;
  unsubscribeUrl?: string;
  position?: number;
  referralCount?: number;
  referralUrl?: string;
  locale?: Locale;
};

const main = {
  backgroundColor: '#05070f',
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
  color: '#cbd5e1',
};

const container = {
  margin: '0 auto',
  padding: '24px',
  maxWidth: '520px',
};

const paragraph = {
  color: '#cbd5e1',
  fontSize: '15px',
  lineHeight: '24px',
  margin: '0 0 16px',
};

// Space / planet-horizon header: dark with a blue glow rising from the bottom.
const hero = {
  backgroundColor: '#070b16',
  backgroundImage:
    'radial-gradient(ellipse at 50% 125%, rgba(59,130,246,0.45) 0%, rgba(37,99,235,0.14) 42%, rgba(7,11,22,0) 70%)',
  border: '1px solid rgba(255,255,255,0.08)',
  borderRadius: '16px',
  padding: '40px 24px 52px',
  textAlign: 'center' as const,
  margin: '0 0 24px',
};

const heroTitle = {
  color: '#ffffff',
  fontSize: '24px',
  lineHeight: '30px',
  fontWeight: 600,
  margin: '20px 0 0',
};

export const ReferralNotificationEmail = ({
  brandName = 'Veralify',
  primaryColor = '#3B82F6',
  websiteUrl = 'https://veralify.com',
  logoUrl = 'https://veralify.com/veralify-logo.png',
  unsubscribeUrl = 'https://veralify.com',
  position = 0,
  referralCount = 1,
  referralUrl = 'https://veralify.com',
  locale = 'en',
}: ReferralNotificationEmailProps) => {
  const t = getEmailStrings(locale);
  const dir = getEmailDir(locale);
  const r = t.referral;
  const vars = { brand: brandName, position, count: referralCount };
  return (
    <Html lang={locale} dir={dir}>
      <Head />
      <Preview>{fmt(r.preview, vars)}</Preview>
      <Body style={main}>
        <Container style={container}>
          <Section style={hero}>
            <Img
              src={logoUrl}
              alt={fmt(t.common.logoAlt, vars)}
              width="40"
              height="40"
              style={{ borderRadius: '9px', display: 'inline-block' }}
            />
            <Text style={heroTitle}>
              {r.heroTitleLine1}
              <br />
              {r.heroTitleLine2}
            </Text>
          </Section>

          <Text style={paragraph}>{r.greeting}</Text>

          <Text style={paragraph}>{renderRich(fmt(r.friendJoined, vars))}</Text>

          {/* Position card */}
          <Section
            style={{
              backgroundColor: '#0d1220',
              border: `1px solid ${primaryColor}40`,
              borderRadius: '12px',
              padding: '20px',
              textAlign: 'center' as const,
              margin: '0 0 20px',
            }}
          >
            <Text style={{ color: '#94a3b8', fontSize: '13px', margin: '0 0 4px' }}>
              {r.positionLabel}
            </Text>
            <Text
              style={{
                color: primaryColor,
                fontSize: '34px',
                fontWeight: 700,
                lineHeight: '38px',
                margin: 0,
              }}
            >
              #{position}
            </Text>
            <Text style={{ color: '#94a3b8', fontSize: '13px', margin: '6px 0 0' }}>
              {referralCount === 1 ? r.friendsCountOne : fmt(r.friendsCountMany, vars)}
            </Text>
          </Section>

          <Text style={paragraph}>{renderRich(r.keepClimbing)}</Text>

          <Text style={{ ...paragraph, margin: '0 0 6px', color: '#94a3b8', fontSize: '13px' }}>
            {r.inviteLabel}
          </Text>
          <Text
            style={{
              margin: '0 0 24px',
              padding: '12px 16px',
              backgroundColor: '#0d1220',
              border: '1px solid rgba(255,255,255,0.08)',
              borderRadius: '8px',
              fontSize: '14px',
              wordBreak: 'break-all' as const,
            }}
          >
            <Link href={referralUrl} style={{ color: primaryColor, fontWeight: 600 }}>
              {referralUrl}
            </Link>
          </Text>

          <Text style={paragraph}>
            {r.signoff}
            <br />
            {fmt(r.teamLine, vars)}{' '}
            <Link href={websiteUrl} style={{ color: primaryColor }}>
              veralify.com
            </Link>
          </Text>

          <Section
            style={{
              marginTop: '28px',
              borderTop: '1px solid rgba(255,255,255,0.08)',
              paddingTop: '20px',
            }}
          >
            <Text style={{ color: '#64748b', fontSize: '12px', lineHeight: '18px', margin: 0 }}>
              {t.common.company}
            </Text>
            <Text
              style={{ color: '#64748b', fontSize: '12px', lineHeight: '18px', margin: '6px 0 0' }}
            >
              {t.common.receiving}{' '}
              <Link href={unsubscribeUrl} style={{ color: '#64748b', textDecoration: 'underline' }}>
                {t.common.unsubscribe}
              </Link>
              .
            </Text>
          </Section>
        </Container>
      </Body>
    </Html>
  );
};

export default ReferralNotificationEmail;
