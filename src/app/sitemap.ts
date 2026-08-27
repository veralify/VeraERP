import { getSiteUrl } from '@config/site';
import type { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  const base = getSiteUrl();
  const routes = [
    '',
    '/features',
    '/ai',
    '/tracking',
    '/communities',
    '/live',
    '/coaches',
    '/pricing',
    '/about',
    '/help',
    '/privacy',
    '/terms',
  ];

  return routes.map((route) => ({
    url: `${base}${route}`,
    lastModified: new Date(),
  }));
}
