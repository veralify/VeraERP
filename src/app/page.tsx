import { HomePage as MarketingHomePage } from '@components/marketing/HomePage';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Veralify | Track. Connect. Transform.',
  description:
    'AI food tracking, fitness communities, live rooms, coach discovery, and progress accountability in one Pro subscription.',
  openGraph: {
    title: 'Veralify | Track. Connect. Transform.',
    description:
      'AI food tracking, real communities, live rooms, and coaches for your fitness transformation.',
    images: ['/v1/generate/og/default.png'],
  },
};

export default function HomePage() {
  return <MarketingHomePage />;
}
