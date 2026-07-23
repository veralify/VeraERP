import { BaseFooter } from '@components/layout/BaseFooter';
import { BaseNavigation } from '@components/layout/BaseNavigation';
import { getActiveBrand } from '@config/brands';
import { getSiteUrl } from '@config/site';
import { localeMeta, resolveLocale, STORAGE_KEY } from '@i18n/config';
import { LanguageProvider } from '@i18n/LanguageProvider';
import { THEME_KEY, ThemeProvider } from '@theme/ThemeProvider';
import { Analytics } from '@vercel/analytics/next';
import { SpeedInsights } from '@vercel/speed-insights/next';
import type { Metadata, Viewport } from 'next';
import { cookies, headers } from 'next/headers';
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

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const [cookieStore, headerList] = await Promise.all([cookies(), headers()]);
  const initialLocale = resolveLocale(
    cookieStore.get(STORAGE_KEY)?.value,
    headerList.get('accept-language'),
  );
  const dir = localeMeta[initialLocale].dir;

  // Explicit day/night preference is known server-side; 'auto'/unset defers to
  // the inline script below (which resolves by local clock before first paint).
  const storedTheme = cookieStore.get(THEME_KEY)?.value;
  const initialTheme = storedTheme === 'day' ? 'day' : 'night';
  const serverDataTheme =
    storedTheme === 'day' ? 'light' : storedTheme === 'night' ? 'dark' : undefined;

  const noFlashScript = `(function(){try{var m=document.cookie.match(/(?:^|; )veralify-theme=([^;]+)/);var v=m?decodeURIComponent(m[1]):(localStorage.getItem('veralify-theme')||'auto');var t=(v==='day'||v==='night')?v:((new Date().getHours()>=6&&new Date().getHours()<18)?'day':'night');document.documentElement.setAttribute('data-theme',t==='day'?'light':'dark');}catch(e){}})();`;

  return (
    <html
      lang={initialLocale}
      dir={dir}
      className="h-full"
      data-theme={serverDataTheme}
      suppressHydrationWarning
    >
      <head>
        {/* biome-ignore lint/security/noDangerouslySetInnerHtml: static no-flash theme script, no user input */}
        <script dangerouslySetInnerHTML={{ __html: noFlashScript }} />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Amiri:ital,wght@0,400;0,700;1,400&family=Tajawal:wght@400;500;700;800&display=swap"
        />
      </head>
      <body>
        <ThemeProvider initialTheme={initialTheme}>
          <LanguageProvider initialLocale={initialLocale}>
            <BaseNavigation />
            {children}
            <BaseFooter />
          </LanguageProvider>
        </ThemeProvider>
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
