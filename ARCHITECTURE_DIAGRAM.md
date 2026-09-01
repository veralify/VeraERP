# Veralify Architecture Diagram

## Overview
Veralify is a fitness and social platform built with Next.js 15, featuring AI food tracking, communities, live rooms, and coach discovery. The application consists of a marketing/waitlist site and a member dashboard.

## Technology Stack

### Frontend
- **Framework**: Next.js 15 (App Router)
- **UI Library**: React 19
- **Styling**: Tailwind CSS 4
- **Deployment**: Vercel

### Backend & Services
- **Database & Auth**: Supabase (PostgreSQL + Auth)
- **Email**: Resend (transactional emails)
- **Payments**: Stripe
- **Analytics**: Vercel Analytics + Speed Insights

### Development Tools
- **Language**: TypeScript
- **Linting/Formatting**: Biome
- **Package Manager**: pnpm

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VERALIFY ARCHITECTURE                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                          CLIENT SIDE (Next.js 15)                             │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐      ┌──────────────────────┐      ┌──────────────────────┐
│   Marketing Site     │      │   Member Dashboard   │      │   Public Pages       │
│   (/)                 │      │   (/dashboard/*)     │      │   (/about, /privacy) │
├──────────────────────┤      ├──────────────────────┤      ├──────────────────────┤
│ • Landing page        │      │ • Dashboard overview │      │ • Static content     │
│ • Waitlist signup     │      │ • Food tracking      │      │ • Legal pages        │
│ • Feature showcase    │      │ • Progress tracking  │      │ • About page         │
│ • Auth widget         │      │ • Goals management   │      │                      │
└──────────┬───────────┘      └──────────┬───────────┘      └──────────┬───────────┘
           │                              │                              │
           └──────────────────────────────┼──────────────────────────────┘
                                          │
                    ┌─────────────────────┴─────────────────────┐
                    │          Next.js App Router               │
                    │  (Server Components + Route Handlers)      │
                    └─────────────────────┬─────────────────────┘
                                          │
┌─────────────────────────────────────────┼─────────────────────────────────────┐
│                    MIDDLEWARE LAYER      │                                     │
│  ┌─────────────────────────────────────┐│                                     │
│  │  middleware.ts                      ││                                     │
│  │  • dashboard.veralify.com redirect ││                                     │
│  │  • Supabase session refresh        ││                                     │
│  │  • Pathname header injection        ││                                     │
│  └─────────────────────────────────────┘│                                     │
└─────────────────────────────────────────┼─────────────────────────────────────┘
                                          │
┌─────────────────────────────────────────┼─────────────────────────────────────┐
│              SERVER SIDE SERVICES       │                                     │
│  ┌─────────────────────────────────────┐│  ┌─────────────────────────────────┐ │
│  │  Supabase Client Layer             ││  │  External API Integrations      │ │
│  ├─────────────────────────────────────┤│  ├─────────────────────────────────┤ │
│  │  • lib/supabase/server.ts           ││  │  • Resend (Email)               │ │
│  │  • lib/supabase/client.ts           ││  │  • Stripe (Payments)            │ │
│  │  • lib/supabase/middleware.ts       ││  │  • OpenAI (AI features)         │ │
│  └─────────────────────────────────────┘│  └─────────────────────────────────┘ │
└─────────────────────────────────────────┼─────────────────────────────────────┘
                                          │
┌─────────────────────────────────────────┼─────────────────────────────────────┐
│              ROUTE HANDLERS (API)       │                                     │
│  ┌─────────────────────────────────────┐│  ┌─────────────────────────────────┐ │
│  │  /api/waitlist                      ││  │  /api/stripe/*                  │ │
│  │  • Email signup                     ││  │  • Stripe webhooks              │ │
│  │  • Referral tracking                ││  │  • Subscription management       │ │
│  │  • Welcome emails                   ││  │                                 │ │
│  ├─────────────────────────────────────┤│  └─────────────────────────────────┘ │
│  │  /api/unsubscribe                   ││                                     │
│  │  • One-click unsubscribe            ││                                     │
│  ├─────────────────────────────────────┤│                                     │
│  │  /api/waitlist-count                ││                                     │
│  │  • Live subscriber count            ││                                     │
│  └─────────────────────────────────────┘│                                     │
└─────────────────────────────────────────┼─────────────────────────────────────┘
                                          │
┌─────────────────────────────────────────┼─────────────────────────────────────┐
│              DATABASE LAYER             │                                     │
│  ┌─────────────────────────────────────┐│                                     │
│  │         SUPABASE (PostgreSQL)        ││                                     │
│  ├─────────────────────────────────────┤│                                     │
│  │  Tables:                            ││                                     │
│  │  • profiles                         ││                                     │
│  │  • goals                            ││                                     │
│  │  • weight_entries                   ││                                     │
│  │  • daily_nutrition_summaries        ││                                     │
│  │  • group_members                    ││                                     │
│  │  • groups                           ││                                     │
│  │  • newsletter_subscribers           ││                                     │
│  │  • meals                            ││                                     │
│  │  • messages                         ││                                     │
│  ├─────────────────────────────────────┤│                                     │
│  │  Auth:                              ││                                     │
│  │  • User authentication              ││                                     │
│  │  • Session management               ││                                     │
│  │  • OAuth providers                  ││                                     │
│  └─────────────────────────────────────┘│                                     │
└─────────────────────────────────────────┼─────────────────────────────────────┘
                                          │
┌─────────────────────────────────────────┼─────────────────────────────────────┐
│              CLIENT STATE MANAGEMENT    │                                     │
│  ┌─────────────────────────────────────┐│  ┌─────────────────────────────────┐ │
│  │  ThemeProvider                      ││  │  LanguageProvider               │ │
│  │  • Day/Night mode                   ││  │  • i18n support                 │ │
│  │  • Cookie persistence               ││  │  • Locale detection             │ │
│  │  • No-flash script                  ││  │  • RTL support                   │ │
│  └─────────────────────────────────────┘│  └─────────────────────────────────┘ │
└─────────────────────────────────────────┼─────────────────────────────────────┘
                                          │
┌─────────────────────────────────────────┼─────────────────────────────────────┐
│              COMPONENT LAYER            │                                     │
│  ┌─────────────────────────────────────┐│  ┌─────────────────────────────────┐ │
│  │  Layout Components                  ││  │  Feature Components             │ │
│  │  • BaseNavigation                   ││  │  • AuthWidget/AuthModal         │ │
│  │  • BaseFooter                       ││  │  • MemberShell                  │ │
│  │  • MemberShell                      ││  │  • DashboardPrimitives         │ │
│  ├─────────────────────────────────────┤│  │  • GoalForm                     │ │
│  │  Marketing Components              ││  │  • MacroBars                    │ │
│  │  • HomePage                         ││  │  • EmptyState                   │ │
│  │  • Feature sections                ││  │                                 │ │
│  └─────────────────────────────────────┘│  └─────────────────────────────────┘ │
└─────────────────────────────────────────┼─────────────────────────────────────┘
```

## Key Data Flows

### 1. User Authentication Flow
```
User → AuthWidget → AuthModal → Supabase Auth
                                ↓
                         Exchange code for session
                                ↓
                         /auth/callback route
                                ↓
                         Set session cookies
                                ↓
                         Redirect to dashboard
```

### 2. Waitlist Signup Flow
```
User → /api/waitlist (POST)
        ↓
    Validate email & consent
        ↓
    Check existing subscriber
        ↓
    Upsert to Supabase (newsletter_subscribers)
        ↓
    Generate referral code
        ↓
    Send welcome email (Resend)
        ↓
    Notify referrer (if applicable)
        ↓
    Return success response
```

### 3. Dashboard Data Flow
```
User → /dashboard
        ↓
    Middleware: Refresh Supabase session
        ↓
    Dashboard layout: Check auth
        ↓
    Server component: Fetch user data
        • Profile
        • Daily nutrition summary
        • Active goal
        • Latest weight
        • Group memberships
        ↓
    Render dashboard with data
```

### 4. Food Tracking Flow
```
User → /dashboard/track
        ↓
    Log meal entry
        ↓
    Server action: Save to meals table
        ↓
    Trigger nutrition calculation
        ↓
    Update daily_nutrition_summaries
        ↓
    Real-time dashboard update
```

## Directory Structure

```
src/
├── app/                          # Next.js App Router
│   ├── layout.tsx               # Root layout with theme/i18n
│   ├── page.tsx                 # Marketing homepage
│   ├── dashboard/               # Member dashboard
│   │   ├── layout.tsx           # Auth-protected layout
│   │   ├── page.tsx             # Dashboard overview
│   │   ├── track/               # Food tracking
│   │   ├── nutrition/           # Nutrition details
│   │   ├── progress/            # Progress tracking
│   │   ├── goals/               # Goal management
│   │   ├── groups/              # Community groups
│   │   ├── live/                # Live rooms
│   │   ├── messages/            # Messaging
│   │   ├── ai/                  # AI features
│   │   ├── profile/             # User profile
│   │   ├── billing/             # Subscription management
│   │   └── coach/               # Coach features
│   ├── auth/                    # Auth routes
│   │   ├── callback/route.ts    # OAuth callback
│   │   └── signout/route.ts     # Sign out handler
│   ├── api/                     # API routes
│   │   ├── waitlist/            # Waitlist signup
│   │   ├── unsubscribe/         # Email unsubscribe
│   │   ├── waitlist-count/      # Live count
│   │   └── stripe/              # Stripe webhooks
│   └── v1/generate/og/          # Open Graph images
├── components/                  # React components
│   ├── layout/                  # Layout components
│   ├── home/                    # Homepage components
│   ├── auth/                    # Auth components
│   ├── member/                  # Dashboard components
│   ├── marketing/               # Marketing components
│   └── generic/                 # Shared components
├── lib/                         # Utility libraries
│   ├── supabase/                # Supabase clients
│   │   ├── server.ts            # Server-side client
│   │   ├── client.ts            # Browser client
│   │   └── middleware.ts        # Middleware client
│   ├── api/                     # API utilities
│   ├── auth/                    # Auth utilities
│   ├── stripe/                 # Stripe utilities
│   └── ai/                      # AI utilities
├── config/                      # Configuration
│   ├── brands.ts                # Brand configuration
│   └── site.ts                  # Site configuration
├── i18n/                        # Internationalization
│   ├── config.ts                # i18n config
│   ├── locales/                 # Translation files
│   └── LanguageProvider.tsx     # i18n provider
├── theme/                       # Theme system
│   └── ThemeProvider.tsx        # Theme provider
├── emails/                      # Email templates
│   ├── waitlist-welcome.tsx     # Welcome email
│   └── referral-notification.tsx # Referral email
└── middleware.ts                # Next.js middleware
```

## Environment Variables

### Public (Client-side)
- `NEXT_PUBLIC_BRAND` - Active brand ID
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Supabase anon key
- `NEXT_PUBLIC_PRIVY_APP_ID` - Privy auth (optional)
- `NEXT_PUBLIC_TWENTY_URL` - CRM link

### Server-side
- `SUPABASE_SERVICE_ROLE_KEY` - Supabase service role key
- `RESEND_API_KEY` - Resend API key
- `RESEND_FROM` - Verified sender email
- `STRIPE_SECRET_KEY` - Stripe secret key
- `STRIPE_WEBHOOK_SECRET` - Stripe webhook secret

## Key Features

### Marketing Site
- Landing page with feature showcase
- Waitlist signup with referral tracking
- Multi-language support (English, Arabic)
- Theme switching (day/night)
- SEO optimization with Open Graph images

### Member Dashboard
- **Food Tracking**: AI-powered meal logging
- **Nutrition**: Daily calorie and macro tracking
- **Progress**: Weight entries and progress charts
- **Goals**: Personalized fitness goals
- **Groups**: Community groups for accountability
- **Live**: Live rooms for real-time interaction
- **Messages**: In-app messaging
- **AI**: AI-powered features
- **Profile**: User profile management
- **Billing**: Subscription management via Stripe
- **Coach**: Coach discovery and interaction

### Authentication
- Supabase Auth with OAuth providers
- Session management via cookies
- Protected routes with middleware
- Auth widget for marketing site

### Email System
- Welcome emails for new subscribers
- Referral notification emails
- One-click unsubscribe (RFC-8058 compliant)
- Multi-language email templates

## Deployment

The application is deployed on Vercel with:
- Automatic deployments from Git
- Environment variable management
- Analytics and speed insights
- Custom domain configuration
- Edge network caching

## Development Workflow

```bash
# Install dependencies
pnpm install

# Start development server
pnpm dev

# Run linting
pnpm lint

# Format code
pnpm format

# Type checking
pnpm check

# Build for production
pnpm build

# Preview email templates
pnpm email
```

## Security Considerations

- Supabase Row Level Security (RLS) for data access
- Service role key only used server-side
- GDPR consent tracking for email signup
- Secure session management via httpOnly cookies
- CSRF protection via Next.js middleware
- Input validation on all API endpoints
