#!/usr/bin/env bash
# Restart RHDH after app-config-only changes (no plugin re-export).
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

load_env
install_rhdh_configs
compose_args
cd "${RHDH_LOCAL}"
"${COMPOSE_ARR[@]}" stop rhdh
"${COMPOSE_ARR[@]}" start rhdh
echo "Restarted rhdh — http://localhost:7007 (compose mode=$(get_compose_mode))"
