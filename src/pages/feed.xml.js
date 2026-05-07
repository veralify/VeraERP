import { getCollection } from 'astro:content';
import rss from '@astrojs/rss';

export async function GET(context) {
  const blog = await getCollection('blog');
  return rss({
    title: 'Veralify Blog',
    description: 'Updates and insights from Veralify',
    stylesheet: false,
    site: context.site,
    items: blog.map((post) => ({
      title: post.data.title,
      pubDate: post.data.pubDate,
      description: post.data.description,
      link: `/blog/${post.id}/`,
    })),
    customData: '<language>en-us</language>',
    canonicalUrl: 'https://veralify.com',
  });
}
