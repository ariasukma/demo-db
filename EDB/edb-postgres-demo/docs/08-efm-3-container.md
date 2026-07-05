# EFM 3 Container

## Purpose
Demo konsep EFM menggunakan OSS EFM simulation. Ini bukan EDB EFM asli.

## Requirement
- EFM asli butuh EDB EFM package/image/license.
- Demo OSS simulation memakai 3 container: `efm-node1`, `efm-node2`, `efm-node3`.
- `efm-node1` primary simulation.
- `efm-node2` dibuat sebagai physical standby dari `efm-node1`.
- `efm-node3` hanya witness/monitor simulation.
- User `replicator`, `pg_hba.conf`, slot `efm_node2`, dan parameter WAL harus siap.
- Production EFM asli butuh agent EFM, cluster properties, fencing/VIP, notification, dan failure manager.

## Topology
```text
efm-node1 primary --WAL--> efm-node2 standby
             \              /
              efm-node3 witness simulation
```

## Scenario
1. Start 3 container simulation.
2. Ensure role, `pg_hba.conf`, reload, dan slot.
3. Rebuild `efm-node2` dari `efm-node1`.
4. Tampilkan primary/standby status.
5. Stop `efm-node1`.
6. Promote `efm-node2`.
7. Validasi write/read setelah promote.
8. Tampilkan catatan HAProxy static endpoint.

## Commands
```bash
cd /opt/source/database/EDB/edb-postgres-demo
./scripts/10-efm-demo.sh
```

## Validation
```bash
docker compose --env-file .env exec efm-node2 psql -U postgres -d postgres -c "SELECT pg_is_in_recovery();"
docker compose --env-file .env exec efm-node2 psql -U postgres -d demo -c "SELECT email FROM public.customers WHERE email = 'efm-promoted@example.test';"
```

## Expected Output
```text
node1_in_recovery | f
node2_in_recovery | t
node2_promoted    | f
efm-promoted@example.test
```

## Troubleshooting
- `no pg_hba.conf entry`: script menambahkan rule pada `efm-node1`.
- `pg_basebackup` gagal: pastikan `efm-node1` healthy dan slot `efm_node2` ada.
- HAProxy tidak otomatis pindah ke promoted node: demo belum membuat dynamic reconfiguration; real EFM/VIP diperlukan.

## Production Notes
Gunakan EDB EFM asli untuk automatic failure detection, fencing, VIP, notification, promotion policy, dan controlled rejoin.
