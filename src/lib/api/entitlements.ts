import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from './database.types';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';

type UserEntitlementRow = Database['public']['Tables']['user_entitlements']['Row'];
export type UserEntitlement = Pick<
  UserEntitlementRow,
  'id' | 'user_id' | 'lookup_key' | 'source' | 'active' | 'limit_value' | 'expires_at' | 'updated_at'
>;

const entitlementSelect =
  'id,user_id,lookup_key,source,active,limit_value,expires_at,updated_at' as const;

function activeEntitlementsQuery(client: SupabaseClient<Database>, userId: string) {
  return client
    .from('user_entitlements')
    .select(entitlementSelect)
    .eq('user_id', userId)
    .eq('active', true)
    .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
    .order('lookup_key', { ascending: true });
}

export async function getUserEntitlements(userId: string): Promise<UserEntitlement[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await activeEntitlementsQuery(supabase, userId);
  if (error) throw error;
  return data ?? [];
}

export async function getUserEntitlementsService(userId: string): Promise<UserEntitlement[]> {
  const { data, error } = await activeEntitlementsQuery(
    supabaseAdmin as SupabaseClient<Database>,
    userId,
  );
  if (error) throw error;
  return data ?? [];
}

export function hasEntitlement(entitlements: readonly Pick<UserEntitlement, 'lookup_key'>[], key: string) {
  return entitlements.some((entitlement) => entitlement.lookup_key === key);
}
