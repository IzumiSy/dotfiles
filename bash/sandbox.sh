# Pi sandbox shortcuts
# shortcut: directory basenames must be unique within an ID; use path-based names if they collide.
unalias sbpi sbbash sbstop sbstatus 2>/dev/null || true
function sbpi() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sbpi [id] [sbx arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  local name="pi-sbx-${PWD##*/}-$id"
  local pi_path pi_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
  pi_path=$(type -P pi) || { echo 'sbpi requires Pi installed on the host.' >&2; return 1; }
  if [[ $pi_path != /* || $pi_dir != /* ]]; then
    echo 'sbpi requires absolute host Pi executable and authentication paths.' >&2
    return 1
  fi
  local copilot_host copilot_command
  # Filter in a subprocess so shell tracing never prints the bearer token.
  # shortcut: only githubcopilot.com endpoints; add trusted domains when custom Enterprise is needed.
  copilot_host=$(
    set -o pipefail
    PI_CODING_AGENT_DIR="$pi_dir" "$pi_path" auth print-bearer-token --provider github-copilot --min-expiry 5m 2>/dev/null |
      awk -F ';' '{ for (i = 1; i <= NF; i++) {
        if ($i ~ /^proxy-ep=proxy\.([a-z0-9-]+\.)?githubcopilot\.com$/) {
          sub(/^proxy-ep=proxy\./, "api.", $i); print $i; exit
        }
      } }'
  ) || { local status=$?; echo 'Could not resolve host Pi Copilot token; check the host Pi login.' >&2; return "$status"; }
  if [[ -z $copilot_host ]]; then
    echo 'Host Pi token has no supported Copilot API endpoint.' >&2
    return 1
  fi
  printf -v copilot_command 'env HOME=%q PATH=%q PI_CODING_AGENT_DIR=%q %q auth print-bearer-token --provider github-copilot --min-expiry 5m' "$HOME" "$PATH" "$pi_dir" "$pi_path"
  local gh_placeholder=sbx-gh-token-proxy-managed
  local copilot_placeholder=sbx-copilot-token-proxy-managed
  sbx secret set-custom --sandbox "$name" --host api.github.com --host github.com \
    --env GH_TOKEN --placeholder "$gh_placeholder" --command 'gh auth token' >/dev/null || return
  sbx secret set-custom --sandbox "$name" --host "$copilot_host" \
    --env COPILOT_GITHUB_TOKEN --placeholder "$copilot_placeholder" \
    --command "$copilot_command" --refresh 1m >/dev/null || return
  if [[ ${HERDR_ENV:-} == 1 && -n ${HERDR_WORKSPACE_ID:-} ]]; then
    herdr workspace rename "$HERDR_WORKSPACE_ID" "$name" >/dev/null 2>&1 || true
  fi
  local status=0
  HERDR_AGENT=pi sbx run --clone --name "$name" --env "GH_TOKEN=$gh_placeholder" \
    --env "COPILOT_GITHUB_TOKEN=$copilot_placeholder" --env "PI_COPILOT_BASE_URL=https://$copilot_host" \
    "$HOME/Devs/dotfiles/pi-sbx" . "$@" || status=$?
  return "$status"
}

function sbbash() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sbbash [id] [bash arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  sbx exec -it -w "$PWD" "pi-sbx-${PWD##*/}-$id" bash "$@"
}

function sbstop() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sbstop [id] [sbx arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  sbx stop "pi-sbx-${PWD##*/}-$id" "$@"
}

function sbstatus() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sbstatus [id] [sbx arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  sbx inspect "pi-sbx-${PWD##*/}-$id" "$@"
}
