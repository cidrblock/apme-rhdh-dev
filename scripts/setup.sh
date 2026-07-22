#!/usr/bin/env bash
# One-time (or rare) setup: .env, clone rhdh-local / plugin repo if missing, wire configs.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

load_env

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
  echo "Created ${ROOT_DIR}/.env — edit paths if needed."
  load_env
fi

require_cmd git
require_cmd node

# podman compose uses the Docker-compatible API on the user socket
if [[ "${COMPOSE}" == podman* ]] && [[ ! -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock" ]]; then
  echo "Starting podman.socket (needed for podman compose)…"
  systemctl --user start podman.socket || {
    echo "Could not start podman.socket. Run: systemctl --user enable --now podman.socket" >&2
  }
fi

if [[ ! -d "${RHDH_LOCAL}/.git" ]]; then
  echo "Cloning rhdh-local → ${RHDH_LOCAL}"
  mkdir -p "$(dirname "${RHDH_LOCAL}")"
  git clone --depth 1 "${RHDH_LOCAL_GIT}" "${RHDH_LOCAL}"
else
  echo "rhdh-local OK: ${RHDH_LOCAL}"
fi

if [[ ! -d "${PLUGIN_REPO}/.git" ]]; then
  echo "Cloning ansible-backstage-plugins → ${PLUGIN_REPO}"
  mkdir -p "$(dirname "${PLUGIN_REPO}")"
  git clone "${PLUGIN_REPO_GIT}" "${PLUGIN_REPO}"
  git -C "${PLUGIN_REPO}" checkout "${PLUGIN_REPO_BRANCH}"
else
  echo "plugin repo OK: ${PLUGIN_REPO}"
  current="$(git -C "${PLUGIN_REPO}" branch --show-current 2>/dev/null || true)"
  if [[ "${current}" != "${PLUGIN_REPO_BRANCH}" ]]; then
    echo "NOTE: ${PLUGIN_REPO} is on '${current}', expected '${PLUGIN_REPO_BRANCH}'."
    echo "      Run: git -C \"${PLUGIN_REPO}\" checkout ${PLUGIN_REPO_BRANCH}"
  fi
fi

if [[ ! -d "${PLUGIN_REPO}/plugins/backstage-apme" ]]; then
  echo "ERROR: ${PLUGIN_REPO}/plugins/backstage-apme missing."
  echo "Checkout ${PLUGIN_REPO_BRANCH} (contains APME plugins)." >&2
  exit 1
fi

if [[ ! -d "${PLUGIN_REPO}/node_modules" ]]; then
  echo "Installing plugin workspace deps (yarn)…"
  use_node_22
  (
    cd "${PLUGIN_REPO}"
    corepack enable >/dev/null 2>&1 || true
    ./install-deps 2>/dev/null || yarn install
  )
fi

install_rhdh_configs

echo
echo "Setup complete."
echo "  1) Start APME:  cd ~/github/apme && tox -e up"
echo "  2) Sync+run:    cd ${ROOT_DIR} && make sync && make up"
echo "  3) Open:        http://localhost:7007"
