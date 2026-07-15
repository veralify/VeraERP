import { BaseFooter } from '@components/layout/BaseFooter';
import { BaseNavigation } from '@components/layout/BaseNavigation';
import { getActiveBrand } from '@config/brands';
import { getSiteUrl } from '@config/site';
import { LanguageProvider } from '@i18n/LanguageProvider';
import { Analytics } from '@vercel/analytics/next';
import { SpeedInsights } from '@vercel/speed-insights/next';
import type { Metadata, Viewport } from 'next';
import './globals.css';

const brand = getActiveBrand();

export const metadata: Metadata = {
  metadataBase: new URL(getSiteUrl()),
  title: {
    default: brand.name,
    template: `%s | ${brand.name}`,
  },
  description: `Sign up to get upcoming ${brand.name} updates.`,
  manifest: '/manifest.json',
  icons: {
    icon: { url: brand.assets.faviconPath, type: 'image/svg+xml' },
    shortcut: { url: brand.assets.faviconPath, type: 'image/svg+xml' },
  },
  openGraph: {
    type: 'website',
    images: ['/v1/generate/og/default.png'],
  },
  twitter: {
    card: 'summary_large_image',
    images: ['/v1/generate/og/default.png'],
  },
};

export const viewport: Viewport = {
  themeColor: brand.theme.themeColor,
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="h-full">
      <body>
        <LanguageProvider>
          <BaseNavigation />
          {children}
          <BaseFooter />
        </LanguageProvider>
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
