#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

ensure_primary
compose up -d postgres-exporter prometheus grafana

log "Database health"
psql_primary -c "SELECT now() AS checked_at, count(*) AS sessions FROM pg_stat_activity;"

log "Long running query and lock visibility sample"
psql_primary -c "SELECT pid, usename, state, now() - query_start AS age, left(query, 80) AS query FROM pg_stat_activity ORDER BY query_start NULLS LAST LIMIT 10;"
psql_primary -c "SELECT locktype, mode, granted, count(*) FROM pg_locks GROUP BY 1,2,3 ORDER BY 4 DESC;"

log "Alert simulation values"
psql_primary -c "SELECT count(*) AS connection_count, current_setting('max_connections') AS max_connections FROM pg_stat_activity;"
psql_primary -c "SELECT COALESCE(max(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)), 0) AS replication_lag_bytes FROM pg_stat_replication;"
compose exec -T pg-primary bash -lc "df -h /var/lib/postgresql/data"

log "Prometheus metric smoke test"
compose exec -T pg-primary bash -lc "exec 3<>/dev/tcp/postgres-exporter/9187; printf 'GET /metrics HTTP/1.0\r\nHost: postgres-exporter\r\n\r\n' >&3; sed -n '1,20p' <&3"

echo "Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
echo "Grafana:    http://localhost:${GRAFANA_PORT:-3000} admin/admin"
