# Monitoring dan Alert

## Purpose
Demo monitoring PostgreSQL menggunakan `postgres_exporter`, Prometheus, Grafana, dan query health check.

## Requirement
- Container: `pg-primary`, `postgres-exporter`, `prometheus`, `grafana`.
- Port: Prometheus `9090`, Grafana `3000`, exporter `9187`.
- User `postgres` untuk exporter demo.
- Metrics PostgreSQL dari exporter; CPU/memory/disk host penuh memerlukan node exporter atau Docker metrics tambahan.

## Topology
```text
pg-primary -> postgres-exporter:9187 -> prometheus:9090 -> grafana:3000
```

## Scenario
1. Start monitoring stack.
2. Cek database health.
3. Tampilkan session/connection count.
4. Tampilkan lock dan long running query.
5. Simulasikan alert connection count, replication lag, disk threshold, database down.

## Commands
```bash
cd /opt/source/database/EDB/edb-postgres-demo
./scripts/07-monitoring-alert-demo.sh
```

## Validation
```bash
curl http://localhost:9090/-/ready
curl http://localhost:9187/metrics | grep '^pg_up'
docker compose --env-file .env exec pg-primary psql -U postgres -d postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

## Expected Output
```text
Prometheus: http://localhost:9090
Grafana:    http://localhost:3000 admin/admin
pg_up 1
```

## Troubleshooting
- Grafana kosong: tunggu provisioning beberapa detik dan refresh.
- `pg_up` nol: cek `DATA_SOURCE_NAME` dan health `pg-primary`.
- CPU/memory tidak ada: tambahkan node exporter/cAdvisor untuk production-like host metrics.

## Production Notes
Tambahkan Alertmanager, dashboards resmi, SLO, log aggregation, retention, node metrics, backup alerts, dan runbook incident.
