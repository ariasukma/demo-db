# Replication 2 Container

## Purpose
Demo physical streaming replication dari `pg-primary` ke `pg-standby`.

## Requirement
- Container: `pg-primary`, `pg-standby`.
- User `replicator` dengan `LOGIN REPLICATION`.
- `pg_hba.conf` mengizinkan replication connection dari standby.
- `wal_level`, `max_wal_senders`, `max_replication_slots` aktif.
- Standby data directory kosong sebelum `pg_basebackup`.
- Slot `standby_slot` tersedia.
- Standby memakai `primary_conninfo` dan `primary_slot_name` dari `pg_basebackup -R -S standby_slot`.

## Topology
```text
pg-primary --WAL streaming--> pg-standby
```

## Scenario
1. Ensure primary running.
2. Ensure role dan `pg_hba.conf`.
3. Reload config.
4. Buat slot `standby_slot`.
5. Reset standby volume.
6. Jalankan `pg_basebackup`.
7. Start standby.
8. Validasi replication status dan data.

## Commands
```bash
cd /opt/source/database/EDB/edb-postgres-demo
./scripts/09-replication-demo.sh
```

## Validation
```bash
docker compose --env-file .env exec pg-primary psql -U postgres -d postgres -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
docker compose --env-file .env exec pg-standby psql -U postgres -d postgres -c "SELECT pg_is_in_recovery();"
docker compose --env-file .env exec pg-standby psql -U postgres -d demo -c "SELECT email FROM public.customers WHERE email = 'replication-demo@example.test';"
```

## Expected Output
```text
state | streaming
pg_is_in_recovery | t
replication-demo@example.test
```

## Troubleshooting
- `no pg_hba.conf entry`: script menambahkan rule; jalankan ulang.
- Slot sudah ada: script idempotent dan tidak membuat ulang.
- Standby tidak siap: script menunggu retry; cek `docker compose logs pg-standby`.

## Production Notes
Production perlu replication monitoring, slot cleanup, failover tooling, fencing, backup integration, synchronous/asynchronous policy, dan rejoin procedure.
