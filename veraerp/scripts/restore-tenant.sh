#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <tenant-slug> <backup-file.sql>" >&2
  exit 1
fi

TENANT_SLUG="$1"
BACKUP_FILE="$2"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TENANT_DIR="$ROOT_DIR/runtime/tenants/$TENANT_SLUG"
TENANT_ENV="$TENANT_DIR/.env"
COMPOSE_FILE="$TENANT_DIR/docker-compose.yml"

if [[ ! -f "$TENANT_ENV" || ! -f "$COMPOSE_FILE" ]]; then
  echo "Tenant not found: $TENANT_SLUG" >&2
  exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "Backup file not found: $BACKUP_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$TENANT_ENV"

docker compose -f "$COMPOSE_FILE" stop odoo >/dev/null

cat "$BACKUP_FILE" | docker compose -f "$COMPOSE_FILE" exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$TENANT_SLUG"

docker compose -f "$COMPOSE_FILE" up -d odoo >/dev/null

echo "Restore complete for tenant: $TENANT_SLUG"
