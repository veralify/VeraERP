import react from '@astrojs/react';
import sitemap from '@astrojs/sitemap';
import vercel from '@astrojs/vercel';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'astro/config';

export default defineConfig({
  site:
    process.env.VERCEL_ENV === 'production'
      ? 'https://veralify.com/'
      : process.env.VERCEL_URL
        ? `https://${process.env.VERCEL_URL}/`
        : 'http://localhost:3000/',
  trailingSlash: 'ignore',
  output: 'server',
  // The only state-changing endpoints (/api/waitlist, /api/unsubscribe) are
  // public and token-authorised — no cookie/session to abuse — so Astro's
  // CSRF origin check adds no protection but blocks Gmail's RFC-8058 one-click
  // unsubscribe (a cross-origin form POST). Disable it so one-click works.
  security: {
    checkOrigin: false,
  },
  // Keep it here:
  adapter: vercel({
    webAnalytics: { enabled: true },
  }),
  // Remove it from here:
  integrations: [sitemap(), react()],
  vite: {
    plugins: [tailwindcss()],
    optimizeDeps: {
      exclude: ['@resvg/resvg-js'],
    },
  },
});
