#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

log "Starting core OSS demo services"
compose up -d pg-primary barman postgres-exporter prometheus grafana haproxy
wait_for_pg pg-primary
ensure_postgres_replication_access pg-primary
ensure_barman_container

log "Loading sample data"
psql_primary -f /docker-entrypoint-initdb.d/01-sample-data.sql

log "Initializing Barman WAL receiver"
start_barman_receive_wal

log "Primary validation"
psql_primary -c "SELECT current_database() AS db, count(*) AS customers FROM public.customers;"

log "Demo is ready"
echo "PostgreSQL: localhost:${PG_PRIMARY_PORT:-5432}"
echo "Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
echo "Grafana:    http://localhost:${GRAFANA_PORT:-3000} (admin/admin)"
