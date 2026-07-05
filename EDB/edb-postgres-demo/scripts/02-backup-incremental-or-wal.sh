#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

ensure_primary

log "Creating WAL activity"
psql_primary -c "INSERT INTO public.orders(customer_id, status, total_amount) SELECT id, 'paid', 42.42 FROM public.customers ORDER BY id LIMIT 5;"
psql_primary -d postgres -c "SELECT pg_switch_wal();"

if has_barman; then
  log "Barman check and receive-wal status"
  barman_cmd "barman check pg-primary || true"
  barman_cmd "barman receive-wal --create-slot pg-primary || true"
  barman_cmd "barman list-backup pg-primary || true"
else
  log "Native incremental backup is not generally the default Barman model here"
  echo "Barman commonly demonstrates full backups plus continuous WAL archiving/PITR. This script generated WAL and switched WAL for incremental recovery stream demonstration."
fi

log "Current WAL"
psql_primary -d postgres -c "SELECT pg_current_wal_lsn();"
