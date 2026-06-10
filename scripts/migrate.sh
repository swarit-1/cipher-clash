#!/usr/bin/env bash
# Apply pending SQL migrations to the dockerized Postgres.
# Tracks applied versions in a schema_migrations table; idempotent.
#
# Usage: scripts/migrate.sh [up|down <version>]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATIONS_DIR="$ROOT_DIR/infra/postgres/migrations"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

PGUSER="${POSTGRES_USER:-postgres}"
PGDB="${POSTGRES_DB:-cipher_clash}"

psql_exec() {
  docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres \
    psql -v ON_ERROR_STOP=1 -U "$PGUSER" -d "$PGDB" "$@"
}

if ! docker compose -f "$ROOT_DIR/docker-compose.yml" ps postgres 2>/dev/null | grep -q "running\|Up"; then
  echo "error: postgres container is not running (docker compose up -d postgres)" >&2
  exit 1
fi

psql_exec -q -c "CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ DEFAULT NOW());"

cmd="${1:-up}"

case "$cmd" in
  up)
    applied=0
    for file in "$MIGRATIONS_DIR"/*.up.sql; do
      version="$(basename "$file" .up.sql)"
      exists=$(psql_exec -tA -c "SELECT 1 FROM schema_migrations WHERE version = '$version'")
      if [[ "$exists" == "1" ]]; then
        echo "  = $version (already applied)"
        continue
      fi
      echo "  > applying $version"
      { echo "BEGIN;"; cat "$file"; echo "INSERT INTO schema_migrations (version) VALUES ('$version');"; echo "COMMIT;"; } | psql_exec -q
      applied=$((applied + 1))
    done
    echo "migrations complete ($applied applied)"
    ;;
  down)
    version="${2:?usage: migrate.sh down <version>}"
    file="$MIGRATIONS_DIR/$version.down.sql"
    [[ -f "$file" ]] || { echo "error: $file not found" >&2; exit 1; }
    echo "  < reverting $version"
    { echo "BEGIN;"; cat "$file"; echo "DELETE FROM schema_migrations WHERE version = '$version';"; echo "COMMIT;"; } | psql_exec -q
    ;;
  *)
    echo "usage: migrate.sh [up|down <version>]" >&2
    exit 1
    ;;
esac
