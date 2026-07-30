#!/usr/bin/env bash
# Start RHDH Local with APME plugin overrides (re-runs install-dynamic-plugins).
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

load_env
install_rhdh_configs

if [[ ! -d "${RHDH_LOCAL}/local-plugins/ansible-plugin-backstage-apme" ]]; then
  echo "Plugins not synced yet. Run: make sync" >&2
  exit 1
fi

# Quick Gateway check on the host (best-effort)
if curl -sf -o /dev/null "http://127.0.0.1:8080/docs"; then
  echo "APME Gateway OK on host :8080"
else
  echo "WARNING: APME Gateway not reachable at http://127.0.0.1:8080"
  echo "         Start it with: cd ~/github/apme && tox -e up"
fi

set_compose_mode "normal"
compose_args "normal"

echo "Starting RHDH Local in ${RHDH_LOCAL} (APME_BASE_URL=${APME_BASE_URL})"
cd "${RHDH_LOCAL}"

# RHDH install-dynamic-plugins.py GC bug: when a local plugin's config hash
# changes but npm-pack extract dir name is unchanged, it reinstalls then
# deletes that dir as "previously installed" (old hash still in the map).
# Symptom: Quality / Self-service vanish after sync-restart; Scalprum 404s.
# Clear cached local installs so every `make up` does a clean extract.
echo "Clearing cached local dynamic plugins (installer GC workaround)…"
if ! "${COMPOSE_ARR[@]}" run --rm --no-deps --entrypoint /bin/sh install-dynamic-plugins -c '
  root=/dynamic-plugins-root
  [ -d "$root" ] || exit 0
  for d in "$root"/ansible-*; do
    [ -e "$d" ] || continue
    echo "  rm -rf $(basename "$d")"
    rm -rf "$d"
  done
'; then
  echo "WARNING: could not clear cached local plugins; Quality tab may vanish after reinstall"
fi

# Force recreate so install-dynamic-plugins re-runs and rhdh reloads
# app-config.dynamic-plugins.yaml (plain `up -d` leaves a running rhdh stale).
"${COMPOSE_ARR[@]}" up -d --force-recreate --build=false

echo
echo "RHDH Local: http://localhost:7007  (Guest login)"
echo "Quality:    http://localhost:7007/catalog/default/component/terrible-playbook-github-manual/apme"
echo "FE HMR:     make react   |   FE in RHDH: make up-dev then make sync-dev"
echo "Logs:       (cd ${RHDH_LOCAL} && ${COMPOSE} logs -f rhdh)"
