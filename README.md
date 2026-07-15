# Veralify

The Veralify marketing site and admin dashboard — a waitlist / "coming soon" experience with
referral tracking, transactional email, and a lightweight admin dashboard.

Built with **Next.js 15 (App Router)**, **React 19**, and **Tailwind CSS 4**, deployed on **Vercel**.

## Stack

- **Framework:** Next.js 15 (App Router, server components + route handlers)
- **Styling:** Tailwind CSS 4 (via `@tailwindcss/postcss`)
- **Data:** Supabase (REST + Edge Functions, called over `fetch`)
- **Email:** Resend + React Email templates
- **Auth (optional):** Privy (`@privy-io/react-auth`)
- **Analytics:** Vercel Analytics + Speed Insights
- **Tooling:** Biome (lint/format), TypeScript

## Commands

All commands run from the project root:

| Command        | Action                                             |
| :------------- | :------------------------------------------------- |
| `pnpm install` | Install dependencies                               |
| `pnpm dev`     | Start the dev server at `localhost:3000`           |
| `pnpm build`   | Build the production site                          |
| `pnpm start`   | Serve the production build                         |
| `pnpm lint`    | Run Biome lint checks                              |
| `pnpm format`  | Format the project with Biome                      |
| `pnpm check`   | Run `biome check` plus `tsc --noEmit`              |
| `pnpm email`   | Preview React Email templates on port `3030`       |

## Project structure

```
src/
  app/                     # App Router routes
    layout.tsx             # Root layout (metadata, nav, footer, analytics)
    page.tsx               # Landing / waitlist (/)
    dashboard/             # Admin dashboard
    welcome/               # Post-signup confirmation
    privacy/, terms/       # Legal pages
    not-found.tsx          # 404
    sitemap.ts             # Dynamic sitemap
    api/                   # Route handlers
      waitlist/            # Signup + welcome / referral emails
      waitlist-count/      # Live subscriber count
      unsubscribe/         # RFC-8058 one-click + human unsubscribe
    v1/generate/og/        # Open Graph image (next/og)
  components/              # React components (layout, home, auth, dashboard, search)
  config/                  # Brand config + site URL helper
  emails/                  # React Email templates
  middleware.ts            # dashboard.veralify.com → /dashboard redirect
```

## Environment variables

Copy `.env.example` to `.env` and fill in the values. Client-exposed variables are prefixed
`NEXT_PUBLIC_`; everything else is server-only.

| Variable                        | Purpose                                  |
| :------------------------------ | :--------------------------------------- |
| `NEXT_PUBLIC_BRAND`             | Active brand id (`veralify`)             |
| `NEXT_PUBLIC_PRIVY_APP_ID`      | Enables the auth widget when set         |
| `NEXT_PUBLIC_TWENTY_URL`        | CRM link used in the dashboard           |
| `NEXT_PUBLIC_SUPABASE_URL`      | Supabase project URL                     |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anon key (client reads)         |
| `SUPABASE_SERVICE_ROLE_KEY`     | Server-only Supabase key (waitlist)      |
| `RESEND_API_KEY`                | Resend API key (transactional email)     |
| `RESEND_FROM`                   | Verified "from" address                  |

## Deployment

The app targets Vercel with zero extra configuration. The `dashboard.veralify.com` → `/dashboard`
redirect is handled by `src/middleware.ts`.
