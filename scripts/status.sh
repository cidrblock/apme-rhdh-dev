#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

load_env
echo "ROOT          ${ROOT_DIR}"
echo "PLUGIN_REPO   ${PLUGIN_REPO}"
echo "RHDH_LOCAL    ${RHDH_LOCAL}"
echo "APME_BASE_URL ${APME_BASE_URL}"
echo "COMPOSE       ${COMPOSE}"
echo "COMPOSE_MODE  $(get_compose_mode)"
echo -n "Gateway :8080 "
if curl -sf -o /dev/null http://127.0.0.1:8080/docs; then echo OK; else echo DOWN; fi

if [[ -d "${PLUGIN_REPO}/.git" ]]; then
  echo "Plugin branch $(git -C "${PLUGIN_REPO}" branch --show-current) @ $(git -C "${PLUGIN_REPO}" rev-parse --short HEAD)"
fi

if [[ -d "${RHDH_LOCAL}" ]]; then
  echo "local-plugins:"
  ls -1 "${RHDH_LOCAL}/local-plugins" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
  if [[ -d "${RHDH_LOCAL}/dynamic-plugins-root" ]]; then
    echo "dynamic-plugins-root: $(find "${RHDH_LOCAL}/dynamic-plugins-root" -maxdepth 1 -mindepth 1 | wc -l) entries"
  fi
  compose_args
  cd "${RHDH_LOCAL}"
  "${COMPOSE_ARR[@]}" ps 2>/dev/null || true
fi
