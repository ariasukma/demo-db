#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

compose up -d barman

if has_barman; then
  log "barman list-backup pg-primary"
  barman_cmd "barman list-backup pg-primary || true"
else
  log "Fallback backup directories"
  barman_cmd "find /var/lib/barman/pg-primary -maxdepth 3 -type d -print | sort || true"
fi
