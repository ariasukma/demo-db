# EDB PostgreSQL Docker Demo

Project ini menyediakan demo end-to-end PostgreSQL/EDB-compatible dengan mode OSS lokal dan template EDB untuk komponen berlisensi seperti EFM dan PGD.

## Prerequisites

- Docker Engine dan Docker Compose v2
- Bash, Make, dan OpenSSL di host/container
- Port lokal yang tersedia: 5432, 5433, 5434, 5441-5443, 5451-5453, 9090, 3000, 15432

## Quick Start

```bash
cd /opt/source/database/EDB/edb-postgres-demo
cp .env.example .env
make build-images
docker compose --env-file .env config
make up
make init
```

Atau:

```bash
make up
```

## Scenario Runner

Jalankan skenario satu per satu:

```bash
./scripts/01-backup-full.sh
./scripts/02-backup-incremental-or-wal.sh
./scripts/03-list-backup.sh
./scripts/04-restore-latest.sh
./scripts/05-maintenance-job.sh
./scripts/06-optimization-demo.sh
./scripts/07-monitoring-alert-demo.sh
./scripts/08-security-demo.sh
./scripts/09-replication-demo.sh
./scripts/10-efm-demo.sh
./scripts/11-pgd-demo.sh
```

Target Makefile:

```bash
make build
make build-images
make pull
make up
make ps
make logs
make init
make backup
make restore
make maintenance
make optimization
make monitoring
make security
make replication
make efm
make pgd
make down
make clean
make purge
make nuke
```

## Image Policy

Project ini tidak menjalankan image public langsung dari `docker-compose.yml`. Semua service memakai alias image lokal dengan prefix `edb-demo-*`:

- `edb-demo-postgres:16-bookworm`
- `edb-demo-haproxy:2.9`
- `edb-demo-prometheus:v2.54.1`
- `edb-demo-grafana:11.1.4`
- `edb-demo-postgres-exporter:v0.15.0`
- `edb-demo-barman:local`

Alias dibuat dengan:

```bash
make build-images
```

Cek image demo:

```bash
docker image ls | grep edb-demo
```

## Port Mapping

| Service | Host Port | User |
| --- | ---: | --- |
| pg-primary | 5432 | postgres |
| pg-standby | 5433 | postgres |
| pg-restore | 5434 | postgres |
| efm-node1 | 5441 | postgres |
| efm-node2 | 5442 | postgres |
| efm-node3 | 5443 | simulation |
| pgd-node1 | 5451 | postgres |
| pgd-node2 | 5452 | postgres |
| pgd-node3 | 5453 | postgres |
| Prometheus | 9090 | none |
| Grafana | 3000 | admin/admin |
| HAProxy VIP simulation | 15432 | postgres |

## Demo Credentials

Semua credential ada di `.env.example` dan hanya untuk demo:

- `postgres / postgres_demo_password`
- `readonly_user / readonly_demo_password`
- `writer_user / writer_demo_password`
- `admin_user / admin_demo_password`
- `replicator / replicator_demo_password`
- `barman / barman_demo_password`

Jangan gunakan password ini di production.

## Documentation

- [Backup dengan Barman](docs/01-backup-barman.md)
- [Restore dari Barman](docs/02-restore-barman.md)
- [Maintenance dan Automation](docs/03-maintenance-automation.md)
- [Optimization](docs/04-optimization.md)
- [Monitoring dan Alert](docs/05-monitoring-alert.md)
- [Security](docs/06-security.md)
- [Replication 2 Container](docs/07-replication-2-container.md)
- [EFM 3 Container](docs/08-efm-3-container.md)
- [PGD Active-Active](docs/09-pgd-active-active.md)

## Reset Environment

```bash
make clean
```

Perintah ini menjalankan `docker compose down -v --remove-orphans`, menghapus volume demo, dan membersihkan folder lokal `logs`, `tmp`, `reports` jika ada.

Untuk menghapus image alias demo saja:

```bash
make purge
```

`make purge` hanya menghapus image dengan nama `edb-demo-*` yang dipakai project ini. Image public asli seperti `postgres:16-bookworm`, `grafana/grafana`, `prom/prometheus`, `haproxy`, dan `prometheuscommunity/postgres-exporter` tidak dihapus kecuali Anda menghapusnya manual.

`make nuke` menambahkan `docker builder prune --filter "label=project=edb-postgres-demo" -f`, sehingga builder cache lain di host tidak tersentuh.

## Troubleshooting

- Jika pernah mendapat error `ghcr.io/enterprisedb/barman:latest denied` atau `registry: denied`, itu karena image tersebut tidak publik untuk environment ini. Project sekarang memakai image lokal `edb-demo-barman:local` yang dibangun dari `docker/barman/Dockerfile` berbasis `postgres:16-bookworm`.
- Build ulang semua alias image demo dengan `make build-images`.
- Jika Compose mencoba pull `edb-demo-*` dari registry, jalankan `make build-images` dulu agar alias lokal tersedia.
- Jika Barman melaporkan permission denied di `/var/lib/barman`, recreate container `barman`; startup command akan menjalankan `chown -R barman:barman /var/lib/barman /etc/barman.d`.
- Jika Barman atau replication melaporkan `no pg_hba.conf entry`, jalankan `./scripts/00-init-demo.sh`; script ini menambahkan rule `barman` dan `replicator` secara idempotent lalu reload config.
- Jika port bentrok, ubah nilai port di `.env`.
- Jika container sudah punya data lama, jalankan `make clean` lalu ulangi `./scripts/00-init-demo.sh`.
- Untuk EFM dan PGD asli, ganti placeholder image di `.env` dengan image resmi EDB dan login registry sesuai entitlement EDB.

## Demo vs Production

Demo ini memakai resource kecil, self-signed certificate, password demo, dan HA/PGD simulation untuk mode OSS. Production perlu sizing, secret management, backup retention, encryption at-rest, monitoring alert manager, network isolation, image resmi/support, dan prosedur failover yang sudah diuji.
