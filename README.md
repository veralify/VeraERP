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

### Privy Auth

The navigation, hero, and dashboard use Privy social authentication.
Privy onboarding is configured for:

- Google, Apple, Facebook, Email, and Phone login
- Automatic embedded Solana wallet creation on login (for users without wallets)

Set these env vars:

```bash
PUBLIC_PRIVY_APP_ID=your_privy_app_id
PUBLIC_TWENTY_URL=https://crm.veralify.com
PUBLIC_SUPABASE_URL=https://syehqhcexzgtxzavjpmw.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

### Canny feedback board

The public feedback board renders at `/feedback` via the Canny SDK. Grab your values from
Canny (**Settings → your board → Install**) and set:

```bash
PUBLIC_CANNY_SUBDOMAIN=your-subdomain      # the `yoursubdomain` in yoursubdomain.canny.io
PUBLIC_CANNY_BOARD_TOKEN=your_board_token  # the boardToken shown on the Install tab
```

Until both are set, `/feedback` shows a placeholder (and a link to the hosted board if the
subdomain is present) instead of the embedded widget.

### Supabase user sync

Social identity is synced to Supabase through the `vera-user-sync` edge function.

1. Run migrations:
   ```bash
   supabase db push
   ```
2. In your terminal, login and link your Supabase project:
   ```bash
   supabase login
   supabase link --project-ref syehqhcexzgtxzavjpmw
   ```
3. Set required Edge Function secrets:
   ```bash
   supabase secrets set SUPABASE_URL=https://syehqhcexzgtxzavjpmw.supabase.co
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   supabase secrets set VERA_ADMIN_API_KEY=your_strong_admin_api_key
   supabase secrets set RESEND_API_KEY=your_resend_api_key
   supabase secrets set VERA_EMAIL_FROM='Veralify <noreply@yourdomain.com>'
   ```
4. Deploy the functions:
   ```bash
   supabase functions deploy vera-user-sync
   supabase functions deploy vera-newsletter-subscribe --no-verify-jwt
   supabase functions deploy vera-signup-submit --no-verify-jwt
   supabase functions deploy vera-blog-api --no-verify-jwt
   supabase functions deploy vera-users-api
   supabase functions deploy vera-newsletter-api
   ```

### Admin server APIs

Use the admin API key in either `Authorization: Bearer <key>` or `x-api-key: <key>`.

- `vera-users-api` actions:
  - `list_users`
  - `get_user`
  - `update_user_role`
- `vera-newsletter-api` actions:
  - `dashboard_bootstrap`
  - `send_campaign`
  - `list_subscribers`
  - `update_subscriber_status`
  - `delete_subscriber`
  - `stats`

- `vera-blog-api` actions:
  - Public: `list_published`, `get_published_post`
  - Admin: `admin_bootstrap`, `create_post`, `update_post`, `publish_post`, `unpublish_post`

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
