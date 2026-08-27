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
    primary: '#4D95F7',
    authAccent: '#DE6C15',
    themeColor: '#050609',
  },
  social: {
    xUrl: 'https://x.com/Veralify',
  },
  copy: {
    heroBadge: 'Fitness and social platform',
    heroTitleLine1: 'Track. Connect.',
    heroTitleLine2: 'Transform.',
    heroDescription:
      'AI food tracking, goals, progress, communities, live rooms, messaging, and coach discovery in one Pro experience.',
    authLandingHeader: 'Start your Veralify transformation',
    authLandingMessage: 'Track. Connect. Transform.',
    networkLabel: 'Veralify Pro',
    networkTitle: 'AI fitness accountability',
    highlights: [
      'AI-powered food and nutrition tracking',
      'Communities and live rooms for accountability',
      'Coach discovery when you need human support',
    ],
  },
};
