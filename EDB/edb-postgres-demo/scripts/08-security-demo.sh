#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

ensure_primary

log "Generating self-signed TLS certificate inside pg-primary"
compose exec -T --user root pg-primary bash -lc "openssl req -new -x509 -days 365 -nodes -text -subj '/CN=pg-primary' -out /var/lib/postgresql/data/server.crt -keyout /var/lib/postgresql/data/server.key >/dev/null 2>&1 && chown postgres:postgres /var/lib/postgresql/data/server.crt /var/lib/postgresql/data/server.key && chmod 600 /var/lib/postgresql/data/server.key"

log "Enabling SSL and hostssl demo rule"
compose exec -T pg-primary bash -lc "grep -q '^ssl = on' /var/lib/postgresql/data/postgresql.conf || echo 'ssl = on' >> /var/lib/postgresql/data/postgresql.conf"
compose exec -T pg-primary bash -lc "grep -q 'hostssl all all all scram-sha-256' /var/lib/postgresql/data/pg_hba.conf || echo 'hostssl all all all scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf"
compose restart pg-primary
wait_for_pg pg-primary
ensure_postgres_replication_access pg-primary
start_barman_receive_wal

log "Applying RBAC and audit demo"
psql_primary -f /docker-entrypoint-initdb.d/03-security-rbac.sql
psql_primary -f /docker-entrypoint-initdb.d/04-audit-demo.sql
compose exec -T pg-primary psql -U "${POSTGRES_USER}" -d postgres -c "SELECT pg_reload_conf();"

log "readonly_user can SELECT"
compose exec -T -e PGPASSWORD="${APP_READONLY_PASSWORD:-readonly_demo_password}" pg-primary psql "sslmode=require host=localhost user=readonly_user dbname=${DEMO_DB}" -c "SELECT count(*) FROM public.orders;"

log "readonly_user INSERT should fail"
compose exec -T -e PGPASSWORD="${APP_READONLY_PASSWORD:-readonly_demo_password}" pg-primary bash -lc "psql 'sslmode=require host=localhost user=readonly_user dbname=${DEMO_DB}' -c \"INSERT INTO public.orders(customer_id,status,total_amount) VALUES (1,'new',1);\" && exit 1 || exit 0"

log "writer_user can INSERT but cannot DROP"
compose exec -T -e PGPASSWORD="${APP_WRITER_PASSWORD:-writer_demo_password}" pg-primary psql "sslmode=require host=localhost user=writer_user dbname=${DEMO_DB}" -c "INSERT INTO public.orders(customer_id,status,total_amount) VALUES (1,'new',9.99);"
compose exec -T -e PGPASSWORD="${APP_WRITER_PASSWORD:-writer_demo_password}" pg-primary bash -lc "psql 'sslmode=require host=localhost user=writer_user dbname=${DEMO_DB}' -c 'DROP TABLE public.orders;' && exit 1 || exit 0"

log "admin_user can manage schema"
compose exec -T -e PGPASSWORD="${APP_ADMIN_PASSWORD:-admin_demo_password}" pg-primary psql "sslmode=require host=localhost user=admin_user dbname=${DEMO_DB}" -c "CREATE TABLE IF NOT EXISTS public.admin_created_table(id int PRIMARY KEY); DROP TABLE public.admin_created_table;"

log "Audit fallback validation"
psql_primary -c "SELECT action, table_name, count(*) FROM audit.demo_audit_log GROUP BY 1,2 ORDER BY 3 DESC;"
