import type { BrandConfig } from './types';

export const veralifyBrand: BrandConfig = {
  id: 'veralify',
  name: 'Veralify',
  shortName: 'Veralify',
  websiteUrl: 'https://veralify.com',
  assets: {
    logoPath: '/favicon.svg',
    faviconPath: '/favicon.svg',
  },
  theme: {
    primary: '#3B82F6',
    authAccent: '#c6a15b',
    themeColor: '#3b82f6',
  },
  social: {
    xUrl: 'https://x.com/Veralify',
  },
  copy: {
    heroBadge: 'Coming soon · 2026',
    heroTitleLine1: 'Your passport',
    heroTitleLine2: 'to a borderless world.',
    heroDescription:
      'The first travel and telecom super-app built for modern explorers. Activate global internet in seconds, curate your perfect trip, and stay connected everywhere — zero friction, no roaming drama. Join us as we find better ways to explore the world.',
    authLandingHeader: 'Stay Connected Anywhere with Veralify',
    authLandingMessage: 'Join the Borderless Network',
    networkLabel: 'Veralify Network',
    networkTitle: 'Global eSIM Connectivity',
    highlights: [
      'Instant eSIM activation',
      'Coverage in 190+ countries',
      'No roaming, no surprises',
    ],
  },
};
