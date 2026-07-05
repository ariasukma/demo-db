#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ENV_FILE}"
  echo "[info] Created ${ENV_FILE} from .env.example"
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

COMPOSE="${COMPOSE:-docker compose}"
DEMO_DB="${DEMO_DB:-demo}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres_demo_password}"
REPLICATION_USER="${REPLICATION_USER:-replicator}"
REPLICATION_PASSWORD="${REPLICATION_PASSWORD:-replicator_demo_password}"
BARMAN_USER="${BARMAN_USER:-barman}"
BARMAN_PASSWORD="${BARMAN_PASSWORD:-barman_demo_password}"

cd "${ROOT_DIR}"

log() {
  printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

compose() {
  ${COMPOSE} --env-file "${ENV_FILE}" "$@"
}

psql_primary() {
  compose exec -T -e PGPASSWORD="${POSTGRES_PASSWORD}" pg-primary \
    psql -U "${POSTGRES_USER}" -d "${DEMO_DB}" "$@"
}

psql_service() {
  local service="$1"
  shift
  compose exec -T -e PGPASSWORD="${POSTGRES_PASSWORD}" "${service}" \
    psql -U "${POSTGRES_USER}" -d "${DEMO_DB}" "$@"
}

psql_postgres_service() {
  local service="$1"
  shift
  compose exec -T -e PGPASSWORD="${POSTGRES_PASSWORD}" "${service}" \
    psql -U "${POSTGRES_USER}" -d postgres "$@"
}

wait_for_pg() {
  local service="$1"
  local user="${2:-${POSTGRES_USER}}"
  log "Waiting for ${service}"
  for _ in $(seq 1 60); do
    if compose exec -T "${service}" pg_isready -U "${user}" >/dev/null 2>&1; then
      log "${service} is ready"
      return 0
    fi
    sleep 2
  done
  echo "[error] ${service} did not become ready" >&2
  return 1
}

ensure_primary() {
  compose up -d pg-primary barman
  wait_for_pg pg-primary
  ensure_postgres_replication_access pg-primary
  ensure_barman_container
  psql_primary -f /docker-entrypoint-initdb.d/01-sample-data.sql
}

barman_cmd() {
  compose exec -T -u barman barman bash -lc "$*"
}

barman_root_cmd() {
  compose exec -T -u root barman bash -lc "$*"
}

has_barman() {
  barman_cmd "command -v barman >/dev/null"
}

ensure_postgres_replication_access() {
  local service="$1"

  log "Ensuring replication roles on ${service}"
  psql_postgres_service "${service}" -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${BARMAN_USER}') THEN CREATE ROLE ${BARMAN_USER} WITH SUPERUSER REPLICATION LOGIN PASSWORD '${BARMAN_PASSWORD}'; ELSE ALTER ROLE ${BARMAN_USER} WITH SUPERUSER REPLICATION LOGIN PASSWORD '${BARMAN_PASSWORD}'; END IF; IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${REPLICATION_USER}') THEN CREATE ROLE ${REPLICATION_USER} WITH REPLICATION LOGIN PASSWORD '${REPLICATION_PASSWORD}'; ELSE ALTER ROLE ${REPLICATION_USER} WITH REPLICATION LOGIN PASSWORD '${REPLICATION_PASSWORD}'; END IF; END \$\$;"

  log "Ensuring pg_hba.conf replication rules on ${service}"
  compose exec -T "${service}" bash -lc "set -euo pipefail
PGDATA=\${PGDATA:-/var/lib/postgresql/data}
touch \"\$PGDATA/pg_hba.conf\"
grep -qxF 'host replication ${BARMAN_USER} 0.0.0.0/0 scram-sha-256' \"\$PGDATA/pg_hba.conf\" || echo 'host replication ${BARMAN_USER} 0.0.0.0/0 scram-sha-256' >> \"\$PGDATA/pg_hba.conf\"
grep -qxF 'host all ${BARMAN_USER} 0.0.0.0/0 scram-sha-256' \"\$PGDATA/pg_hba.conf\" || echo 'host all ${BARMAN_USER} 0.0.0.0/0 scram-sha-256' >> \"\$PGDATA/pg_hba.conf\"
grep -qxF 'host replication ${REPLICATION_USER} 0.0.0.0/0 scram-sha-256' \"\$PGDATA/pg_hba.conf\" || echo 'host replication ${REPLICATION_USER} 0.0.0.0/0 scram-sha-256' >> \"\$PGDATA/pg_hba.conf\"
grep -qxF 'host all ${REPLICATION_USER} 0.0.0.0/0 scram-sha-256' \"\$PGDATA/pg_hba.conf\" || echo 'host all ${REPLICATION_USER} 0.0.0.0/0 scram-sha-256' >> \"\$PGDATA/pg_hba.conf\"
"
  psql_postgres_service "${service}" -c "SELECT pg_reload_conf();"
}

ensure_replication_slot() {
  local service="$1"
  local slot="$2"
  psql_postgres_service "${service}" -c "SELECT pg_create_physical_replication_slot('${slot}') WHERE NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = '${slot}');"
}

ensure_barman_container() {
  compose up -d barman
  barman_root_cmd "mkdir -p /var/lib/barman/pg-primary /etc/barman.d && cp /demo-config/pg-primary.conf /etc/barman.d/pg-primary.conf && sed -i 's/password=barman_demo_password/password=${BARMAN_PASSWORD}/g' /etc/barman.d/pg-primary.conf && chown -R barman:barman /var/lib/barman /etc/barman.d && chmod -R u+rwX,g+rwX /var/lib/barman /etc/barman.d"
}

start_barman_receive_wal() {
  ensure_replication_slot pg-primary barman
  barman_cmd "if ! ps -eo stat,args | awk '\$1 !~ /Z/ && \$0 !~ /awk/ && /pg_receivewal|barman receive-wal pg-primary/ {found=1} END {exit !found}'; then nohup barman receive-wal pg-primary > /var/lib/barman/pg-primary/receive-wal.log 2>&1 < /dev/null & disown || true; fi"
  for _ in $(seq 1 10); do
    if barman_cmd "ps -eo stat,args | awk '\$1 !~ /Z/ && \$0 !~ /awk/ && /pg_receivewal|barman receive-wal pg-primary/ {found=1} END {exit !found}'"; then
      return 0
    fi
    sleep 1
  done
  barman_cmd "tail -50 /var/lib/barman/pg-primary/receive-wal.log 2>/dev/null || true"
  echo "[error] barman receive-wal did not stay running" >&2
  return 1
}

wait_for_query_result() {
  local service="$1"
  local sql="$2"
  local expected="$3"
  local attempts="${4:-30}"

  for _ in $(seq 1 "${attempts}"); do
    local result
    result="$(psql_service "${service}" -At -c "${sql}" 2>/dev/null || true)"
    if [[ "${result}" == "${expected}" ]]; then
      return 0
    fi
    sleep 2
  done
  echo "[error] Expected '${expected}' from ${service}, got '${result:-<empty>}'" >&2
  return 1
}
