# veraERP Implementation Scaffold

## Build order

1. Fork Odoo Community into a private veraERP repo.
2. Copy the `veraerp/` scaffold into that repo.
3. Implement `veraerp_branding`.
4. Implement `veraerp_tenant`.
5. Implement `veraerp_billing`.
6. Implement `veraerp_provisioning`.
7. Wire Docker, Nginx, and PostgreSQL.
8. Add Stripe checkout and webhook handling.
9. Add template DB cloning and tenant onboarding.
10. Add lifecycle ops: suspend, renew, backup, restore, delete.

## Minimum viable tenant model

- one tenant = one Odoo container
- one tenant = one PostgreSQL database
- one tenant = one subdomain
- one tenant = one billing subscription

## Immediate engineering deliverables

- addon manifests
- environment config
- deployment scripts
- tenant onboarding flow
- admin dashboard for lifecycle control

## Scaffold status (started)

- Added tenant Docker compose template: `veraerp/deploy/docker/docker-compose.tenant.yml.tpl`
- Added Odoo image Dockerfile: `veraerp/deploy/docker/Dockerfile`
- Added Nginx tenant template: `veraerp/deploy/nginx/tenant.conf.tpl`
- Added Odoo config template: `veraerp/config/odoo.conf.template`
- Added isolated custom addons under `veraerp/custom_addons/`:
  - `vera_theme`
  - `vera_stripe_sync`
- Added tenant scripts:
  - `veraerp/scripts/provision-tenant.sh`
  - `veraerp/scripts/backup-tenant.sh`
  - `veraerp/scripts/restore-tenant.sh`

## Run the first tenant locally

1. `cp veraerp/config/env.example veraerp/config/.env`
2. `./veraerp/scripts/provision-tenant.sh acme acme.veralify.com 8069`
3. `docker compose -f veraerp/runtime/tenants/acme/docker-compose.yml up -d`
4. `docker compose -f veraerp/runtime/tenants/acme/docker-compose.yml run --rm --no-deps odoo odoo --config=/etc/odoo/odoo.conf -d acme -i base,vera_theme --without-demo all --stop-after-init`
