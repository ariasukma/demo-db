# Backup dengan Barman

## Purpose
Demo full physical backup PostgreSQL menggunakan Barman lokal `edb-demo-barman:local`, plus WAL streaming untuk PITR. Demo ini tidak memakai image `ghcr.io/enterprisedb/barman:latest`.

## Requirement
- Container: `pg-primary`, `barman`.
- Image Barman lokal dibangun dari `docker/barman/Dockerfile`.
- User database `barman` harus punya `LOGIN`, `REPLICATION`, dan pada demo diberi `SUPERUSER` agar backup privilege cukup.
- Production harus memakai least privilege, bukan superuser demo.
- `pg_hba.conf` harus mengizinkan `barman` untuk koneksi normal dan replication.
- `wal_level` minimal `replica`; demo memakai `logical`.
- `max_wal_senders` dan `max_replication_slots` cukup.
- Replication slot `barman` tersedia.
- `streaming_archiver=on`, `archiver=off`.
- Volume `barman_data` writable oleh user Linux `barman`.
- Backup demo adalah full physical backup + WAL streaming/PITR, bukan incremental file backup terpisah.

## Topology
```text
pg-primary:5432
  | normal connection + replication connection
  v
barman:/var/lib/barman
```

## Scenario
1. Build image Barman lokal.
2. Start `pg-primary` dan `barman`.
3. Bootstrap role, `pg_hba.conf`, reload config, dan slot.
4. Start `barman receive-wal`.
5. Jalankan `barman check`.
6. Jalankan full backup.
7. List dan show backup terbaru.

## Commands
```bash
cd /opt/source/database/EDB/edb-postgres-demo
cp -n .env.example .env
docker compose --env-file .env build barman
./scripts/00-init-demo.sh
./scripts/01-backup-full.sh
```

## Validation
```bash
docker exec -u barman barman barman check pg-primary
docker exec -u barman barman barman list-backup pg-primary
docker exec -u barman barman barman show-backup pg-primary latest
```

## Expected Output
```text
Server pg-primary:
  PostgreSQL: OK
  streaming: OK
  WAL archive: OK

pg-primary <backup_id> ... DONE
```

## Troubleshooting
- `registry denied`: project memakai image lokal `edb-demo-barman:local`; jalankan `docker compose --env-file .env build barman`.
- `Permission denied /var/lib/barman`: restart `barman`; startup command menjalankan `chown -R barman:barman`.
- `reuse_backup option is not supported`: config demo tidak memakai `reuse_backup`.
- `no pg_hba.conf entry`: jalankan `./scripts/00-init-demo.sh` atau `./scripts/01-backup-full.sh`.
- `receive-wal not running`: script backup menjalankan receiver; cek log `/var/lib/barman/pg-primary/receive-wal.log`.

## Production Notes
Gunakan credential rahasia, least privilege, retention policy formal, monitoring Barman, offsite copy, backup encryption, dan restore drill berkala.
