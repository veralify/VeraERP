# veraERP Scaffold

Starter layout for the Odoo Community fork that will become veraERP.

## What this contains

- isolated custom addon structure in `custom_addons/` (no core edits)
- baseline Docker + PostgreSQL tenant templates
- Nginx tenant routing template
- tenant lifecycle scripts (provision, backup, restore)

## Quick start

1. Copy `config/env.example` to `config/.env` and set values.
2. Provision a tenant stack:
   - `./scripts/provision-tenant.sh acme acme.veralify.com`
3. Start that tenant:
   - `docker compose -f runtime/tenants/acme/docker-compose.yml up -d`
4. Visit:
   - `http://localhost:8069` (or your routed domain in production)

## Notes

- The generated files in `runtime/tenants/` are local deployment artifacts.
- Keep Odoo customizations in `custom_addons/` to avoid core fork drift.
- Add community UX modules like `web_responsive` per tenant when needed.
