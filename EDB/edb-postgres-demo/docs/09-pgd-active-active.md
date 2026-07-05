# PGD Active-Active

## Purpose
Menjelaskan template EDB PGD asli dan menyediakan OSS fallback simulation. Script `11-pgd-demo.sh` bukan EDB PGD asli.

## Requirement
- PGD asli memerlukan EDB PGD image/package/license.
- Minimal PGD asli direkomendasikan 3 database node/container.
- Optional 1 client/admin container dan 1 proxy/load balancer.
- Setiap node PGD asli writable.
- Perlu group creation, node join, replication set/table definition, conflict management, dan node lifecycle tooling.
- Template: `docker-compose.pgd-edb.yml` dan `.env.pgd-edb.example`.
- OSS fallback memakai 3 PostgreSQL container biasa dan hanya menunjukkan multi-node writes lokal, bukan active-active replication PGD.

## Topology
```text
EDB PGD asli:
pgd-node1 <-> pgd-node2 <-> pgd-node3
      \          |          /
       optional admin/proxy

OSS fallback:
pgd-node1   pgd-node2   pgd-node3
local table local table local table
```

## Scenario
1. Untuk fallback, start `pgd-node1`, `pgd-node2`, `pgd-node3`.
2. Buat table demo pada tiap node.
3. Buat publication contoh pada tiap node.
4. Insert dari tiap node.
5. Validasi bahwa ini hanya simulasi, bukan replikasi PGD.
6. Untuk PGD asli, gunakan template EDB dan jalankan command resmi EDB untuk create group, join node, replicated table, conflict handling, dan node down/up.

## Commands
```bash
cd /opt/source/database/EDB/edb-postgres-demo
./scripts/11-pgd-demo.sh

cp .env.pgd-edb.example .env.pgd-edb
docker compose --env-file .env.pgd-edb -f docker-compose.pgd-edb.yml config
```

## Validation
```bash
docker compose --env-file .env exec pgd-node1 psql -U postgres -d demo -c "SELECT origin_node, count(*) FROM public.pgd_demo GROUP BY 1 ORDER BY 1;"
docker compose --env-file .env -f docker-compose.pgd-edb.yml config
```

## Expected Output
```text
This is an OSS fallback simulation, not real EDB Postgres Distributed.
pgd-node1 | 1
pgd-node2 | 1
pgd-node3 | 1
```

## Troubleshooting
- `gen_random_uuid` error: use PostgreSQL 16 image or replace with explicit UUID values.
- EDB image pull gagal: isi `.env.pgd-edb` dengan image dan token/kredensial resmi.
- Data tidak muncul antar node fallback: benar, fallback bukan PGD replication.

## Production Notes
PGD production perlu desain conflict handling, routing, latency budget, DDL strategy, backup/restore PGD-aware, monitoring, quorum, dan dokumentasi failover/failback.
