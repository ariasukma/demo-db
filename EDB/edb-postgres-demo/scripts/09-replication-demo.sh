#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

ensure_primary

log "Preparing physical standby from pg-primary"
ensure_postgres_replication_access pg-primary
ensure_replication_slot pg-primary standby_slot
compose stop pg-standby >/dev/null 2>&1 || true
compose rm -f pg-standby >/dev/null 2>&1 || true
docker volume rm "${COMPOSE_PROJECT_NAME:-edb_postgres_demo}_pg_standby_data" >/dev/null 2>&1 || true
compose run --rm --user root pg-standby bash -lc "rm -rf /var/lib/postgresql/data/* && chown -R postgres:postgres /var/lib/postgresql/data"
compose run --rm -e PGPASSWORD="${REPLICATION_PASSWORD:-replicator_demo_password}" pg-standby bash -lc "pg_basebackup -h pg-primary -U ${REPLICATION_USER:-replicator} -D /var/lib/postgresql/data -Fp -Xs -P -R -S standby_slot"
compose up -d pg-standby
wait_for_pg pg-standby
wait_for_query_result pg-standby "SELECT pg_is_in_recovery();" t 30

log "Replication status on primary"
psql_primary -d postgres -c "SELECT application_name, state, sync_state, sent_lsn, replay_lsn FROM pg_stat_replication;"

log "Standby recovery and WAL receiver status"
psql_service pg-standby -d postgres -c "SELECT pg_is_in_recovery() AS standby_in_recovery;"
psql_service pg-standby -d postgres -c "SELECT status, sender_host, latest_end_lsn FROM pg_stat_wal_receiver;"

log "Insert on primary and validate on standby"
psql_primary -c "INSERT INTO public.customers(email, full_name) VALUES ('replication-demo@example.test', 'Replication Demo') ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name;"
wait_for_query_result pg-standby "SELECT count(*) FROM public.customers WHERE email = 'replication-demo@example.test';" 1 30
psql_service pg-standby -c "SELECT id, email, full_name FROM public.customers WHERE email = 'replication-demo@example.test';"

log "Optional manual failover command"
echo "docker compose --env-file .env exec pg-standby pg_ctl promote -D /var/lib/postgresql/data"
