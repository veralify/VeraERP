import { getActiveBrand } from '@config/brands';

export function TermsContent() {
  const brand = getActiveBrand();
  const sections = [
    [
      '1. Use of the service',
      'You agree to use Veralify only for lawful purposes and in accordance with these Terms. You are responsible for activity on your account.',
    ],
    [
      '2. Fitness and nutrition information',
      'Veralify provides tracking, accountability, AI-assisted insights, community, live room, and coach discovery features. It is not medical advice, diagnosis, or treatment.',
    ],
    [
      '3. Subscriptions',
      'Veralify Pro is a paid subscription with a 3-day trial where offered. Web subscriptions are processed through Stripe. iOS digital subscriptions are processed through Apple In-App Purchase.',
    ],
    [
      '4. Communities and conduct',
      'You must not harass others, share unlawful content, or misuse live rooms, messages, groups, or coach interactions. We may restrict access to protect members and the platform.',
    ],
    [
      '5. Intellectual property',
      'All content, trademarks, software, and materials on this site are owned by or licensed to Veralify and may not be used without prior written permission.',
    ],
    [
      '6. Disclaimer and liability',
      'The service is provided as is. To the fullest extent permitted by law, Veralify is not liable for indirect or consequential loss. Nothing limits liability that cannot be limited by law.',
    ],
    [
      '7. Governing law',
      'These Terms are governed by the laws of England and Wales, and disputes are subject to the exclusive jurisdiction of the courts of England and Wales.',
    ],
  ];

  return (
    <main className="mx-auto w-full max-w-3xl bg-vera-bg px-6 pb-40 pt-16 text-vera-fg">
      <h1 className="text-3xl font-semibold md:text-4xl">Terms of Service</h1>
      <p className="mt-2 text-sm text-vera-fg-muted">Last updated: 27 August 2026</p>
      <div className="mt-8 space-y-6 text-sm leading-relaxed text-vera-fg-muted md:text-base">
        <p>
          These Terms govern your access to and use of the website and services provided by VERALIFY
          LTD, a company registered in England and Wales.
        </p>
        {sections.map(([heading, body]) => (
          <section key={heading} className="space-y-2">
            <h2 className="text-lg font-semibold text-vera-fg">{heading}</h2>
            <p>{body}</p>
          </section>
        ))}
        <section className="space-y-2">
          <h2 className="text-lg font-semibold text-vera-fg">8. Contact</h2>
          <p>
            VERALIFY LTD, registered in England and Wales, Company Number 17332341. Contact us via{' '}
            <a href={brand.websiteUrl} className="text-vera-primary underline">
              {brand.websiteUrl}
            </a>
            .
          </p>
        </section>
      </div>
    </main>
  );
}
