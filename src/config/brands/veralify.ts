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
    heroBadge: 'Coming Soon',
    heroTitleLine1: 'The trust layer',
    heroTitleLine2: 'for physical assets.',
    heroDescription:
      'Veralify helps users verify ownership and risk signals before buying, selling, or transferring high-value items.',
    authLandingHeader: 'Secure Your Assets with Veralify',
    authLandingMessage: 'Join the Global Registry',
    networkLabel: 'Veralify Network',
    networkTitle: 'Ownership Verification API',
    highlights: ['Real-time risk checks', 'Stolen item intelligence', 'Transfer-ready provenance'],
  },
};
