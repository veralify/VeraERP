import { getActiveBrand } from '@config/brands';
import type { Metadata } from 'next';

const brand = getActiveBrand();
const lastUpdated = '14 July 2026';

export const metadata: Metadata = {
  title: 'Terms of Service',
  description: `The terms governing your use of ${brand.name}.`,
};

export default function TermsPage() {
  return (
    <main
      className="mx-auto w-full max-w-3xl px-6 py-16"
      style={{ backgroundColor: 'var(--page-bg)', color: 'var(--text-main)' }}
    >
      <h1 className="matrix-heading text-3xl font-semibold md:text-4xl">Terms of Service</h1>
      <p className="matrix-text mt-2 text-sm" style={{ color: 'var(--text-muted)' }}>
        Last updated: {lastUpdated}
      </p>

      <div
        className="matrix-text mt-8 space-y-6 text-sm leading-relaxed md:text-base"
        style={{ color: 'var(--text-muted)' }}
      >
        <p>
          These Terms of Service (&quot;Terms&quot;) govern your access to and use of the website
          and services provided by VERALIFY LTD (&quot;Veralify&quot;, &quot;we&quot;,
          &quot;us&quot;), a company registered in England and Wales (Company Number: 17332341). By
          using our services, you agree to these Terms.
        </p>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            1. Use of the service
          </h2>
          <p>
            You agree to use Veralify only for lawful purposes and in accordance with these Terms.
            You are responsible for any activity carried out through your account.
          </p>
        </section>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            2. Waitlist and communications
          </h2>
          <p>
            Joining our waitlist does not guarantee access to any product or service. By submitting
            your email, you consent to receive product updates from Veralify, which you may opt out
            of at any time.
          </p>
        </section>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            3. Intellectual property
          </h2>
          <p>
            All content, trademarks, and materials on this site are owned by or licensed to Veralify
            and may not be used without our prior written permission.
          </p>
        </section>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            4. Disclaimer and liability
          </h2>
          <p>
            The service is provided &quot;as is&quot; without warranties of any kind. To the fullest
            extent permitted by law, Veralify shall not be liable for any indirect or consequential
            loss arising from your use of the service. Nothing in these Terms limits liability that
            cannot be limited under applicable law.
          </p>
        </section>

        <section className="space-y-2">
          <h2
            className="matrix-heading text-lg font-semibold"
            style={{ color: 'var(--text-main)' }}
          >
            5. Governing law
          </h2>
          <p>
            These Terms are governed by the laws of England and Wales, and any disputes are subject
            to the exclusive jurisdiction of the courts of England and Wales.
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
            VERALIFY LTD, registered in England and Wales, Company Number 17332341. Contact us via{' '}
            <a href={brand.websiteUrl} className="underline hover:text-[#3B82F6]">
              {brand.websiteUrl}
            </a>
            .
          </p>
        </section>
      </div>
    </main>
  );
}
