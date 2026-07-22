#!/usr/bin/env bash
# Export APME + self-service dynamic plugins into rhdh-local/local-plugins.
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

# src_dir|local-plugins folder name (must match configs/dynamic-plugins.override.yaml)
PLUGINS=(
  "self-service|ansible-plugin-backstage-self-service"
  "backstage-apme|ansible-plugin-backstage-apme"
  "catalog-backend-module-apme|ansible-backstage-plugin-catalog-backend-module-apme"
  # Provides ansible:register:git-repository for the APME Add repository template
  "scaffolder-backend-module-backstage-rhaap|ansible-plugin-scaffolder-backend-module-backstage-rhaap"
  # POST /api/catalog/ansible/git-repository used by that scaffolder action
  "catalog-backend-module-rhaap|ansible-backstage-plugin-catalog-backend-module-rhaap"
)

# Commons must be built before export (embedded by rhdh-cli).
COMMONS=(backstage-apme-common backstage-rhaap-common)

export PATH="${PLUGIN_REPO}/node_modules/.bin:${PATH}"

echo "Using Node $(node --version) / Yarn $(yarn --version)"
echo "PLUGIN_REPO=${PLUGIN_REPO}"
echo "RHDH_LOCAL=${RHDH_LOCAL}"

cd "${PLUGIN_REPO}"

if [[ ! -x "${PLUGIN_REPO}/node_modules/.bin/rhdh-cli" ]]; then
  echo "rhdh-cli not found — running yarn install…"
  yarn install
fi

echo "Generating types (yarn tsc)…"
yarn tsc

echo "Building shared packages…"
for common in "${COMMONS[@]}"; do
  if [[ -d "plugins/${common}" ]]; then
    (cd "plugins/${common}" && yarn build)
  fi
done

OUT="${RHDH_LOCAL}/local-plugins"
mkdir -p "${OUT}"

export_one() {
  local src="$1"
  local dest_name="$2"
  local plugin_path="${PLUGIN_REPO}/plugins/${src}"
  echo
  echo "==> Exporting ${src} → local-plugins/${dest_name}"
  (
    cd "${plugin_path}"
    yarn export-dynamic --clean
  )
  if [[ ! -f "${plugin_path}/dist-dynamic/package.json" ]]; then
    echo "Export failed: ${plugin_path}/dist-dynamic missing" >&2
    exit 1
  fi
  rm -rf "${OUT}/${dest_name}"
  cp -a "${plugin_path}/dist-dynamic" "${OUT}/${dest_name}"
  chmod -R a+rX "${OUT}/${dest_name}" || true
  python3 -c "import json; print('   ', json.load(open('${OUT}/${dest_name}/package.json'))['name'])"
}

for entry in "${PLUGINS[@]}"; do
  src="${entry%%|*}"
  dest="${entry##*|}"
  export_one "${src}" "${dest}"
done

echo
echo "Synced plugins in ${OUT}:"
for entry in "${PLUGINS[@]}"; do
  dest="${entry##*|}"
  ls -ld "${OUT}/${dest}"
done

install_rhdh_configs

echo
echo "Done. Start (or reload) RHDH Local with: make up"
