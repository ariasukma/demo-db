# Restore dari Barman

## Purpose
Demo restore backup terakhir dari Barman ke container target `pg-restore`, lalu validasi database dan data.

## Requirement
- Container: `pg-primary`, `barman`, `pg-restore`.
- Backup Barman harus tersedia.
- Volume `pg_restore_data` dapat di-reset oleh script restore.
- Barman volume berisi backup atau fallback basebackup.
- Tool: `barman`, `psql`, `pg_isready`.

## Topology
```text
pg-primary -> barman_data -> pg-restore
```

## Scenario
1. Pastikan primary dan Barman running.
2. Ambil row count sumber.
3. Pastikan full backup tersedia.
4. Reset volume restore target.
5. Restore backup terbaru.
6. Start `pg-restore`.
7. Validasi koneksi, tabel, row count, dan sample query.

## Commands
```bash
cd /opt/source/database/EDB/edb-postgres-demo
./scripts/04-restore-latest.sh
```

## Validation
```bash
docker compose --env-file .env exec pg-restore psql -U postgres -d demo -c "SELECT count(*) FROM public.orders;"
docker compose --env-file .env exec pg-restore psql -U postgres -d demo -c "SELECT email FROM public.customers ORDER BY id LIMIT 3;"
```

## Expected Output
```text
Restored orders: <number>
customer0001@example.test
```

## Troubleshooting
- Tidak ada backup: jalankan `./scripts/01-backup-full.sh`.
- Restore target gagal start: jalankan `docker compose --env-file .env logs pg-restore`.
- Permission data directory: script menjalankan copy sebagai root dan `chown postgres:postgres`.

## Production Notes
Production restore perlu PITR timestamp, checksum, isolated restore environment, documented cutover, dan verifikasi aplikasi.
