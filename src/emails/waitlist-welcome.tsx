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

type WaitlistWelcomeEmailProps = {
  brandName?: string;
  primaryColor?: string;
  websiteUrl?: string;
  logoUrl?: string;
  unsubscribeUrl?: string;
  position?: number;
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

export const WaitlistWelcomeEmail = ({
  brandName = 'Veralify',
  primaryColor = '#3B82F6',
  websiteUrl = 'https://veralify.com',
  logoUrl = 'https://syehqhcexzgtxzavjpmw.supabase.co/storage/v1/object/public/public-assets/veralify-logo.png',
  unsubscribeUrl = 'https://veralify.com',
  position = 0,
  referralUrl = 'https://veralify.com',
}: WaitlistWelcomeEmailProps) => (
  <Html>
    <Head />
    <Preview>
      {`You're #${position} on the ${brandName} waitlist — invite friends to move up.`}
    </Preview>
    <Body style={main}>
      <Container style={container}>
        <Section style={hero}>
          <Img
            src={logoUrl}
            alt={`${brandName} logo`}
            width="40"
            height="40"
            style={{ borderRadius: '9px', display: 'inline-block' }}
          />
          <Text style={heroTitle}>
            Your passport to a
            <br />
            borderless world.
          </Text>
        </Section>

        <Text style={paragraph}>Hey 👋</Text>

        <Text style={paragraph}>
          You're officially on the {brandName} waitlist — thank you for joining us early.
        </Text>

        <Text style={paragraph}>
          We're building your <strong>passport to a borderless world</strong>: the first travel and
          telecom super-app for modern explorers. Intuitive enough to activate global internet in
          seconds, smart enough to curate your perfect trip, and designed to make amazing
          experiences easier to reach — wherever you go.
        </Text>

        <Text style={{ ...paragraph, margin: '0 0 16px' }}>
          🌍 Global travel &amp; connectivity in one place.
          <br />
          📲 One intelligent super-app.
          <br />
          💡 Zero friction. No roaming drama.
        </Text>

        <Text style={paragraph}>
          We're redefining how travel should feel — with transparency, empathy, and tech that
          actually works. Booking your journey and staying connected should feel like freedom, not
          frustration.
        </Text>

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
            Your position on the waitlist
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
        </Section>

        <Text style={paragraph}>
          <strong>Want to move up?</strong> The higher you climb, the sooner you get in — and the{' '}
          <strong>top 100</strong> unlock an <strong>exclusive launch discount code</strong>. Every
          friend who joins with your link bumps you up the list.
        </Text>

        <Text style={{ ...paragraph, margin: '0 0 6px', color: '#94a3b8', fontSize: '13px' }}>
          Your personal invite link:
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
          Join us as we stray off the beaten path to find better ways to explore the world.
          <br />
          <br />
          Talk soon,
          <br />
          The {brandName} team ·{' '}
          <Link href={websiteUrl} style={{ color: primaryColor }}>
            veralify.com
          </Link>
        </Text>

        <Section style={{ marginTop: '28px', borderTop: '1px solid rgba(255,255,255,0.08)', paddingTop: '20px' }}>
          <Text style={{ color: '#64748b', fontSize: '12px', lineHeight: '18px', margin: 0 }}>
            VERALIFY LTD · Company Number 17332341 · Registered in England and Wales.
          </Text>
          <Text style={{ color: '#64748b', fontSize: '12px', lineHeight: '18px', margin: '6px 0 0' }}>
            You're receiving this because you joined our waitlist.{' '}
            <Link href={unsubscribeUrl} style={{ color: '#64748b', textDecoration: 'underline' }}>
              Unsubscribe
            </Link>
            .
          </Text>
        </Section>
      </Container>
    </Body>
  </Html>
);

export default WaitlistWelcomeEmail;
