#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <tenant-slug> <tenant-domain> [host-port]" >&2
  exit 1
fi

TENANT_SLUG="$1"
TENANT_DOMAIN="$2"
HOST_PORT="${3:-8069}"

if ! [[ "$TENANT_SLUG" =~ ^[a-z0-9][a-z0-9-]{1,30}$ ]]; then
  echo "Invalid tenant slug: '$TENANT_SLUG'" >&2
  exit 1
fi

if ! [[ "$HOST_PORT" =~ ^[0-9]+$ ]]; then
  echo "Host port must be numeric: '$HOST_PORT'" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TENANT_DIR="$ROOT_DIR/runtime/tenants/$TENANT_SLUG"
TEMPLATE_COMPOSE="$ROOT_DIR/deploy/docker/docker-compose.tenant.yml.tpl"
TEMPLATE_NGINX="$ROOT_DIR/deploy/nginx/tenant.conf.tpl"
TEMPLATE_ODOO="$ROOT_DIR/config/odoo.conf.template"
BASE_ENV="$ROOT_DIR/config/.env"

if [[ ! -f "$BASE_ENV" ]]; then
  echo "Missing $BASE_ENV. Copy config/env.example to config/.env first." >&2
  exit 1
fi

mkdir -p "$TENANT_DIR/nginx" "$TENANT_DIR/postgres-data" "$TENANT_DIR/odoo-data"

POSTGRES_USER="${TENANT_SLUG}_user"
POSTGRES_PASSWORD="$(openssl rand -hex 20)"
ODOO_ADMIN_PASSWORD="$(openssl rand -hex 20)"

# shellcheck disable=SC1090
source "$BASE_ENV"
VERAERP_IMAGE="${VERAERP_IMAGE:-veralify/erp:latest}"
VERAERP_TIMEZONE="${VERAERP_TIMEZONE:-UTC}"

if [[ -f "$TENANT_DIR/docker-compose.yml" ]]; then
  echo "Tenant already exists at $TENANT_DIR" >&2
  exit 1
fi

sed \
  -e "s|__TENANT_SLUG__|$TENANT_SLUG|g" \
  -e "s|__POSTGRES_USER__|$POSTGRES_USER|g" \
  -e "s|__POSTGRES_PASSWORD__|$POSTGRES_PASSWORD|g" \
  -e "s|__VERAERP_IMAGE__|$VERAERP_IMAGE|g" \
  -e "s|__VERAERP_TIMEZONE__|$VERAERP_TIMEZONE|g" \
  -e "s|__HOST_PORT__|$HOST_PORT|g" \
  "$TEMPLATE_COMPOSE" > "$TENANT_DIR/docker-compose.yml"

sed \
  -e "s|__TENANT_DOMAIN__|$TENANT_DOMAIN|g" \
  -e "s|__HOST_PORT__|$HOST_PORT|g" \
  "$TEMPLATE_NGINX" > "$TENANT_DIR/nginx/$TENANT_DOMAIN.conf"

sed \
  -e "s|\${ODOO_ADMIN_PASSWORD}|$ODOO_ADMIN_PASSWORD|g" \
  -e "s|\${POSTGRES_USER}|$POSTGRES_USER|g" \
  -e "s|\${POSTGRES_PASSWORD}|$POSTGRES_PASSWORD|g" \
  -e "s|\${TENANT_SLUG}|$TENANT_SLUG|g" \
  "$TEMPLATE_ODOO" > "$TENANT_DIR/odoo.conf"

cat > "$TENANT_DIR/.env" <<EOF
TENANT_SLUG=$TENANT_SLUG
TENANT_DOMAIN=$TENANT_DOMAIN
HOST_PORT=$HOST_PORT
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
ODOO_ADMIN_PASSWORD=$ODOO_ADMIN_PASSWORD
EOF

echo "Tenant scaffold created: $TENANT_DIR"
echo "Next: docker compose -f $TENANT_DIR/docker-compose.yml up -d"
