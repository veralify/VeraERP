# veraERP Repo Structure

This is the recommended structure for a veraERP fork of Odoo Community.

```text
veraerp/
  addons/
    veraerp_branding/
    veraerp_tenant/
    veraerp_billing/
    veraerp_provisioning/
  deploy/
    docker/
    nginx/
    postgres/
    terraform/
  scripts/
    provision-tenant.sh
    backup-tenant.sh
    restore-tenant.sh
  config/
    odoo.conf
    env.example
  docs/
    architecture/
    operations/
    roadmap.md
  tests/
    provisioning/
    tenant-isolation/
```

## Addon responsibilities

| Folder | Responsibility |
| --- | --- |
| `veraerp_branding` | Login branding, backend white-labeling, email templates, favicon, footer/header tweaks |
| `veraerp_tenant` | Tenant records, domains, subscription state, tenant isolation rules |
| `veraerp_billing` | Plan definitions, Stripe hooks, invoices, renewals, suspensions |
| `veraerp_provisioning` | Tenant creation, template DB cloning, container startup, teardown |

## Deployment responsibilities

| Folder | Responsibility |
| --- | --- |
| `deploy/docker` | Base image and compose files |
| `deploy/nginx` | Subdomain routing and TLS termination |
| `deploy/postgres` | DB init, backups, and restore helpers |
| `deploy/terraform` | Infra provisioning if you use cloud resources |

## Suggested runtime split

- **Odoo app runtime:** isolated container per tenant
- **Database:** isolated PostgreSQL database per tenant
- **Proxy:** Nginx or Cloudflare in front
- **Provisioner:** a small internal service or worker queue

