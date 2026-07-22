#!/usr/bin/env bash
# Start RHDH Local with host-mounted dynamic-plugins-root (FE --dev loop).
# After this: edit FE → make sync-dev → browser refresh (no recreate).
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

load_env
install_rhdh_configs

if [[ ! -d "${RHDH_LOCAL}/local-plugins/ansible-plugin-backstage-apme" ]]; then
  echo "Backend/local-plugins not synced yet. Run once: make sync" >&2
  echo "(up-dev still needs local-plugins for backend modules + first FE install.)" >&2
  exit 1
fi

if curl -sf -o /dev/null "http://127.0.0.1:8080/docs"; then
  echo "APME Gateway OK on host :8080"
else
  echo "WARNING: APME Gateway not reachable at http://127.0.0.1:8080"
  echo "         Start it with: cd ~/github/apme && tox -e up"
fi

mkdir -p "${RHDH_LOCAL}/dynamic-plugins-root"

echo "Exporting FE plugins into dynamic-plugins-root (initial sync-dev)…"
"${ROOT_DIR}/scripts/sync-dev.sh"

set_compose_mode "dev"
compose_args "dev"

echo "Starting RHDH Local (dev mount) in ${RHDH_LOCAL}"
cd "${RHDH_LOCAL}"
"${COMPOSE_ARR[@]}" up -d --force-recreate --build=false

echo
echo "RHDH Local (dev): http://localhost:7007  (Guest login)"
echo "After FE edits:   make sync-dev   then hard-refresh the browser"
echo "Everyday UI:      make react      (yarn start — fastest HMR)"
echo "Stop:             make down"
echo "Logs:             (cd ${RHDH_LOCAL} && ${COMPOSE} -f compose.yaml -f compose.override.yaml -f compose-dynamic-plugins-root.yaml logs -f rhdh)"
