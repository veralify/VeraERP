import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Help',
  description: 'Contact Veralify support and read common product and billing answers.',
};

const faqs = [
  ['How do I start?', 'Create an account, choose a Pro billing option, and begin with tracking.'],
  [
    'Is there a free tier?',
    'No. Veralify launches with a 3-day Pro trial and read-only access if a subscription lapses.',
  ],
  [
    'How do I manage billing?',
    'Web subscribers can manage billing from the Billing page or pricing page when signed in.',
  ],
  [
    'How do I contact support?',
    'Email support@veralify.com with your account email and a clear description of the issue.',
  ],
];

export default function HelpPage() {
  return (
    <main className="bg-vera-bg px-6 py-20 text-vera-fg">
      <section className="mx-auto max-w-4xl">
        <p className="text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">Help</p>
        <h1 className="mt-3 text-4xl font-black tracking-tight sm:text-6xl">How can we help?</h1>
        <p className="mt-5 text-vera-fg-muted">
          For account, product, privacy, or billing support, contact{' '}
          <a className="text-vera-primary underline" href="mailto:support@veralify.com">
            support@veralify.com
          </a>
          .
        </p>
        <div className="mt-10 divide-y divide-vera-border rounded-vera-2xl border border-vera-border bg-vera-surface">
          {faqs.map(([question, answer]) => (
            <details key={question} className="group p-6">
              <summary className="cursor-pointer font-semibold">{question}</summary>
              <p className="mt-3 text-sm leading-6 text-vera-fg-muted">{answer}</p>
            </details>
          ))}
        </div>
      </section>
    </main>
  );
}
