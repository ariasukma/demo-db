#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

pull_and_tag() {
  local source_image="$1"
  local demo_image="$2"

  echo "[build-images] pull ${source_image}"
  docker pull "${source_image}"
  echo "[build-images] tag ${source_image} -> ${demo_image}"
  docker tag "${source_image}" "${demo_image}"
}

pull_and_tag "postgres:16-bookworm" "edb-demo-postgres:16-bookworm"
pull_and_tag "haproxy:2.9" "edb-demo-haproxy:2.9"
pull_and_tag "prom/prometheus:v2.54.1" "edb-demo-prometheus:v2.54.1"
pull_and_tag "grafana/grafana:11.1.4" "edb-demo-grafana:11.1.4"
pull_and_tag "prometheuscommunity/postgres-exporter:v0.15.0" "edb-demo-postgres-exporter:v0.15.0"

echo "[build-images] local demo image aliases are ready"
