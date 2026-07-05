#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

ensure_primary

log "Creating large table for optimization demo"
psql_primary -f /docker-entrypoint-initdb.d/02-index-demo.sql

log "EXPLAIN ANALYZE before index"
psql_primary -c "DROP INDEX IF EXISTS idx_large_order_search_tenant_status_created;"
psql_primary -c "EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM public.large_order_search WHERE tenant_id = 7 AND status = 'paid' ORDER BY created_at DESC LIMIT 20;"

log "Creating index"
psql_primary -c "CREATE INDEX IF NOT EXISTS idx_large_order_search_tenant_status_created ON public.large_order_search (tenant_id, status, created_at DESC);"
psql_primary -c "ANALYZE public.large_order_search;"

log "EXPLAIN ANALYZE after index"
psql_primary -c "EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM public.large_order_search WHERE tenant_id = 7 AND status = 'paid' ORDER BY created_at DESC LIMIT 20;"

log "Demo tuning parameters"
psql_primary -d postgres -c "SHOW shared_buffers; SHOW work_mem; SHOW maintenance_work_mem; SHOW effective_cache_size; SHOW max_connections; SHOW log_min_duration_statement;"
