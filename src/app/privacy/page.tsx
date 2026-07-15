import { getActiveBrand } from '@config/brands';
import type { Metadata } from 'next';

const brand = getActiveBrand();
const lastUpdated = '14 July 2026';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: `How ${brand.name} collects, uses, and protects your personal data.`,
};

export default function PrivacyPage() {
  return (
    <main
      className="mx-auto w-full max-w-3xl px-6 py-16"
      style={{ backgroundColor: 'var(--page-bg)', color: 'var(--text-main)' }}
    >
      <h1 className="matrix-heading text-3xl font-semibold md:text-4xl">Privacy Policy</h1>
      <p className="matrix-text mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
        Last updated: {lastUpdated}
      </p>

      <div
        className="matrix-text mt-8 space-y-6 text-sm leading-relaxed md:text-base"
        style={{ color: 'var(--text-muted)' }}
      >
        <p>
          This Privacy Policy explains how VERALIFY LTD (&quot;Veralify&quot;, &quot;we&quot;,
          &quot;us&quot;) collects, uses, and protects your personal data when you use our website
          and services. Veralify is a company registered in England and Wales (Company Number:
          17332341).
        </p>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            1. Data we collect
          </h2>
          <p>
            We collect information you provide directly to us (e.g., email address, contact
            details). Additionally, as you use our services, we automatically collect technical data
            such as IP addresses, browser types, and usage patterns to ensure our services function
            correctly and securely.
          </p>
        </section>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            2. How we use your data
          </h2>
          <p>
            We use your data to operate the service, process your requests, communicate product
            updates, and fulfill our contractual obligations. We do not sell your personal data.
          </p>
        </section>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            3. Third-party sharing
          </h2>
          <p>
            To provide eSIM connectivity and essential services, we may share necessary data with
            trusted third-party service providers (e.g., telecommunication carriers, payment
            processors, and cloud infrastructure providers). We ensure these partners adhere to
            strict data protection standards.
          </p>
        </section>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            4. Data security
          </h2>
          <p>
            We implement appropriate technical and organizational measures to protect your personal
            data against unauthorized access, loss, or alteration. We use industry-standard
            encryption protocols for data transmission.
          </p>
        </section>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            5. Your rights &amp; complaints
          </h2>
          <p>
            Under the UK GDPR, you have the right to access, correct, or delete your data. You may
            also object to processing. To exercise these rights, contact us at the address below. If
            you are unsatisfied with our response, you have the right to lodge a complaint with the{' '}
            <strong>Information Commissioner&rsquo;s Office (ICO)</strong>.
          </p>
        </section>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            6. Contact
          </h2>
          <p>
            VERALIFY LTD
            <br />
            Registered in England and Wales. Company Number: 17332341
            <br />
            Registered Office: 71-75 Shelton Street, Covent Garden, London, WC2H 9JQ
            <br />
            Email:{' '}
            <a href="mailto:privacy@veralify.com" className="underline hover:text-[#3B82F6]">
              privacy@veralify.com
            </a>
          </p>
        </section>
      </div>
    </main>
  );
}
