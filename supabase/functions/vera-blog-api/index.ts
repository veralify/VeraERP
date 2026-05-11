// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });

const getApiKey = (req: Request) => {
  const bearer = req.headers.get('authorization');
  if (bearer?.startsWith('Bearer ')) {
    return bearer.replace('Bearer ', '').trim();
  }
  return req.headers.get('x-api-key')?.trim() || '';
};

const slugify = (value: string) =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .slice(0, 90);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const adminApiKey = Deno.env.get('VERA_ADMIN_API_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.' }, 500);
  }

  try {
    const payload = (await req.json()) as {
      action?:
        | 'list_published'
        | 'get_published_post'
        | 'admin_bootstrap'
        | 'create_post'
        | 'publish_post'
        | 'unpublish_post'
        | 'update_post';
      brand?: string;
      slug?: string;
      limit?: number;
      privyUserId?: string;
      postId?: string;
      title?: string;
      excerpt?: string;
      content?: string;
      publish?: boolean;
    };

    const action = payload.action;
    if (!action) {
      return jsonResponse({ error: 'Missing action.' }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const brand = payload.brand?.trim() || 'default';
    const publicActions = new Set(['list_published', 'get_published_post']);

    let adminUserId: string | null = null;
    if (!publicActions.has(action)) {
      const hasApiKeyAccess = Boolean(adminApiKey) && getApiKey(req) === adminApiKey;

      if (payload.privyUserId?.trim()) {
        const { data: adminUser, error: adminUserError } = await supabase
          .from('vera_users')
          .select('id, role')
          .eq('privy_user_id', payload.privyUserId.trim())
          .maybeSingle();
        if (adminUserError) {
          throw new Error(`Failed to authorize user: ${adminUserError.message}`);
        }
        if (adminUser?.role === 'admin') {
          adminUserId = adminUser.id;
        }
      }

      if (!hasApiKeyAccess && !adminUserId) {
        return jsonResponse({ error: 'Unauthorized.' }, 401);
      }
    }

    if (action === 'list_published') {
      const limit = Math.min(Math.max(payload.limit || 10, 1), 50);
      const { data, error } = await supabase
        .from('blog_posts')
        .select('id, title, slug, excerpt, content, published_at, created_at')
        .eq('brand', brand)
        .eq('status', 'published')
        .order('published_at', { ascending: false })
        .limit(limit);
      if (error) {
        throw new Error(`Failed to list posts: ${error.message}`);
      }
      return jsonResponse({ success: true, data: data || [] });
    }

    if (action === 'get_published_post') {
      const slug = payload.slug?.trim() || '';
      if (!slug) {
        return jsonResponse({ error: 'Missing slug.' }, 400);
      }
      const { data, error } = await supabase
        .from('blog_posts')
        .select('id, title, slug, excerpt, content, published_at, created_at')
        .eq('brand', brand)
        .eq('slug', slug)
        .eq('status', 'published')
        .maybeSingle();
      if (error) {
        throw new Error(`Failed to load post: ${error.message}`);
      }
      if (!data) {
        return jsonResponse({ error: 'Post not found.' }, 404);
      }
      return jsonResponse({ success: true, data });
    }

    if (action === 'admin_bootstrap') {
      const { data, error } = await supabase
        .from('blog_posts')
        .select('id, title, slug, status, excerpt, published_at, created_at')
        .eq('brand', brand)
        .order('created_at', { ascending: false })
        .limit(20);
      if (error) {
        throw new Error(`Failed to load admin blog posts: ${error.message}`);
      }
      return jsonResponse({ success: true, data: data || [] });
    }

    if (action === 'create_post') {
      const title = payload.title?.trim() || '';
      const content = payload.content?.trim() || '';
      if (!title || !content) {
        return jsonResponse({ error: 'Title and content are required.' }, 400);
      }

      const baseSlug = slugify(title);
      let slug = baseSlug;
      let suffix = 1;
      // keep slug unique per brand
      while (true) {
        const { data: exists, error: existsError } = await supabase
          .from('blog_posts')
          .select('id')
          .eq('brand', brand)
          .eq('slug', slug)
          .maybeSingle();
        if (existsError) {
          throw new Error(`Failed to check slug: ${existsError.message}`);
        }
        if (!exists) {
          break;
        }
        suffix += 1;
        slug = `${baseSlug}-${suffix}`;
      }

      const isPublished = Boolean(payload.publish);
      const { data, error } = await supabase
        .from('blog_posts')
        .insert({
          author_user_id: adminUserId,
          brand,
          title,
          slug,
          excerpt: payload.excerpt?.trim() || null,
          content,
          status: isPublished ? 'published' : 'draft',
          published_at: isPublished ? new Date().toISOString() : null,
          updated_at: new Date().toISOString(),
        })
        .select('id, title, slug, status, published_at')
        .single();
      if (error) {
        throw new Error(`Failed to create post: ${error.message}`);
      }
      return jsonResponse({ success: true, data });
    }

    if (action === 'publish_post' || action === 'unpublish_post') {
      const postId = payload.postId?.trim() || '';
      if (!postId) {
        return jsonResponse({ error: 'Missing postId.' }, 400);
      }

      const isPublish = action === 'publish_post';
      const { data, error } = await supabase
        .from('blog_posts')
        .update({
          status: isPublish ? 'published' : 'draft',
          published_at: isPublish ? new Date().toISOString() : null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', postId)
        .eq('brand', brand)
        .select('id, status, published_at')
        .maybeSingle();
      if (error) {
        throw new Error(`Failed to update post status: ${error.message}`);
      }
      if (!data) {
        return jsonResponse({ error: 'Post not found.' }, 404);
      }
      return jsonResponse({ success: true, data });
    }

    if (action === 'update_post') {
      const postId = payload.postId?.trim() || '';
      if (!postId) {
        return jsonResponse({ error: 'Missing postId.' }, 400);
      }
      const title = payload.title?.trim() || '';
      const content = payload.content?.trim() || '';
      if (!title || !content) {
        return jsonResponse({ error: 'Title and content are required.' }, 400);
      }

      const { data, error } = await supabase
        .from('blog_posts')
        .update({
          title,
          excerpt: payload.excerpt?.trim() || null,
          content,
          updated_at: new Date().toISOString(),
        })
        .eq('id', postId)
        .eq('brand', brand)
        .select('id, title, slug, status, updated_at')
        .maybeSingle();
      if (error) {
        throw new Error(`Failed to update post: ${error.message}`);
      }
      if (!data) {
        return jsonResponse({ error: 'Post not found.' }, 404);
      }
      return jsonResponse({ success: true, data });
    }

    return jsonResponse({ error: 'Unsupported action.' }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected blog API error.';
    return jsonResponse({ error: message }, 500);
  }
});
