import { WelcomeContent } from '@components/home/WelcomeContent';
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

  return (
    <WelcomeContent
      position={hasPosition ? position : 0}
      hasPosition={hasPosition}
      welcomeBack={welcomeBack}
      referralUrl={referralUrl}
    />
  );
}
