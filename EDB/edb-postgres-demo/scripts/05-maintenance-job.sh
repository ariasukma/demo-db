#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

ensure_primary

log "Manual VACUUM ANALYZE"
psql_primary -c "VACUUM (ANALYZE, VERBOSE) public.orders;"

log "Scheduled backup example"
"${SCRIPT_DIR}/01-backup-full.sh"

log "Log rotation simulation"
compose exec -T pg-primary bash -lc "mkdir -p /tmp/demo-log-rotation && echo rotated-at-\$(date -Iseconds) >> /tmp/demo-log-rotation/postgresql-demo.log && tail -5 /tmp/demo-log-rotation/postgresql-demo.log"

log "Cleanup old demo logs/backups simulation"
barman_cmd "find /var/lib/barman -type f -name '*.tmp' -mtime +1 -delete || true"

log "Optional scheduler profile command"
echo "docker compose --env-file .env --profile scheduler up -d maintenance"
echo "Example cron: 0 1 * * * /path/to/edb-postgres-demo/scripts/01-backup-full.sh"
