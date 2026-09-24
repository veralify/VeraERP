'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { currentUser, read } from '../actions/shared';
import {
  CATEGORY_KEYS,
  DEFAULT_KEY,
  decodeOption,
  isProvider,
  type MappingKind,
  UNKNOWN_TAX_KEY,
  untyped,
} from './lib';

const PAGE = '/dashboard/money/integrations';

/**
 * Starts the OAuth handshake: `accounting-connect` stores the state (and PKCE
 * verifier) server-side and hands back the provider's consent URL, which the
 * browser is sent to. The provider returns to `accounting-callback`, which
 * redirects back here with `?status=connected|error`.
 */
export async function connectProviderAction(formData: FormData) {
  const { supabase } = await currentUser();
  const provider = read(formData, 'provider');
  if (!isProvider(provider)) redirect(`${PAGE}?error=invalid`);

  const { data, error } = await supabase.functions.invoke<{ url?: string }>('accounting-connect', {
    body: { provider, return_to: 'web' },
  });
  const url = data?.url;
  if (error || !url || !url.startsWith('https://')) redirect(`${PAGE}?error=connect`);
  redirect(url);
}

export async function setAutoSyncAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const autoSync = read(formData, 'auto_sync') === 'true';
  const { error } = await untyped(supabase)
    .from('accounting_connections')
    .update({ auto_sync: autoSync })
    .eq('id', id)
    .eq('user_id', user.id);
  if (error) redirect(`${PAGE}?error=save`);
  revalidatePath(PAGE);
  redirect(`${PAGE}?saved=1`);
}

export async function setSyncScopeAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const scope = read(formData, 'sync_scope');
  if (scope !== 'business' && scope !== 'personal') redirect(`${PAGE}?error=invalid`);
  const { error } = await untyped(supabase)
    .from('accounting_connections')
    .update({ sync_scope: scope })
    .eq('id', id)
    .eq('user_id', user.id);
  if (error) redirect(`${PAGE}?error=save`);
  revalidatePath(PAGE);
  redirect(`${PAGE}?saved=1`);
}

export async function disconnectAction(formData: FormData) {
  const { supabase } = await currentUser();
  const id = read(formData, 'id');
  const { error } = await supabase.functions.invoke('accounting-disconnect', {
    body: { connection_id: id },
  });
  if (error) redirect(`${PAGE}?error=disconnect`);
  revalidatePath(PAGE);
  redirect(`${PAGE}?status=disconnected`);
}

const CATEGORY_KEY_SET = new Set([...CATEGORY_KEYS.map((c) => c.key), DEFAULT_KEY]);

/** Which local keys each mapping kind accepts (see accounting_mappings.local_key). */
function validKey(kind: MappingKind, key: string): boolean {
  switch (kind) {
    case 'category':
      return CATEGORY_KEY_SET.has(key);
    case 'tax_rate':
      return key === UNKNOWN_TAX_KEY || /^\d{1,3}(\.\d{1,2})?$/.test(key);
    case 'payment_account':
      return key === DEFAULT_KEY || /^[A-Z]{3}$/.test(key);
  }
}

/**
 * Saves the whole mapping form. Fields are named `<kind>:<local_key>`; a
 * chosen option is upserted, an emptied select deletes that mapping.
 */
export async function saveMappingsAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const connectionId = read(formData, 'connection_id');
  const db = untyped(supabase);
  const back = `${PAGE}?map=${encodeURIComponent(connectionId)}`;

  const { data: connection } = await db
    .from('accounting_connections')
    .select('id')
    .eq('id', connectionId)
    .eq('user_id', user.id)
    .maybeSingle();
  if (!connection) redirect(`${PAGE}?error=invalid`);

  const upserts: Record<string, string>[] = [];
  const removals: { kind: MappingKind; local_key: string }[] = [];
  for (const [name, raw] of formData.entries()) {
    if (typeof raw !== 'string') continue;
    const [kind, localKey] = name.split(':', 2) as [MappingKind, string | undefined];
    if (!localKey || !['category', 'tax_rate', 'payment_account'].includes(kind)) continue;
    if (!validKey(kind, localKey)) continue;
    const choice = decodeOption(raw);
    if (choice) {
      upserts.push({
        user_id: user.id,
        connection_id: connectionId,
        kind,
        local_key: localKey,
        external_id: choice.id,
        external_name: choice.name,
      });
    } else if (raw === '') {
      removals.push({ kind, local_key: localKey });
    }
  }

  if (upserts.length) {
    const { error } = await db
      .from('accounting_mappings')
      .upsert(upserts, { onConflict: 'connection_id,kind,local_key' });
    if (error) redirect(`${back}&error=save`);
  }
  for (const removal of removals) {
    const { error } = await db
      .from('accounting_mappings')
      .delete()
      .eq('connection_id', connectionId)
      .eq('user_id', user.id)
      .eq('kind', removal.kind)
      .eq('local_key', removal.local_key);
    if (error) redirect(`${back}&error=save`);
  }
  revalidatePath(PAGE);
  redirect(`${back}&saved=1`);
}
