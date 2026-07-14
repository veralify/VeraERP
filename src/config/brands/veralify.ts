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
    primary: '#E84125',
    authAccent: '#c6a15b',
    themeColor: '#e84125',
  },
  social: {
    xUrl: 'https://x.com/Veralify',
  },
  copy: {
    heroBadge: 'New!',
    heroTitleLine1: 'Your passport',
    heroTitleLine2: 'to a borderless world.',
    heroDescription:
      'Veralify keeps you connected the moment you land. Activate global internet in seconds with a travel-ready eSIM — no roaming fees, no SIM swaps, no friction.',
    authLandingHeader: 'Stay Connected Anywhere with Veralify',
    authLandingMessage: 'Join the Borderless Network',
    networkLabel: 'Veralify Network',
    networkTitle: 'Global eSIM Connectivity',
    highlights: ['Instant eSIM activation', 'Coverage in 190+ countries', 'No roaming, no surprises'],
  },
};
