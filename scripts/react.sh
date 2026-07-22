#!/usr/bin/env bash
# Fast React UI loop: yarn start in PLUGIN_REPO (HMR). Not RHDH / dynamic plugins.
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

if ! curl -sf -o /dev/null "http://127.0.0.1:8080/docs"; then
  echo "WARNING: APME Gateway not reachable at http://127.0.0.1:8080"
  echo "         For real scans: cd ~/github/apme && tox -e up"
  echo "         (Or use ansible.apme.mockMode in the plugin monorepo app-config.)"
  echo
fi

echo "Starting plugin monorepo UI (yarn start) in ${PLUGIN_REPO}"
echo "This is the fastest loop for APME React work — not RHDH Local."
echo "Stop with Ctrl+C. For dynamic-plugin checks use: make up-dev / make sync-dev"
echo
cd "${PLUGIN_REPO}"
exec yarn start
