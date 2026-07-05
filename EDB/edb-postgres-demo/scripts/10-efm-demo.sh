#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

log "Starting OSS EFM simulation containers"
compose up -d efm-node1 efm-node2 efm-node3 haproxy
wait_for_pg efm-node1

log "Preparing efm-node2 as physical standby of efm-node1"
ensure_postgres_replication_access efm-node1
ensure_replication_slot efm-node1 efm_node2
compose stop efm-node2 >/dev/null 2>&1 || true
compose rm -f efm-node2 >/dev/null 2>&1 || true
docker volume rm "${COMPOSE_PROJECT_NAME:-edb_postgres_demo}_efm_node2_data" >/dev/null 2>&1 || true
compose run --rm --user root efm-node2 bash -lc "rm -rf /var/lib/postgresql/data/* && chown -R postgres:postgres /var/lib/postgresql/data"
compose run --rm -e PGPASSWORD="${REPLICATION_PASSWORD:-replicator_demo_password}" efm-node2 bash -lc "pg_basebackup -h efm-node1 -U ${REPLICATION_USER:-replicator} -D /var/lib/postgresql/data -Fp -Xs -P -R -S efm_node2"
compose up -d efm-node2
wait_for_pg efm-node2
wait_for_query_result efm-node2 "SELECT pg_is_in_recovery();" t 30

log "Cluster status simulation"
compose exec -T -e PGPASSWORD="${POSTGRES_PASSWORD}" efm-node1 psql -U "${POSTGRES_USER}" -d postgres -c "SELECT pg_is_in_recovery() AS node1_in_recovery;"
compose exec -T -e PGPASSWORD="${POSTGRES_PASSWORD}" efm-node2 psql -U "${POSTGRES_USER}" -d postgres -c "SELECT pg_is_in_recovery() AS node2_in_recovery;"
compose exec -T efm-node3 bash -lc "echo witness-status=observing; getent hosts efm-node1 efm-node2"

log "Simulating primary down and standby promote"
compose stop efm-node1
sleep 3
compose exec -T -u postgres efm-node2 pg_ctl promote -D /var/lib/postgresql/data
wait_for_query_result efm-node2 "SELECT pg_is_in_recovery();" f 30
compose exec -T -e PGPASSWORD="${POSTGRES_PASSWORD}" efm-node2 psql -U "${POSTGRES_USER}" -d postgres -c "SELECT pg_is_in_recovery() AS node2_promoted;"

log "Validating write/read on promoted efm-node2"
psql_service efm-node2 -c "INSERT INTO public.customers(email, full_name) VALUES ('efm-promoted@example.test', 'EFM Promoted Node') ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name;"
psql_service efm-node2 -c "SELECT email, full_name FROM public.customers WHERE email = 'efm-promoted@example.test';"

log "VIP/HAProxy simulation check"
echo "HAProxy TCP endpoint: localhost:${HAPROXY_PORT:-15432}"
echo "HAProxy is static in OSS simulation; docs explain that dynamic VIP/agent routing requires real EDB EFM."
echo "Restart efm-node1 with: docker compose --env-file .env up -d efm-node1"
