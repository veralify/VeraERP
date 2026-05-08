import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const sanitizeFileName = (name: string) =>
  name
    .toLowerCase()
    .replace(/[^a-z0-9.\-_]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const bucket = Deno.env.get('VERA_BADGE_STORAGE_BUCKET') || 'vera-badges';

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in function secrets.' },
      500,
    );
  }

  try {
    const data = await req.formData();
    const assetName = String(data.get('assetName') ?? '').trim();
    const description = String(data.get('description') ?? '').trim();
    const category = String(data.get('category') ?? '').trim();
    const serialNumber = String(data.get('serialNumber') ?? '').trim();
    const photos = data
      .getAll('photos')
      .filter((item): item is File => item instanceof File && item.size > 0);

    if (!assetName || !description) {
      return jsonResponse({ error: 'Asset name and description are required.' }, 400);
    }

    if (photos.length === 0) {
      return jsonResponse({ error: 'At least one photo is required.' }, 400);
    }

    if (photos.length > 5) {
      return jsonResponse({ error: 'Maximum 5 photos are allowed.' }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const createdAt = Date.now();
    const basePath = `vera-badges/${createdAt}-${crypto.randomUUID()}`;

    const photoUrls: string[] = [];

    for (const [index, photo] of photos.entries()) {
      const ext = photo.name.split('.').pop()?.toLowerCase() || 'jpg';
      const safeName = sanitizeFileName(photo.name.replace(/\.[^.]+$/, '')) || `photo-${index + 1}`;
      const storagePath = `${basePath}/images/${index + 1}-${safeName}.${ext}`;

      const { error: uploadError } = await supabase.storage
        .from(bucket)
        .upload(storagePath, photo, {
          contentType: photo.type || 'image/jpeg',
          upsert: false,
        });

      if (uploadError) {
        return jsonResponse({ error: `Image upload failed: ${uploadError.message}` }, 500);
      }

      const { data: publicData } = supabase.storage.from(bucket).getPublicUrl(storagePath);
      photoUrls.push(publicData.publicUrl);
    }

    const metadata = {
      name: `${assetName} • Vera Badge`,
      symbol: 'VERA',
      description,
      image: photoUrls[0],
      properties: {
        category: 'image',
        files: photoUrls.map((url, index) => ({
          uri: url,
          type: photos[index]?.type || 'image/*',
        })),
      },
      attributes: [
        { trait_type: 'Category', value: category || 'Unspecified' },
        { trait_type: 'Serial Number', value: serialNumber || 'N/A' },
        { trait_type: 'Project', value: 'Veralify' },
      ],
      external_url: 'https://veralify.com',
      created_at: new Date(createdAt).toISOString(),
    };

    const metadataPath = `${basePath}/metadata.json`;
    const { error: metadataError } = await supabase.storage
      .from(bucket)
      .upload(metadataPath, JSON.stringify(metadata, null, 2), {
        contentType: 'application/json',
        upsert: false,
      });

    if (metadataError) {
      return jsonResponse({ error: `Metadata upload failed: ${metadataError.message}` }, 500);
    }

    const { data: metadataPublicData } = supabase.storage.from(bucket).getPublicUrl(metadataPath);

    return jsonResponse({
      metadataUri: metadataPublicData.publicUrl,
      metadataGatewayUrl: metadataPublicData.publicUrl,
      photoUris: photoUrls,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected upload error.';
    return jsonResponse({ error: message }, 500);
  }
});
