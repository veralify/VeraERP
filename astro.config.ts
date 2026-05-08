import sitemap from '@astrojs/sitemap';
import react from '@astrojs/react';
import vercel from '@astrojs/vercel';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'astro/config';

export default defineConfig({
  // used to generate images
  site:
    process.env.VERCEL_ENV === 'production'
      ? 'https://veralify.com/'
      : process.env.VERCEL_URL
        ? `https://${process.env.VERCEL_URL}/`
        : 'http://localhost:3000/', // Changed to http as localhost is usually not https by default
  trailingSlash: 'ignore',
  output: 'server',
  integrations: [sitemap(), react()],
  adapter: vercel({
    webAnalytics: {
      enabled: true,
    },
  }),
  vite: {
    plugins: [tailwindcss()],
    optimizeDeps: {
      exclude: ['@resvg/resvg-js'],
    },
  },
});