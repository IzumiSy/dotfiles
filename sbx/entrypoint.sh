#!/usr/bin/env bash
set -eu

if [[ -n ${PI_COPILOT_BASE_URL:-} ]]; then
  node "$(dirname "$0")/configure-copilot.mjs"
fi

exec bash -l "$@"
