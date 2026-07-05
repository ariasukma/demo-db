# Optimization

## Purpose
Demo perbandingan query lambat sebelum dan sesudah index, plus contoh parameter tuning PostgreSQL.

## Requirement
- Container: `pg-primary`.
- Database `demo`.
- Table `large_order_search` dibuat oleh `sql/02-index-demo.sql`.
- Parameter demo: `shared_buffers`, `work_mem`, `maintenance_work_mem`, `effective_cache_size`, `max_connections`, `log_min_duration_statement`.

## Topology
```text
client/script -> pg-primary -> demo.large_order_search
```

## Scenario
1. Load data besar.
2. Drop index demo jika ada.
3. Jalankan `EXPLAIN (ANALYZE, BUFFERS)` sebelum index.
4. Buat index `(tenant_id, status, created_at DESC)`.
5. Jalankan explain setelah index.
6. Tampilkan parameter tuning demo.

## Commands
```bash
cd /opt/source/database/EDB/edb-postgres-demo
./scripts/06-optimization-demo.sh
```

## Validation
```bash
docker compose --env-file .env exec pg-primary psql -U postgres -d demo -c "\di public.idx_large_order_search_tenant_status_created"
docker compose --env-file .env exec pg-primary psql -U postgres -d demo -c "EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM public.large_order_search WHERE tenant_id = 7 AND status = 'paid' ORDER BY created_at DESC LIMIT 20;"
```

## Expected Output
```text
Index Scan using idx_large_order_search_tenant_status_created
shared_buffers | 256MB
```

## Troubleshooting
- Data terlalu lama dibuat: kurangi `generate_series` di `sql/02-index-demo.sql`.
- Planner masih sequential scan: jalankan `ANALYZE` dan ulang query.
- Nilai tuning bukan production sizing; lihat catatan production.

## Production Notes
Sizing harus berbasis RAM, concurrency, query pattern, IO, autovacuum behavior, dan benchmark. Jangan copy nilai demo langsung ke production.
