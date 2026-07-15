import { getSiteUrl } from '@config/site';
import type { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  const base = getSiteUrl();
  const routes = ['', '/privacy', '/terms', '/welcome'];

  return routes.map((route) => ({
    url: `${base}${route}`,
    lastModified: new Date(),
  }));
}
