#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

load_env
compose_args
cd "${RHDH_LOCAL}"
"${COMPOSE_ARR[@]}" down
# Clear mode so the next make up starts clean
rm -f "$(compose_mode_file)"
echo "RHDH Local stopped."
