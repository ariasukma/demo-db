#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

log "Starting OSS PGD fallback simulation nodes"
compose up -d pgd-node1 pgd-node2 pgd-node3
wait_for_pg pgd-node1
wait_for_pg pgd-node2
wait_for_pg pgd-node3

for node in pgd-node1 pgd-node2 pgd-node3; do
  log "Preparing ${node}"
  psql_service "${node}" -c "CREATE TABLE IF NOT EXISTS public.pgd_demo(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), origin_node text NOT NULL, note text NOT NULL, updated_at timestamptz NOT NULL DEFAULT now());"
  psql_service "${node}" -c "DELETE FROM public.pgd_demo WHERE note LIKE 'insert from node%' AND id NOT IN ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003');"
  psql_service "${node}" -d postgres -c "ALTER SYSTEM SET wal_level = 'logical';"
  psql_service "${node}" -d postgres -c "ALTER SYSTEM SET max_replication_slots = '20';"
  psql_service "${node}" -d postgres -c "ALTER SYSTEM SET max_wal_senders = '20';"
done

log "Creating publications"
for node in pgd-node1 pgd-node2 pgd-node3; do
  psql_service "${node}" -c "DROP PUBLICATION IF EXISTS pub_${node//-/_}; CREATE PUBLICATION pub_${node//-/_} FOR TABLE public.pgd_demo;"
done

log "OSS fallback inserts on multiple nodes"
psql_service pgd-node1 -c "INSERT INTO public.pgd_demo(id, origin_node, note) VALUES ('00000000-0000-0000-0000-000000000001', 'pgd-node1', 'insert from node1') ON CONFLICT (id) DO UPDATE SET origin_node = EXCLUDED.origin_node, note = EXCLUDED.note, updated_at = now();"
psql_service pgd-node2 -c "INSERT INTO public.pgd_demo(id, origin_node, note) VALUES ('00000000-0000-0000-0000-000000000002', 'pgd-node2', 'insert from node2') ON CONFLICT (id) DO UPDATE SET origin_node = EXCLUDED.origin_node, note = EXCLUDED.note, updated_at = now();"
psql_service pgd-node3 -c "INSERT INTO public.pgd_demo(id, origin_node, note) VALUES ('00000000-0000-0000-0000-000000000003', 'pgd-node3', 'insert from node3') ON CONFLICT (id) DO UPDATE SET origin_node = EXCLUDED.origin_node, note = EXCLUDED.note, updated_at = now();"

log "Validation on each node"
for node in pgd-node1 pgd-node2 pgd-node3; do
  echo "--- ${node}"
  psql_service "${node}" -c "SELECT origin_node, note, count(*) FROM public.pgd_demo GROUP BY 1,2 ORDER BY 1;"
done

cat <<'NOTE'

This is an OSS fallback simulation, not real EDB Postgres Distributed.
Real PGD requires EDB images/packages and commands such as group creation,
node join, replicated table definition, conflict management, and node down/up
testing. Use docker-compose.pgd-edb.yml as the licensed template.
NOTE
