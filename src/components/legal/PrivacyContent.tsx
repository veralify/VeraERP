export function PrivacyContent() {
  const sections = [
    [
      '1. Data we collect',
      'We collect information you provide directly, including account details, email address, profile information, nutrition and fitness entries, community activity, messages, billing identifiers, and support requests. We also collect technical data needed to operate, secure, and improve the service.',
    ],
    [
      '2. How we use data',
      'We use data to provide Veralify features, authenticate users, process subscriptions, operate AI-assisted tracking, support communities and live rooms, send service communications, prevent abuse, and meet legal obligations. We do not sell personal data.',
    ],
    [
      '3. Service providers',
      'We may share necessary data with trusted providers such as hosting, authentication, payment, email, analytics, and communications providers. These providers process data only for Veralify business purposes.',
    ],
    [
      '4. Health and fitness context',
      'Nutrition and fitness information can be sensitive. Use Veralify for tracking and accountability; it is not a medical device and does not replace professional medical advice.',
    ],
    [
      '5. Your rights',
      'Under applicable privacy law, including UK GDPR where relevant, you may request access, correction, deletion, restriction, portability, or objection. Contact us to exercise these rights.',
    ],
  ];

  return (
    <main className="mx-auto w-full max-w-3xl bg-vera-bg px-6 pb-40 pt-16 text-vera-fg">
      <h1 className="text-3xl font-semibold md:text-4xl">Privacy Policy</h1>
      <p className="mt-2 text-sm text-vera-fg-muted">Last updated: 27 August 2026</p>
      <div className="mt-8 space-y-6 text-sm leading-relaxed text-vera-fg-muted md:text-base">
        <p>
          This Privacy Policy explains how VERALIFY LTD ("Veralify", "we", "us") collects, uses, and
          protects personal data when you use our website and services.
        </p>
        {sections.map(([heading, body]) => (
          <section key={heading} className="space-y-2">
            <h2 className="text-lg font-semibold text-vera-fg">{heading}</h2>
            <p>{body}</p>
          </section>
        ))}
        <section className="space-y-2">
          <h2 className="text-lg font-semibold text-vera-fg">6. Contact</h2>
          <p>
            VERALIFY LTD
            <br />
            Registered in England and Wales. Company Number: 17332341
            <br />
            Registered Office: 71-75 Shelton Street, Covent Garden, London, WC2H 9JQ
            <br />
            Email:{' '}
            <a href="mailto:privacy@veralify.com" className="text-vera-primary underline">
              privacy@veralify.com
            </a>
          </p>
        </section>
      </div>
    </main>
  );
}
