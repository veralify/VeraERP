export type BrandId = 'veralify';

export type BrandConfig = {
  id: BrandId;
  name: string;
  shortName: string;
  websiteUrl: string;
  assets: {
    logoPath: string;
    faviconPath: string;
  };
  theme: {
    primary: string;
    authAccent: string;
    themeColor: string;
  };
  social: {
    xUrl: string;
  };
  copy: {
    heroBadge: string;
    heroTitleLine1: string;
    heroTitleLine2: string;
    heroDescription: string;
    authLandingHeader: string;
    authLandingMessage: string;
    networkLabel: string;
    networkTitle: string;
    highlights: string[];
  };
};
