import sitemap from '@astrojs/sitemap';
import react from '@astrojs/react';
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
  // Keep it here:
  adapter: vercel({
    webAnalytics: { enabled: true },
  }),
  // Remove it from here:
  integrations: [
    sitemap(), 
    react()
    // vercel() <--- DELETE THIS LINE
  ],
  vite: {
    plugins: [tailwindcss()],
    optimizeDeps: {
      exclude: ['@resvg/resvg-js'],
    },
  },
});