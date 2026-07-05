# Maintenance Job dan Automation

## Purpose
Demo maintenance manual dan scheduled: backup, `VACUUM ANALYZE`, simulasi log rotation, dan cleanup.

## Requirement
- Container: `pg-primary`, `barman`, optional `maintenance`.
- Role `postgres` untuk maintenance demo.
- Database `demo` dan sample table tersedia.
- Scheduler profile Compose tersedia melalui profile `scheduler`.
- Volume Barman dan PostgreSQL harus writable.

## Topology
```text
maintenance-scheduler -> pg-primary
                  \-> barman
```

## Scenario
1. Start primary dan Barman.
2. Jalankan `VACUUM (ANALYZE, VERBOSE)`.
3. Jalankan backup terjadwal secara manual.
4. Buat simulasi log rotation.
5. Cleanup file temporary lama.
6. Tampilkan contoh cron.

## Commands
```bash
cd /opt/source/database/EDB/edb-postgres-demo
./scripts/05-maintenance-job.sh
docker compose --env-file .env --profile scheduler up -d maintenance
```

## Validation
```bash
docker compose --env-file .env exec pg-primary psql -U postgres -d demo -c "SELECT relname, last_vacuum, last_analyze FROM pg_stat_user_tables WHERE relname = 'orders';"
docker exec -u barman barman barman list-backup pg-primary
```

## Expected Output
```text
VACUUM
Example cron: 0 1 * * * ...
```

## Troubleshooting
- Job overlap: demo tidak memakai distributed lock; jalankan satu instance.
- Backup gagal: cek docs backup Barman dan `docker compose logs barman`.
- Scheduler tidak start: pastikan memakai `--profile scheduler`.

## Production Notes
Gunakan scheduler terobservasi, lock, alerting, logrotate asli, retention policy, dan window maintenance yang sesuai workload.
