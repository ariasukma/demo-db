# Security

## Purpose
Demo TLS in-transit, `hostssl`, RBAC, user privilege validation, dan audit fallback.

## Requirement
- Container: `pg-primary`.
- Tool dalam container: `openssl`, `psql`.
- Role: `app_readonly`, `app_writer`, `app_admin`.
- User: `readonly_user`, `writer_user`, `admin_user`.
- TLS self-signed certificate untuk demo.
- Audit fallback memakai PostgreSQL logging dan trigger audit jika `pgaudit` tidak tersedia.

## Topology
```text
client sslmode=require -> pg-primary TLS -> demo schema
```

## Scenario
1. Generate self-signed certificate.
2. Enable `ssl = on`.
3. Tambah rule `hostssl`.
4. Apply RBAC.
5. Validasi readonly, writer, admin.
6. Enable audit fallback.

## Commands
```bash
cd /opt/source/database/EDB/edb-postgres-demo
./scripts/08-security-demo.sh
```

## Validation
```bash
docker compose --env-file .env exec pg-primary psql -U postgres -d postgres -c "SHOW ssl;"
docker compose --env-file .env exec pg-primary psql -U postgres -d demo -c "SELECT action, table_name, count(*) FROM audit.demo_audit_log GROUP BY 1,2;"
```

## Expected Output
```text
ssl | on
readonly_user INSERT should fail
writer_user can INSERT but cannot DROP
```

## Troubleshooting
- TLS gagal: restart `pg-primary` setelah certificate dibuat.
- Permission tidak sesuai: jalankan ulang script, RBAC SQL idempotent.
- `pgaudit` tidak tersedia: demo memakai fallback logging dan trigger audit.

## Production Notes
Gunakan CA resmi/internal, secret manager, SCRAM, least privilege, audit extension, encryption at-rest, network policy, rotation, dan pemisahan role operasional.
