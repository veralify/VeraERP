#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <tenant-slug>" >&2
  exit 1
fi

TENANT_SLUG="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TENANT_DIR="$ROOT_DIR/runtime/tenants/$TENANT_SLUG"
TENANT_ENV="$TENANT_DIR/.env"
COMPOSE_FILE="$TENANT_DIR/docker-compose.yml"

if [[ ! -f "$TENANT_ENV" || ! -f "$COMPOSE_FILE" ]]; then
  echo "Tenant not found: $TENANT_SLUG" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$TENANT_ENV"

BACKUP_DIR="$TENANT_DIR/backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/${TENANT_SLUG}_$(date +%Y%m%d_%H%M%S).sql"

docker compose -f "$COMPOSE_FILE" exec -T postgres \
  pg_dump --clean --if-exists --no-owner --no-privileges \
  -U "$POSTGRES_USER" "$TENANT_SLUG" > "$BACKUP_FILE"

echo "Backup written: $BACKUP_FILE"
