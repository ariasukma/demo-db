#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

ensure_primary

log "Capturing source counts before damage simulation"
psql_primary -At -c "SELECT count(*) FROM public.orders;" > /tmp/edb-demo-source-orders.count
SOURCE_COUNT="$(cat /tmp/edb-demo-source-orders.count)"
echo "Source orders before damage: ${SOURCE_COUNT}"

log "Simulating logical damage on primary"
psql_primary -c "CREATE TABLE IF NOT EXISTS public.restore_damage_marker(id int); TRUNCATE public.restore_damage_marker;"

log "Ensuring a backup exists"
"${SCRIPT_DIR}/01-backup-full.sh"

log "Recreating restore target volume"
compose stop pg-restore >/dev/null 2>&1 || true
compose rm -f pg-restore >/dev/null 2>&1 || true
docker volume rm "${COMPOSE_PROJECT_NAME:-edb_postgres_demo}_pg_restore_data" >/dev/null 2>&1 || true

if has_barman; then
  log "Restoring latest Barman backup into pg-restore"
  compose run --rm --user root pg-restore bash -lc "rm -rf /var/lib/postgresql/data/*"
  barman_cmd "rm -rf /var/lib/barman/recover-latest && latest=\$(barman list-backup pg-primary | awk 'NR==1 {print \$2}'); barman recover pg-primary \"\$latest\" /var/lib/barman/recover-latest"
  compose run --rm --user root -v "${COMPOSE_PROJECT_NAME:-edb_postgres_demo}_barman_data:/barman:ro" pg-restore bash -lc "cp -a /barman/recover-latest/. /var/lib/postgresql/data/ && chown -R postgres:postgres /var/lib/postgresql/data"
else
  log "Restoring latest fallback pg_basebackup directory"
  compose run --rm --user root pg-restore bash -lc "rm -rf /var/lib/postgresql/data/*"
  compose run --rm --user root -v "${COMPOSE_PROJECT_NAME:-edb_postgres_demo}_barman_data:/barman:ro" pg-restore bash -lc "latest=\$(find /barman/pg-primary/base -maxdepth 1 -mindepth 1 -type d | sort | tail -1); cp -a \"\$latest\"/. /var/lib/postgresql/data/ && chown -R postgres:postgres /var/lib/postgresql/data"
fi

compose up -d pg-restore
wait_for_pg pg-restore

log "Restore validation"
RESTORED_COUNT="$(psql_service pg-restore -At -c "SELECT count(*) FROM public.orders;")"
echo "Restored orders: ${RESTORED_COUNT}"
psql_service pg-restore -c "SELECT id, email, full_name FROM public.customers ORDER BY id LIMIT 3;"
