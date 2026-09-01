# Veralify Architecture Diagram

## Overview
Veralify is a fitness coaching marketplace platform built with Next.js 15. The primary focus is a coaching marketplace where clients can discover, book, and pay fitness coaches, with Veralify taking a 15% platform fee. Additional features include AI food tracking, communities, live rooms, and subscription-based services.

## Business Model

### Revenue Streams (Prioritized)
1. **Coaching Marketplace** (Priority): 15% platform fee on paid coaching sessions
2. **Coach SaaS**: €19-49/month for coaches to manage clients
3. **Consumer Pro**: $9.99/month for AI food tracking and fitness features

### Marketplace Flow
```
Client books coach → Pays via Stripe Connect → Veralify keeps 15% → Coach gets 85% → Video call via Agora RTC
```

## Technology Stack

### Frontend
- **Framework**: Next.js 15 (App Router)
- **UI Library**: React 19
- **Styling**: Tailwind CSS 4
- **Deployment**: Vercel

### Backend & Services
- **Database & Auth**: Supabase (PostgreSQL + Auth)
- **Email**: Resend (transactional emails)
- **Payments**: Stripe (Subscription + Stripe Connect for marketplace)
- **Video**: Agora RTC (real-time video coaching sessions)
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
│   Marketing Site     │      │   Member Dashboard   │      │   Coach Portal       │
│   (/)                 │      │   (/dashboard/*)     │      │   (/coach/*)          │
├──────────────────────┤      ├──────────────────────┤      ├──────────────────────┤
│ • Landing page        │      │ • Dashboard overview │      │ • Coach profile      │
│ • Waitlist signup     │      │ • Coach discovery    │      │ • Session management  │
│ • Coach marketplace   │      │ • Session booking    │      │ • Availability        │
│ • Feature showcase    │      │ • Video calls        │      │ • Earnings dashboard  │
│ • Auth widget         │      │ • Progress tracking  │      │ • Client management   │
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
│  │  • lib/supabase/client.ts           ││  │  • Stripe (Payments + Connect)  │ │
│  │  • lib/supabase/middleware.ts       ││  │  • Agora RTC (Video calls)      │ │
│                                         ││  │  • OpenAI (AI features)         │ │
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
│  ├─────────────────────────────────────┤│  ┌─────────────────────────────────┐ │
│  │  /api/coaching/*                    ││  │  /api/agora/*                   │ │
│  │  • Coach profiles                   ││  │  • Video token generation        │ │
│  │  • Session booking                 ││  │  • Room management              │ │
│  │  • Availability management         ││  │  • Call analytics               │ │
│  │  • Payment processing              ││  └─────────────────────────────────┘ │
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
│  │  • coach_profiles                   ││                                     │
│  │  • coaching_sessions                ││                                     │
│  │  • session_bookings                 ││                                     │
│  │  • coach_availability               ││                                     │
│  │  • client_reviews                   ││                                     │
│  │  • stripe_accounts                 ││                                     │
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

### 5. Coaching Marketplace Flow (Priority)
```
Client → Browse coaches
        ↓
    Select coach & view profile
        ↓
    Book session (€50)
        ↓
    Stripe Connect payment
        ├── Client pays €50
        ├── Veralify keeps €7.50 (15%)
        └── Coach receives €42.50
        ↓
    Session scheduled
        ↓
    Agora RTC video call
        ├── Video room created
        ├── Client joins
        └── Coach joins
        ↓
    Session completed
        ↓
    Review & rating
```

### 6. Coach Onboarding Flow
```
Coach → Registration
        ↓
    Profile creation
        ↓
    Certification upload
        ↓
    Stripe Connect onboarding
        ↓
    Pricing setup
        ↓
    Availability calendar
        ↓
    Profile verified
        ↓
    Listed on marketplace
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
│   │   ├── stripe/              # Stripe webhooks + Connect
│   │   ├── coaching/            # Coaching marketplace
│   │   │   ├── coaches/         # Coach profiles
│   │   │   ├── sessions/        # Session booking
│   │   │   └── availability/    # Availability management
│   │   └── agora/               # Video call tokens
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
- `STRIPE_CONNECT_CLIENT_ID` - Stripe Connect client ID
- `STRIPE_CONNECT_SECRET_KEY` - Stripe Connect secret key
- `AGORA_APP_ID` - Agora RTC application ID
- `AGORA_APP_CERTIFICATE` - Agora RTC app certificate
- `AGORA_CUSTOMER_ID` - Agora customer ID (for REST API)
- `AGORA_CUSTOMER_SECRET` - Agora customer secret

## Key Features

### Marketing Site
- Landing page with feature showcase
- Coach marketplace preview
- Waitlist signup with referral tracking
- Multi-language support (English, Arabic)
- Theme switching (day/night)
- SEO optimization with Open Graph images

### Coaching Marketplace (Priority)
- **Coach Discovery**: Browse and search fitness coaches
- **Coach Profiles**: Detailed coach information, certifications, reviews
- **Session Booking**: Schedule 1:1 coaching sessions
- **Payment Processing**: Stripe Connect for secure payments
- **Platform Fee**: 15% fee on paid sessions
- **Video Calls**: Real-time video coaching via Agora RTC
- **Coach Dashboard**: Manage sessions, availability, earnings
- **Client Reviews**: Rating and review system

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
- Coach authentication and verification
- Stripe Connect onboarding for coaches

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

## Coaching Marketplace Architecture

### Marketplace Components
```
┌─────────────────────────────────────────────────────────────┐
│                    COACHING MARKETPLACE                      │
└─────────────────────────────────────────────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   CLIENT     │    │   VERALIFY   │    │    COACH     │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       │ 1. Browse         │                   │
       ├───────────────────┤                   │
       │                   │                   │
       │ 2. View Profile   │                   │
       ├───────────────────┤                   │
       │                   │                   │
       │ 3. Book Session   │                   │
       ├───────────────────┤ 4. Notification   │
       │                   ├───────────────────┤
       │ 5. Payment        │                   │
       ├───────────────────┤                   │
       │                   │                   │
       │    Stripe Connect │                   │
       │    ┌────────────┐ │                   │
       │    │ €50 pay   │ │                   │
       │    │ €7.50 fee │ │                   │
       │    │ €42.50    │ │                   │
       │    └────────────┘ │                   │
       │                   │                   │
       │ 6. Scheduled      │ 7. Payout         │
       ├───────────────────┼───────────────────┤
       │                   │                   │
       │ 8. Video Call     │ 9. Video Call     │
       │    Agora RTC      │    Agora RTC      │
       ├───────────────────┼───────────────────┤
       │                   │                   │
       │ 10. Review         │ 11. Rating        │
       └───────────────────┴───────────────────┘
```

### Database Schema for Marketplace
```sql
-- Coach profiles
CREATE TABLE coach_profiles (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  display_name TEXT,
  bio TEXT,
  certifications JSONB,
  specialties TEXT[],
  hourly_rate DECIMAL,
  currency TEXT DEFAULT 'EUR',
  verified BOOLEAN DEFAULT FALSE,
  rating_avg DECIMAL,
  review_count INTEGER,
  created_at TIMESTAMP
);

-- Coaching sessions
CREATE TABLE coaching_sessions (
  id UUID PRIMARY KEY,
  coach_id UUID REFERENCES coach_profiles(id),
  client_id UUID REFERENCES profiles(id),
  scheduled_at TIMESTAMP,
  duration_minutes INTEGER DEFAULT 60,
  price DECIMAL,
  currency TEXT DEFAULT 'EUR',
  status TEXT DEFAULT 'scheduled',
  agora_room_id TEXT,
  stripe_payment_intent_id TEXT,
  stripe_transfer_id TEXT,
  platform_fee DECIMAL,
  coach_payout DECIMAL,
  created_at TIMESTAMP
);

-- Coach availability
CREATE TABLE coach_availability (
  id UUID PRIMARY KEY,
  coach_id UUID REFERENCES coach_profiles(id),
  day_of_week INTEGER,
  start_time TIME,
  end_time TIME,
  is_available BOOLEAN DEFAULT TRUE
);

-- Client reviews
CREATE TABLE client_reviews (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES coaching_sessions(id),
  client_id UUID REFERENCES profiles(id),
  coach_id UUID REFERENCES coach_profiles(id),
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMP
);
```

## Security Considerations

- Supabase Row Level Security (RLS) for data access
- Service role key only used server-side
- GDPR consent tracking for email signup
- Secure session management via httpOnly cookies
- CSRF protection via Next.js middleware
- Input validation on all API endpoints
- Stripe Connect security for payment processing
- Agora RTC token generation for video calls
- Coach verification and certification checks
- PII protection for coach and client data
- Secure video call room management

## Revenue Model Implementation

### Platform Fee Calculation
```
Session Price: €50
Platform Fee: 15%
Veralify Revenue: €50 × 0.15 = €7.50
Coach Payout: €50 × 0.85 = €42.50
```

### Stripe Connect Flow
1. Coach onboarding → Create connected account
2. Client books session → Create payment intent
3. Process payment → Split payment (15% platform, 85% coach)
4. Automated payouts → Daily/weekly coach payouts
5. Tax reporting → 1099-K generation for coaches

### Agora RTC Integration
1. Session scheduled → Generate video token
2. Client joins → Create video room
3. Coach joins → Same video room
4. Session active → Real-time video/audio
5. Session ends → Room cleanup, analytics recorded
