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

type ReferralNotificationEmailProps = {
  brandName?: string;
  primaryColor?: string;
  websiteUrl?: string;
  logoUrl?: string;
  unsubscribeUrl?: string;
  position?: number;
  referralCount?: number;
  referralUrl?: string;
};

const main = {
  backgroundColor: '#05070f',
  fontFamily:
    '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
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
  logoUrl = 'https://syehqhcexzgtxzavjpmw.supabase.co/storage/v1/object/public/public-assets/veralify-logo.png',
  unsubscribeUrl = 'https://veralify.com',
  position = 0,
  referralCount = 1,
  referralUrl = 'https://veralify.com',
}: ReferralNotificationEmailProps) => (
  <Html>
    <Head />
    <Preview>
      {`🎉 A friend just joined ${brandName} with your link — you're now #${position}.`}
    </Preview>
    <Body style={main}>
      <Container style={container}>
        <Img
          src={logoUrl}
          alt={`${brandName} logo`}
          width="32"
          height="32"
          style={{ borderRadius: '7px', display: 'block', marginBottom: '24px' }}
        />

        <Text style={paragraph}>Great news 🎉</Text>

        <Text style={paragraph}>
          A friend just joined the {brandName} waitlist using <strong>your invite link</strong> —
          thank you for spreading the word! You've moved up the list.
        </Text>

        {/* Position card */}
        <Section
          style={{
            backgroundColor: '#faf6f5',
            border: `1px solid ${primaryColor}33`,
            borderRadius: '12px',
            padding: '20px',
            textAlign: 'center' as const,
            margin: '0 0 20px',
          }}
        >
          <Text style={{ color: '#666666', fontSize: '13px', margin: '0 0 4px' }}>
            Your new position on the waitlist
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
          <Text style={{ color: '#666666', fontSize: '13px', margin: '6px 0 0' }}>
            {referralCount === 1
              ? '1 friend joined with your link'
              : `${referralCount} friends joined with your link`}
          </Text>
        </Section>

        <Text style={paragraph}>
          <strong>Keep climbing.</strong> The <strong>top 100</strong> unlock an{' '}
          <strong>exclusive launch discount code</strong> — every friend who joins with your link
          bumps you higher.
        </Text>

        <Text style={{ ...paragraph, margin: '0 0 6px', color: '#666666', fontSize: '13px' }}>
          Your personal invite link:
        </Text>
        <Text
          style={{
            margin: '0 0 24px',
            padding: '12px 16px',
            backgroundColor: '#f4f4f4',
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
          Talk soon,
          <br />
          The {brandName} team ·{' '}
          <Link href={websiteUrl} style={{ color: primaryColor }}>
            veralify.com
          </Link>
        </Text>

        <Section style={{ marginTop: '28px' }}>
          <Text style={{ color: '#999999', fontSize: '12px', lineHeight: '18px', margin: 0 }}>
            VERALIFY LTD · Company Number 17332341 · Registered in England and Wales.
          </Text>
          <Text style={{ color: '#999999', fontSize: '12px', lineHeight: '18px', margin: '6px 0 0' }}>
            You're receiving this because you joined our waitlist.{' '}
            <Link href={unsubscribeUrl} style={{ color: '#999999', textDecoration: 'underline' }}>
              Unsubscribe
            </Link>
            .
          </Text>
        </Section>
      </Container>
    </Body>
  </Html>
);

export default ReferralNotificationEmail;
