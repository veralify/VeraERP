# veraERP MVP Roadmap

> Working note: this is a product/engineering plan, not legal advice. Verify licensing, trademark, and hosting obligations before launch.

## Goal

Create **veraERP** as a white-labeled, multi-tenant B2B SaaS built from Odoo Community, with isolated tenant deployments, billing, and a small set of custom addons.

## Principles

- Keep custom business logic in separate addons.
- Prefer one tenant per container + database for strong isolation.
- Automate provisioning, renewal, suspension, and teardown.
- Add only the minimum OCA modules needed for parity.

## Phase 0 — Foundation

1. Fork `odoo/odoo` into a private veraERP repo.
2. Choose the target Odoo version and freeze it.
3. Define branding: `veraERP`, logo, theme, login page, favicon, emails.
4. Decide tenant model: container-per-client.
5. Create baseline Docker image, PostgreSQL config, and reverse proxy layout.

## Phase 1 — Core Product

1. Build a `veraerp_branding` addon.
2. Build a `veraerp_tenant` addon for tenant metadata.
3. Add admin-only provisioning screens or APIs.
4. Add domain/subdomain routing for each tenant.
5. Implement superuser-safe defaults and tenant isolation checks.

## Phase 2 — SaaS Automation

1. Stripe checkout for plan purchase.
2. Webhook handler to create tenant, DB, and container.
3. Generate SSL certificates automatically.
4. Seed new tenants from a template database.
5. Email tenant admin credentials and onboarding steps.

## Phase 3 — Operational Controls

1. Subscription lifecycle: trial, active, past-due, suspended, cancelled.
2. Backups and restore workflow.
3. Usage tracking and basic cost reporting.
4. Health checks and alerting.
5. Tenant deletion and data retention policy.

## Phase 4 — Optional OCA Addons

- `web_debrand` for white-label cleanup.
- `web_responsive` for a better mobile backend.
- `account_financial_report` if advanced reporting is required.

## MVP Deliverables

- veraERP fork repo
- branded login and backend
- tenant provisioning API
- Stripe billing flow
- one-tenant-per-container deployment
- onboarding email flow

## First 10 Engineering Tasks

1. Set up repo structure for addons and deployment.
2. Add branding addon skeleton.
3. Add tenant metadata model.
4. Add webhook endpoint for Stripe.
5. Add container provisioning script.
6. Add reverse-proxy routing template.
7. Add SSL automation.
8. Add template DB restore path.
9. Add onboarding email template.
10. Add tenant lifecycle admin page.
