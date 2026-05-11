# Brutal - The neobrutalist Astro theme

Brutal is a minimal neobrutalist theme for [Astro](https://astro.build/). It's based on Neobrutalist Web Design, a movement that aims to create websites with a minimalistic and functional design. It has some integrations like Image Optimization, RSS, Sitemap, ready to get your SEO done right.

The theme has no JavaScript integration out of the box, but can always be added of course.

This template is based on [my own personal website](<https://www.elian.codes/>), with some more generic things added.

## Usage

You can bootstrap a new Astro project using Brutal with the following command:

```bash
# npm
npm create astro@latest -- --template eliancodes/brutal

# pnpm
pnpm create astro@latest --template eliancodes/brutal

# yarn
yarn create astro --template eliancodes/brutal
```

### Commands

All commands are run from the root of the project, from a terminal:

(Here I use PNPM, no problem if you use NPM or Yarn)

| Command             | Action                                             |
| :------------------ | :------------------------------------------------- |
| `pnpm install`      | Installs dependencies                              |
| `pnpm dev`          | Starts local dev server at `localhost:4321`        |
| `pnpm lint`         | Runs Biome lint checks                             |
| `pnpm format`       | Formats the project with Biome                     |
| `pnpm check`        | Runs Astro checks plus `biome check`               |
| `pnpm build`        | Build your production site to `./dist/`            |
| `pnpm preview`      | Preview your build locally, before deploying       |
| `pnpm astro ...`    | Run CLI commands like `astro add`, `astro preview` |
| `pnpm astro --help` | Get help using the Astro CLI                       |

## Tooling

This project uses [Biome](https://biomejs.dev/) for formatting, linting, and import organization.
Astro-specific diagnostics still run through `astro check`, so CI and local validation use both:

```bash
pnpm run check
```

## White-label brand architecture

Brand configuration now lives in:

- `src/config/brands/types.ts` (shared shape)
- `src/config/brands/veralify.ts` (Veralify brand config)
- `src/config/brands/index.ts` (active brand resolver)

Set the active brand with:

```bash
PUBLIC_BRAND=veralify
```

The app defaults to `veralify` when `PUBLIC_BRAND` is not set.

## Integrations

### Tailwind CSS

In this theme, I'm using [Tailwind CSS](https://tailwindcss.com/) to generate the utility classes. The project uses Astro's Tailwind setup with the Vite plugin, plus a small amount of regular CSS for the theme-specific scrollbar and shadow styling.

### Sitemap

To generate the sitemap, you don't need to do anything. It's automatically generated when you build your site. You'll just need to switch out the `site` on `astro.config.ts` to your own.

```js title="astro.config.mjs"
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://example.com',
});
```

### RSS

The RSS feed is automatically generated from the Markdown files in the `src/content/blog` folder. You can ofcourse completely change this to your own needs.

The RSS will output to `https://example.com/feed.xml` by default. You can change this, by renaming `src/pages/feed.xml.js`.

### Privy Social Auth + Embedded Solana Wallets

The navigation and hero now use a Web2-first onboarding flow powered by Privy with:

- Email
- Phone Number
- Google
- Apple
- Facebook (configured as a custom OAuth provider, e.g. `privy:facebook`)

Each authenticated user gets an embedded Solana wallet for minting.

Set these env vars:

```bash
PUBLIC_PRIVY_APP_ID=your_privy_app_id
PUBLIC_SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
PUBLIC_SUPABASE_URL=https://syehqhcexzgtxzavjpmw.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

### Vera Badge minting (MVP)

The homepage includes a **Create Vera Badge** form where users can:

1. Sign in with social/email/phone
2. Get an embedded Solana wallet automatically
3. Upload asset details and photos
4. Mint a compressed badge NFT (cNFT) to their wallet

Images and NFT metadata are uploaded by a Supabase-hosted Edge Function.

#### Supabase server setup

1. Create a public Storage bucket named `vera-badges` in your Supabase project.
2. Run DB migration to create users + eNFT tables:
   ```bash
   supabase db push
   ```
   This now also creates:
   - `vera_mint_payments` (resume paid-but-failed mints safely)
   - `registered_devices` (tracks embedded wallets and primary wallet selection)
3. In your terminal, login and link your Supabase project:
   ```bash
   supabase login
   supabase link --project-ref syehqhcexzgtxzavjpmw
   ```
4. Set required Edge Function secrets:
   ```bash
   supabase secrets set SUPABASE_URL=https://syehqhcexzgtxzavjpmw.supabase.co
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   supabase secrets set VERA_BADGE_STORAGE_BUCKET=vera-badges
   ```
5. Set cNFT mint secrets (service wallet + tree):
   ```bash
   supabase secrets set VERA_SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
   supabase secrets set VERA_CNFT_MINT_AUTHORITY_SECRET=your_base58_or_json_secret_key
   supabase secrets set VERA_CNFT_TREE_ADDRESS=your_merkle_tree_public_key
   # Optional only for first-time tree auto-create:
   # supabase secrets set VERA_CNFT_TREE_SECRET=your_merkle_tree_secret_key
   # Optional overrides:
   # supabase secrets set VERA_CNFT_MAX_DEPTH=14
   # supabase secrets set VERA_CNFT_MAX_BUFFER_SIZE=64
   ```
6. Deploy the functions:
   ```bash
   supabase functions deploy vera-badge-upload
   supabase functions deploy vera-badge-mint-compressed
   supabase functions deploy vera-badge-save
   supabase functions deploy vera-user-sync
   ```

During mint, a **0.001 SOL fee** is transferred to:

`CK1gBf6XyJaeZq1aS2gHsmrohA4gMDmPDBBu9hCBswnS`

### Image

## Components

### `components/blog/`

This directory contains all components for the blog.

### `components/errors/`

This directory contains all error components.

#### `components/errors/404.astro`

This component is used when a page is not found.

### `components/generic/`

This directory contains all generic components, reused over multiple pages.

### `components/home/`

This directory contains all components for the home page.

### `components/layout/`

This directory contains all layout components. For instance, the header and footer and `<head>` section.

If you need more from this theme, don't hesitate to open an issue or reach out to me!
