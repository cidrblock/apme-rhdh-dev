#!/usr/bin/env bash
# Fast React UI loop: backstage-cli repo start in PLUGIN_REPO (HMR).
# Ports: FE :3001, backend :7008 — avoids native APME (:3000) and RHDH Local (:7007).
#
# NOTE: Do not use `yarn start` here — packages/scripts/start.sh does not forward
# --config, so overlays never apply and the app still binds :3000.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

load_env
use_node_22
require_cmd yarn

REACT_PORT="${REACT_PORT:-3001}"
REACT_BACKEND_PORT="${REACT_BACKEND_PORT:-7008}"
REACT_CONFIG="${ROOT_DIR}/configs/app-config.react.yaml"

if [[ ! -d "${PLUGIN_REPO}/plugins/backstage-apme" ]]; then
  echo "Missing APME plugins under ${PLUGIN_REPO}. Run: make setup" >&2
  exit 1
fi

if [[ ! -f "${REACT_CONFIG}" ]]; then
  echo "Missing ${REACT_CONFIG}" >&2
  exit 1
fi

# Load PLUGIN_REPO/.env when present (same vars yarn start / dotenv-cli use).
if [[ -f "${PLUGIN_REPO}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${PLUGIN_REPO}/.env"
  set +a
fi

# Stubs so backend config schema is satisfied without a real AAP / OAuth app.
# Override via PLUGIN_REPO/.env when you have real values.
export AAP_HOST="${AAP_HOST:-http://127.0.0.1:9}"
export AAP_API_TOKEN="${AAP_API_TOKEN:-local-dev-unused-token}"
export AAP_AUTH_CLIENT_ID="${AAP_AUTH_CLIENT_ID:-local-dev}"
export AAP_AUTH_CLIENT_SECRET="${AAP_AUTH_CLIENT_SECRET:-local-dev}"
export AUTH_GITHUB_CLIENT_ID="${AUTH_GITHUB_CLIENT_ID:-local-dev}"
export AUTH_GITHUB_CLIENT_SECRET="${AUTH_GITHUB_CLIENT_SECRET:-local-dev}"
export AUTH_GITLAB_CLIENT_ID="${AUTH_GITLAB_CLIENT_ID:-local-dev}"
export AUTH_GITLAB_CLIENT_SECRET="${AUTH_GITLAB_CLIENT_SECRET:-local-dev}"

# Empty integration tokens break Backstage config ("empty-string" invalid).
if [[ -z "${GITHUB_INTEGRATION_TOKEN:-}" ]]; then
  unset GITHUB_INTEGRATION_TOKEN || true
fi
if [[ -z "${GITLAB_INTEGRATION_TOKEN:-}" ]]; then
  unset GITLAB_INTEGRATION_TOKEN || true
fi

port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tlnH 2>/dev/null | grep -E ":${port}\\s" >/dev/null
  elif command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
  else
    return 1
  fi
}

if port_in_use "${REACT_PORT}"; then
  echo "ERROR: port ${REACT_PORT} is already in use (frontend)." >&2
  echo "       Free it, or set REACT_PORT and update configs/app-config.react.yaml." >&2
  exit 1
fi
if port_in_use "${REACT_BACKEND_PORT}"; then
  echo "ERROR: port ${REACT_BACKEND_PORT} is already in use (backend)." >&2
  echo "       Free it, or set REACT_BACKEND_PORT / update configs/app-config.react.yaml." >&2
  exit 1
fi

if ! curl -sf -o /dev/null "http://127.0.0.1:8080/docs"; then
  echo "WARNING: APME Gateway not reachable at http://127.0.0.1:8080"
  echo "         For real scans: cd ~/github/apme && tox -e up"
  echo
fi

export PATH="${PLUGIN_REPO}/node_modules/.bin:${PATH}"
if [[ ! -x "${PLUGIN_REPO}/node_modules/.bin/backstage-cli" ]]; then
  echo "backstage-cli not found — running yarn install…"
  (cd "${PLUGIN_REPO}" && yarn install)
fi

# Native modules (better-sqlite3) must match the current Node ABI.
# NODE_MODULE_VERSION 111 = Node 20; 127 = Node 22. Mismatch → backend never
# becomes ready and every /api/* returns 404 (UI shows page-not-found).
ensure_native_modules() {
  if ! (
    cd "${PLUGIN_REPO}"
    node -e "require('better-sqlite3')" >/dev/null 2>&1
  ); then
    echo "better-sqlite3 ABI mismatch for Node $(node -v) — rebuilding…"
    (cd "${PLUGIN_REPO}" && yarn rebuild better-sqlite3)
    if ! (
      cd "${PLUGIN_REPO}"
      node -e "require('better-sqlite3')" >/dev/null 2>&1
    ); then
      echo "ERROR: better-sqlite3 still fails to load under Node $(node -v)." >&2
      echo "       Try: cd ${PLUGIN_REPO} && rm -rf node_modules && yarn install" >&2
      exit 1
    fi
  fi
}
ensure_native_modules

# Same secrets bootstrap as PLUGIN_REPO/scripts/start.sh
export BACKEND_SECRET="${BACKEND_SECRET:-$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('base64'))")}"
export AUTH_SIGNING_KEY="${AUTH_SIGNING_KEY:-$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('base64'))")}"
export PORT="${REACT_PORT}"
export NODE_OPTIONS="${NODE_OPTIONS:-} --no-node-snapshot"

echo "Starting plugin monorepo UI in ${PLUGIN_REPO}"
echo "  Frontend:  http://localhost:${REACT_PORT}   (native APME UI stays on :3000)"
echo "  Backend:   http://localhost:${REACT_BACKEND_PORT}   (RHDH Local stays on :7007)"
echo "  Overlay:   ${REACT_CONFIG}"
echo "  Node:      $(node -v)"
echo
echo "Open after backend is ready (wait for Listening on :${REACT_BACKEND_PORT}):"
echo "  Sign in as Guest"
echo "  Git Repositories: http://localhost:${REACT_PORT}/self-service/repositories/catalog"
echo "  Content Quality:  http://localhost:${REACT_PORT}/self-service/repositories/quality"
echo "  (/apme is a legacy redirect and may 404 — do not use it)"
echo
echo "Stop with Ctrl+C. For dynamic-plugin checks use: make up-dev / make sync-dev"
echo

cd "${PLUGIN_REPO}"

# Absolute paths: package start resolves --config relative to packages/* cwd.
BASE_CONFIG="${PLUGIN_REPO}/app-config.yaml"
if [[ ! -f "${BASE_CONFIG}" ]]; then
  echo "Missing ${BASE_CONFIG}" >&2
  exit 1
fi

echo "Configs: ${BASE_CONFIG} + ${REACT_CONFIG}"
echo

# Call CLI directly so --config is honored (yarn start → start.sh drops args).
exec backstage-cli repo start \
  --config "${BASE_CONFIG}" \
  --config "${REACT_CONFIG}"
