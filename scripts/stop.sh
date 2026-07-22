#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

load_env
cd "${RHDH_LOCAL}"
read -r -a COMPOSE_ARR <<< "${COMPOSE}"
"${COMPOSE_ARR[@]}" down
echo "RHDH Local stopped."
