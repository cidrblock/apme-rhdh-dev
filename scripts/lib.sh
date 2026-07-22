#!/usr/bin/env bash
# Shared helpers for apme-rhdh-dev scripts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_env() {
  if [[ -f "${ROOT_DIR}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/.env"
    set +a
  elif [[ -f "${ROOT_DIR}/.env.example" ]]; then
    echo "No .env found — using .env.example defaults. Run: cp .env.example .env" >&2
    set -a
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/.env.example"
    set +a
  fi

  : "${HOME:?}"
  PLUGIN_REPO="${PLUGIN_REPO:-${HOME}/github/ansible-backstage-plugins}"
  RHDH_LOCAL="${RHDH_LOCAL:-${HOME}/github/rhdh-local}"
  APME_BASE_URL="${APME_BASE_URL:-http://host.containers.internal:8080}"
  COMPOSE="${COMPOSE:-podman compose}"
  RHDH_LOCAL_GIT="${RHDH_LOCAL_GIT:-https://github.com/redhat-developer/rhdh-local.git}"
  PLUGIN_REPO_GIT="${PLUGIN_REPO_GIT:-https://github.com/ansible/ansible-backstage-plugins.git}"
  PLUGIN_REPO_BRANCH="${PLUGIN_REPO_BRANCH:-prototype/apme}"

  # Expand $HOME in values copied from .env.example literally
  PLUGIN_REPO="${PLUGIN_REPO/\$\{HOME\}/$HOME}"
  PLUGIN_REPO="${PLUGIN_REPO/\$HOME/$HOME}"
  RHDH_LOCAL="${RHDH_LOCAL/\$\{HOME\}/$HOME}"
  RHDH_LOCAL="${RHDH_LOCAL/\$HOME/$HOME}"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

use_node_22() {
  if [[ -s "${HOME}/.nvm/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HOME}/.nvm/nvm.sh"
    nvm use 22 >/dev/null 2>&1 || nvm use 20 >/dev/null 2>&1 || true
  fi
  local major
  major="$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
  if [[ "${major}" -lt 20 ]]; then
    echo "Node 20 or 22 required (found: $(node --version 2>/dev/null || echo none))" >&2
    echo "Install via nvm: nvm install 22 && nvm use 22" >&2
    exit 1
  fi
}

install_rhdh_configs() {
  load_env
  mkdir -p "${RHDH_LOCAL}/configs/dynamic-plugins" \
    "${RHDH_LOCAL}/configs/app-config" \
    "${RHDH_LOCAL}/configs/catalog-entities"

  cp "${ROOT_DIR}/configs/dynamic-plugins.override.yaml" \
    "${RHDH_LOCAL}/configs/dynamic-plugins/dynamic-plugins.override.yaml"
  cp "${ROOT_DIR}/configs/compose.override.yaml" \
    "${RHDH_LOCAL}/compose.override.yaml"

  # Prefer live template from PLUGIN_REPO; fall back to vendored copy.
  local template_src="${ROOT_DIR}/catalog/apme-register-git-repository"
  if [[ -f "${PLUGIN_REPO}/examples/apme-register-git-repository/template.yaml" ]]; then
    template_src="${PLUGIN_REPO}/examples/apme-register-git-repository"
  fi
  rm -rf "${RHDH_LOCAL}/configs/catalog-entities/apme-register-git-repository"
  cp -a "${template_src}" \
    "${RHDH_LOCAL}/configs/catalog-entities/apme-register-git-repository"
  cp -f "${ROOT_DIR}/catalog/seed-git-repository.yaml" \
    "${RHDH_LOCAL}/configs/catalog-entities/seed-git-repository.yaml"

  # Substitute APME_BASE_URL into app-config.local.yaml
  sed "s|baseUrl: http://host.containers.internal:8080|baseUrl: ${APME_BASE_URL}|g" \
    "${ROOT_DIR}/configs/app-config.local.yaml" \
    > "${RHDH_LOCAL}/configs/app-config/app-config.local.yaml"

  # Append GitHub integration only when a real token is present. Empty string
  # fails Backstage config validation (got empty-string, wanted string).
  local env_file="${RHDH_LOCAL}/.env"
  touch "${env_file}"
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    cat >> "${RHDH_LOCAL}/configs/app-config/app-config.local.yaml" <<EOF

integrations:
  github:
    - host: github.com
      token: \${GITHUB_TOKEN}
EOF
    if grep -q '^GITHUB_TOKEN=' "${env_file}" 2>/dev/null; then
      sed -i "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=${GITHUB_TOKEN}|" "${env_file}"
    else
      echo "GITHUB_TOKEN=${GITHUB_TOKEN}" >> "${env_file}"
    fi
  else
    # Drop stale token so compose does not inject an empty value from a prior run
    if grep -q '^GITHUB_TOKEN=' "${env_file}" 2>/dev/null; then
      sed -i '/^GITHUB_TOKEN=/d' "${env_file}"
    fi
  fi

  echo "Installed configs into ${RHDH_LOCAL}"
  echo "  catalog template: …/apme-register-git-repository/template.yaml"
  echo "  seed entity:      …/seed-git-repository.yaml"
}
