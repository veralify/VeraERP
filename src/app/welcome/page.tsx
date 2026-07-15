import { CopyReferralLink } from '@components/home/CopyReferralLink';
import { getActiveBrand } from '@config/brands';
import type { Metadata } from 'next';

const brand = getActiveBrand();

export const metadata: Metadata = {
  title: `You're on the list | ${brand.name}`,
  description: `Thanks for joining the ${brand.name} waitlist.`,
};

type SearchParams = Promise<{ pos?: string; ref?: string; welcome?: string }>;

export default async function WelcomePage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const position = Number.parseInt(params.pos ?? '', 10);
  const refCode = params.ref ?? '';
  const hasPosition = Number.isFinite(position) && position > 0;
  const welcomeBack = params.welcome === 'back';
  const referralUrl = refCode ? `${brand.websiteUrl}/?ref=${refCode}` : brand.websiteUrl;
  const shareText = `I just joined the ${brand.name} waitlist — your passport to a borderless world. Join with my link and we both move up:`;

  return (
    <main
      className="relative flex min-h-[80vh] w-full items-center justify-center overflow-hidden px-6 py-16"
      style={{ backgroundColor: 'var(--page-bg)', color: 'var(--text-main)' }}
    >
      <div className="pointer-events-none absolute inset-0">
        <div
          className="absolute left-1/2 top-0 h-[24rem] w-[24rem] -translate-x-1/2 rounded-full blur-3xl"
          style={{ backgroundColor: `${brand.theme.primary}33` }}
        />
      </div>

      <section
        className="relative mx-auto w-full max-w-lg rounded-3xl border p-8 text-center shadow-[0_0_120px_rgba(232,65,37,0.22)] backdrop-blur-xl md:p-10"
        style={{ borderColor: 'var(--surface-border)', backgroundColor: 'var(--surface)' }}
      >
        <div
          className="mx-auto flex h-14 w-14 items-center justify-center rounded-full"
          style={{ backgroundColor: `${brand.theme.primary}22`, color: brand.theme.primary }}
        >
          <svg className="h-7 w-7" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path
              d="M20 6 9 17l-5-5"
              stroke="currentColor"
              strokeWidth={2.5}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>

        <h1 className="matrix-heading mt-5 text-2xl font-semibold md:text-3xl">
          {welcomeBack ? "You're already on the list — welcome back! 🌍" : "You're on the list! 🌍"}
        </h1>

        {hasPosition && (
          <div
            className="mx-auto mt-6 rounded-2xl border p-5"
            style={{
              borderColor: `${brand.theme.primary}33`,
              backgroundColor: 'var(--surface-elevated)',
            }}
          >
            <p
              className="matrix-text text-xs uppercase tracking-wide"
              style={{ color: 'var(--text-muted)' }}
            >
              Your position
            </p>
            <p className="matrix-heading text-5xl font-bold" style={{ color: brand.theme.primary }}>
              #{position}
            </p>
          </div>
        )}

        <p className="matrix-text mt-6 text-base" style={{ color: 'var(--text-muted)' }}>
          Want to move up? Every friend who joins with your link bumps you up the list — and the
          <strong style={{ color: 'var(--text-main)' }}> top 100 </strong> unlock an exclusive
          launch discount code.
        </p>

        <CopyReferralLink referralUrl={referralUrl} primaryColor={brand.theme.primary} />

        <div className="mt-4 flex items-center justify-center gap-3">
          <a
            href={`https://wa.me/?text=${encodeURIComponent(`${shareText} ${referralUrl}`)}`}
            target="_blank"
            rel="noopener noreferrer"
            className="matrix-text rounded-full border px-4 py-2 text-xs font-medium transition hover:brightness-110"
            style={{ borderColor: 'var(--surface-border)', color: 'var(--text-main)' }}
          >
            Share on WhatsApp
          </a>
          <a
            href={`https://twitter.com/intent/tweet?text=${encodeURIComponent(shareText)}&url=${encodeURIComponent(referralUrl)}`}
            target="_blank"
            rel="noopener noreferrer"
            className="matrix-text rounded-full border px-4 py-2 text-xs font-medium transition hover:brightness-110"
            style={{ borderColor: 'var(--surface-border)', color: 'var(--text-main)' }}
          >
            Share on X
          </a>
        </div>

        <a
          href="/"
          className="matrix-text mt-8 inline-block text-sm underline"
          style={{ color: 'var(--text-muted)' }}
        >
          Back to home
        </a>
      </section>
    </main>
  );
}
