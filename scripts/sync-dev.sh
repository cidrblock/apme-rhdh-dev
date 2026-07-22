#!/usr/bin/env bash
# Re-export frontend plugins with rhdh-cli --dev into rhdh-local/dynamic-plugins-root.
# RHDH must already be running via make up-dev. Then refresh the browser (no recreate).
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

load_env
use_node_22
require_cmd yarn

if [[ ! -d "${PLUGIN_REPO}/plugins/backstage-apme" ]]; then
  echo "Missing APME plugins under ${PLUGIN_REPO}. Run: make setup" >&2
  exit 1
fi

if [[ ! -d "${RHDH_LOCAL}" ]]; then
  echo "Missing ${RHDH_LOCAL}. Run: make setup" >&2
  exit 1
fi

# Space-separated plugin directory names under plugins/
# Override: SYNC_DEV_PLUGINS="backstage-apme self-service"
SYNC_DEV_PLUGINS="${SYNC_DEV_PLUGINS:-backstage-apme}"

ROOT_OUT="${RHDH_LOCAL}/dynamic-plugins-root"
mkdir -p "${ROOT_OUT}"

export PATH="${PLUGIN_REPO}/node_modules/.bin:${PATH}"

if [[ ! -x "${PLUGIN_REPO}/node_modules/.bin/rhdh-cli" ]]; then
  echo "rhdh-cli not found — running yarn install…"
  (cd "${PLUGIN_REPO}" && yarn install)
fi

echo "Using Node $(node --version) / Yarn $(yarn --version)"
echo "PLUGIN_REPO=${PLUGIN_REPO}"
echo "dynamic-plugins-root=${ROOT_OUT}"
echo "Plugins: ${SYNC_DEV_PLUGINS}"
echo

# Shared packages embedded by backstage-apme export
echo "Building shared packages (apme-common)…"
if [[ -d "${PLUGIN_REPO}/plugins/backstage-apme-common" ]]; then
  (cd "${PLUGIN_REPO}/plugins/backstage-apme-common" && yarn build)
fi
if [[ -d "${PLUGIN_REPO}/plugins/backstage-rhaap-common" ]]; then
  (cd "${PLUGIN_REPO}/plugins/backstage-rhaap-common" && yarn build)
fi

for src in ${SYNC_DEV_PLUGINS}; do
  plugin_path="${PLUGIN_REPO}/plugins/${src}"
  if [[ ! -d "${plugin_path}" ]]; then
    echo "Skip missing plugin: ${src}" >&2
    continue
  fi
  echo "==> export --dev ${src}"
  (
    cd "${plugin_path}"
    # Pass-through to rhdh-cli (export-dynamic script already sets embed flags for apme)
    yarn export-dynamic --dev --dynamic-plugins-root "${ROOT_OUT}"
  )
done

chmod -R a+rX "${ROOT_OUT}" || true

echo
echo "Dev export done → ${ROOT_OUT}"
echo "Hard-refresh http://localhost:7007 (no container restart)."
if [[ "$(get_compose_mode)" != "dev" ]]; then
  echo "NOTE: RHDH is not in up-dev mode (compose mode=$(get_compose_mode))."
  echo "      Start with: make up-dev"
fi
