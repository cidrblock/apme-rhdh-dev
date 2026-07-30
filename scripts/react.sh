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

# PIDs listening on TCP port (ss preferred; lsof fallback).
pids_on_port() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tlnpH 2>/dev/null \
      | grep -E ":${port}\\s" \
      | grep -oE 'pid=[0-9]+' \
      | cut -d= -f2 \
      | sort -u
  elif command -v lsof >/dev/null 2>&1; then
    lsof -t -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null | sort -u
  fi
}

# Stop a prior make react (or anything) on FE/backend ports so restart is one command.
stop_react_ports() {
  local port pids pid
  local any=0
  for port in "${REACT_PORT}" "${REACT_BACKEND_PORT}"; do
    pids="$(pids_on_port "${port}" || true)"
    if [[ -z "${pids}" ]]; then
      continue
    fi
    any=1
    echo "Stopping process(es) on :${port}: ${pids//$'\n'/ }"
    # shellcheck disable=SC2086
    kill ${pids} 2>/dev/null || true
  done
  if [[ "${any}" -eq 0 ]]; then
    return 0
  fi
  # Give listeners time to exit; escalate if needed.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! port_in_use "${REACT_PORT}" && ! port_in_use "${REACT_BACKEND_PORT}"; then
      echo "Ports ${REACT_PORT} / ${REACT_BACKEND_PORT} free."
      return 0
    fi
    sleep 0.3
  done
  for port in "${REACT_PORT}" "${REACT_BACKEND_PORT}"; do
    pids="$(pids_on_port "${port}" || true)"
    if [[ -n "${pids}" ]]; then
      echo "Force-killing stubborn listener(s) on :${port}: ${pids//$'\n'/ }"
      # shellcheck disable=SC2086
      kill -9 ${pids} 2>/dev/null || true
    fi
  done
  sleep 0.2
  if port_in_use "${REACT_PORT}" || port_in_use "${REACT_BACKEND_PORT}"; then
    echo "ERROR: could not free ports ${REACT_PORT} / ${REACT_BACKEND_PORT}." >&2
    echo "       Free them manually, or set REACT_PORT / REACT_BACKEND_PORT." >&2
    exit 1
  fi
  echo "Ports ${REACT_PORT} / ${REACT_BACKEND_PORT} free."
}

stop_react_ports

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

# Persist backend secrets in this repo's .env so Guest JWTs survive restart.
# Regenerating keys each run causes ERR_JWKS_NO_MATCHING_KEY → 401s → UI 404s.
persist_react_secrets() {
  local env_file="${ROOT_DIR}/.env"
  local secret key
  secret="${BACKEND_SECRET:-}"
  key="${AUTH_SIGNING_KEY:-}"
  if [[ -z "${secret}" || -z "${key}" ]]; then
    secret="${secret:-$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('base64'))")}"
    key="${key:-$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('base64'))")}"
    touch "${env_file}"
    if ! grep -q '^BACKEND_SECRET=' "${env_file}" 2>/dev/null; then
      printf '\n# make react — stable across restarts (do not commit secrets)\nBACKEND_SECRET=%s\n' "${secret}" >>"${env_file}"
    fi
    if ! grep -q '^AUTH_SIGNING_KEY=' "${env_file}" 2>/dev/null; then
      printf 'AUTH_SIGNING_KEY=%s\n' "${key}" >>"${env_file}"
    fi
    # Re-read in case file already had one of the two
    set -a
    # shellcheck disable=SC1091
    source "${env_file}"
    set +a
    secret="${BACKEND_SECRET:-$secret}"
    key="${AUTH_SIGNING_KEY:-$key}"
  fi
  export BACKEND_SECRET="${secret}"
  export AUTH_SIGNING_KEY="${key}"
}
persist_react_secrets

export PORT="${REACT_PORT}"
export NODE_OPTIONS="${NODE_OPTIONS:-} --no-node-snapshot"
# For catalog.locations in app-config.react.yaml
export PLUGIN_REPO
export APME_RHDH_DEV="${ROOT_DIR}"

echo "Starting plugin monorepo UI in ${PLUGIN_REPO}"
echo "  Frontend:  http://localhost:${REACT_PORT}   (native APME UI stays on :3000)"
echo "  Backend:   http://localhost:${REACT_BACKEND_PORT}   (RHDH Local stays on :7007)"
echo "  Overlay:   ${REACT_CONFIG}"
echo "  Node:      $(node -v)"
echo
echo "Open after backend is ready (wait for Listening on :${REACT_BACKEND_PORT}):"
echo "  Sign in as Guest  (if you see 401/JWKS errors: clear site data for localhost:${REACT_PORT})"
echo "  Git Repositories: http://localhost:${REACT_PORT}/self-service/repositories/catalog"
echo "  Add repository:   http://localhost:${REACT_PORT}/create/templates/default/apme-register-git-repository"
echo "  Seed repo (no add): Catalog → ansible-lightspeed → Quality"
echo "  Content Quality:  http://localhost:${REACT_PORT}/self-service/repositories/quality"
echo "  (/apme is a legacy redirect and may 404 — do not use it)"
echo "  (ansible sync/status 403/404 without real AAP is expected — ignore)"
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
