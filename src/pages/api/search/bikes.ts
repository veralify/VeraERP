import type { APIRoute } from 'astro';

export const GET: APIRoute = async ({ url }) => {
  const query = url.searchParams.get('q') || '';
  const page = url.searchParams.get('page') || '1';

  if (!query.trim()) {
    return new Response(JSON.stringify({ bikes: [], total: 0 }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const upstream = new URL('https://bikeindex.org/api/v3/search');
    upstream.searchParams.set('query', query.trim());
    upstream.searchParams.set('stolenness', 'all');
    upstream.searchParams.set('per_page', '12');
    upstream.searchParams.set('page', page);

    const response = await fetch(upstream.toString(), {
      headers: { Accept: 'application/json' },
    });

    if (!response.ok) {
      throw new Error(`BikeIndex responded with ${response.status}`);
    }

    const data = await response.json();
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Search failed';
    return new Response(JSON.stringify({ error: message, bikes: [] }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
};
