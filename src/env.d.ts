/// <reference path="../.astro/types.d.ts" />
/// <reference types="astro/client" />

interface ImportMetaEnv {
  readonly PUBLIC_BRAND?: string;
  readonly PUBLIC_TWENTY_URL?: string;
  readonly PUBLIC_SUPABASE_URL?: string;
  readonly PUBLIC_SUPABASE_ANON_KEY?: string;
  readonly SUPABASE_SERVICE_ROLE_KEY?: string;
  readonly PUBLIC_CANNY_SUBDOMAIN?: string;
  readonly PUBLIC_CANNY_BOARD_TOKEN?: string;
  readonly RESEND_API_KEY?: string;
  readonly RESEND_FROM?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
