#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

ensure_primary

log "Preparing Barman replication slot and permissions"
ensure_postgres_replication_access pg-primary
ensure_barman_container
start_barman_receive_wal

if has_barman; then
  log "barman check pg-primary"
  barman_cmd "barman check pg-primary || true"
  log "barman backup pg-primary"
  barman_cmd "barman backup pg-primary"
  log "barman list-backup pg-primary"
  barman_cmd "barman list-backup pg-primary"
  log "barman show-backup latest"
  barman_cmd "latest=\$(barman list-backup pg-primary | awk 'NR==1 {print \$2}'); test -n \"\$latest\" && barman show-backup pg-primary \"\$latest\""
else
  log "Barman binary not found in selected image; using pg_basebackup fallback into Barman volume"
  barman_cmd "mkdir -p /var/lib/barman/pg-primary/base && PGPASSWORD='${BARMAN_PASSWORD}' pg_basebackup -h pg-primary -U '${BARMAN_USER}' -D /var/lib/barman/pg-primary/base/manual-\$(date +%Y%m%d%H%M%S) -Fp -Xs -P"
  barman_cmd "find /var/lib/barman/pg-primary/base -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort"
fi

log "Backup validation source row counts"
psql_primary -c "SELECT count(*) AS customers FROM public.customers; SELECT count(*) AS orders FROM public.orders;"
