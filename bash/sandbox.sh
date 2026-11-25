# Pi sandbox shortcuts
# shortcut: directory basenames must be unique within an ID; use path-based names if they collide.
unalias sbpi sbup sbbash sbstop sbdown sbstatus sbpmap 2>/dev/null || true
unset -f sbpi sbstop
_sbpmap_ports_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/sbpmap-ports.py"
function sbup() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sbup [id] [sbx arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  local name="sbx-${PWD##*/}-$id"
  local pi_path pi_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
  pi_path=$(type -P pi) || { echo 'sbup requires Pi installed on the host.' >&2; return 1; }
  if [[ $pi_path != /* || $pi_dir != /* ]]; then
    echo 'sbup requires absolute host Pi executable and authentication paths.' >&2
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
    "$HOME/Devs/dotfiles/sbx" . "$@" || status=$?
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
  sbx exec -it -w "$PWD" "sbx-${PWD##*/}-$id" bash "$@"
}

function sbdown() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sbdown [id] [sbx arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  sbx stop "sbx-${PWD##*/}-$id" "$@"
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
  sbx inspect "sbx-${PWD##*/}-$id" "$@"
}

function sbpmap() {
  local usage='Usage: sbpmap [--id ID] [HOST_PORT:SANDBOX_PORT | SANDBOX_PORT]'
  local id="${HERDR_WORKSPACE_ID:-}" spec='' port='' host_port='' tool
  while (( $# > 0 )); do
    case "$1" in
      --id)
        if (( $# < 2 )) || [[ -z $2 ]]; then
          echo "$usage" >&2; return 1
        fi
        id=$2; shift 2 ;;
      -h|--help)
        printf '%s\n' "$usage" 'Without a port, select a listener. Omit HOST_PORT for automatic allocation.'
        return 0 ;;
      *)
        if [[ -n $spec || ! $1 =~ ^([0-9]{1,5}:)?[0-9]{1,5}$ ]]; then
          echo "$usage" >&2; return 1
        fi
        spec=$1; shift ;;
    esac
  done
  if [[ -z $id ]]; then
    printf '%s\n' "$usage" 'An ID is required when HERDR_WORKSPACE_ID is unset.' >&2
    return 1
  fi
  if [[ -n $spec ]]; then
    port=${spec##*:}
    if (( 10#$port < 1 || 10#$port > 65535 )); then
      echo 'Sandbox port must be between 1 and 65535.' >&2; return 1
    fi
    port=$((10#$port))
    if [[ $spec == *:* ]]; then
      host_port=${spec%%:*}
      if (( 10#$host_port < 1 || 10#$host_port > 65535 )); then
        echo 'Host port must be between 1 and 65535.' >&2; return 1
      fi
      host_port=$((10#$host_port))
    fi
  fi
  for tool in sbx jq; do
    command -v "$tool" >/dev/null 2>&1 || { echo "sbpmap requires $tool on the host." >&2; return 1; }
  done

  if [[ -z $port ]]; then
    if [[ ! -t 0 || ! -t 2 ]]; then
      echo 'Port selection requires a terminal; specify a sandbox port instead.' >&2; return 1
    fi
    command -v peco >/dev/null 2>&1 || { echo 'sbpmap requires peco for selection.' >&2; return 1; }
  fi

  local sandboxes matches nearby name selection
  sandboxes=$(sbx ls --format json) || return
  matches=$(jq -c --arg id "$id" '[.[] | select(.name | startswith("sbx-") and endswith("-" + $id))]' <<< "$sandboxes") || return
  if [[ $matches == '[]' ]]; then
    echo "No sandbox found for workspace $id." >&2; return 1
  fi
  if (( $(jq length <<< "$matches") > 1 )); then
    nearby=$(jq -c --arg cwd "$(pwd -P)" '[.[] | select(any(.workspaces[]?; . as $path | $cwd == $path or ($cwd | startswith($path + "/"))))]' <<< "$matches") || return
    if [[ $nearby != '[]' ]]; then
      matches=$nearby
    fi
  fi
  if (( $(jq length <<< "$matches") == 1 )); then
    name=$(jq -r '.[0].name' <<< "$matches") || return
  else
    if [[ ! -t 0 || ! -t 2 ]]; then
      echo 'Multiple sandboxes match this workspace; run in a terminal to select one.' >&2; return 1
    fi
    command -v peco >/dev/null 2>&1 || { echo 'sbpmap requires peco for selection.' >&2; return 1; }
    selection=$(jq -r '.[] | [.name, .status, ((.workspaces // []) | join(", "))] | @tsv' <<< "$matches" |
      peco --prompt 'Sandbox> ' --on-cancel error) || return 130
    [[ -n $selection ]] || return 130
    name=${selection%%$'\t'*}
  fi
  if ! jq -e --arg name "$name" 'any(.[]; .name == $name and .status == "running")' <<< "$matches" >/dev/null; then
    echo "Sandbox $name is not running; start it before mapping ports." >&2; return 1
  fi
  printf 'Sandbox: %s\n' "$name" >&2

  local mappings ports rows blocked existing
  mappings=$(sbx port ls "$name" --format json) || return
  # shortcut: sbx may start a sandbox stopped after this state check; avoid concurrent lifecycle commands.
  ports=$(sbx exec -i "$name" python3 -I - < "$_sbpmap_ports_script") || return
  if [[ -z $port ]]; then
    rows=$(jq -r --argjson mappings "$mappings" '
      group_by(.port)[] | select(any(.[]; .loopback == false)) | .[0].port as $port |
      [$port, (map(.process) | unique | join(",")), (map(.address) | unique | join(",")),
       ([$mappings[] | select(.sandbox_port == $port and .host_ip == "127.0.0.1" and
         (.protocol == "tcp4" or .protocol == "tcp")) | "\(.host_ip):\(.host_port)"] |
        unique | if length == 0 then "unmapped" else join(",") end)] | @tsv' <<< "$ports") || return
    blocked=$(jq -r 'group_by(.port)[] | select(all(.[]; .loopback)) |
      "  \(.[0].port): \(map(.address) | unique | join(","))"' <<< "$ports") || return
    if [[ -n $blocked ]]; then
      printf 'Loopback-only listeners (not selectable; bind the service to 0.0.0.0):\n%s\n' "$blocked" >&2
    fi
    if [[ -z $rows ]]; then
      echo 'No reachable IPv4 TCP listeners found.' >&2; return 1
    fi
    echo 'PORT / PROCESS / LISTEN / HOST' >&2
    selection=$(peco --prompt 'Port> ' --on-cancel error <<< "$rows") || return 130
    [[ -n $selection ]] || return 130
    port=${selection%%$'\t'*}
    # Existing mappings need no new host-port prompt.
    if ! jq -e --argjson port "$port" 'any(.[]; .sandbox_port == $port and .host_ip == "127.0.0.1" and
      (.protocol == "tcp4" or .protocol == "tcp"))' <<< "$mappings" >/dev/null; then
      read -r -p 'Host port [Enter: auto]: ' host_port || return 130
      if [[ -n $host_port ]]; then
        if [[ ! $host_port =~ ^[0-9]{1,5}$ ]] || (( 10#$host_port < 1 || 10#$host_port > 65535 )); then
          echo 'Host port must be between 1 and 65535.' >&2; return 1
        fi
        host_port=$((10#$host_port))
      fi
    fi
  fi
  if ! jq -e --argjson port "$port" 'any(.[]; .port == $port and .loopback == false)' <<< "$ports" >/dev/null; then
    echo "Port $port has no reachable IPv4 TCP listener; bind the service to 0.0.0.0." >&2; return 1
  fi
  existing=$(jq -r --argjson port "$port" --arg host "$host_port" '
    .[] | select(.sandbox_port == $port and .host_ip == "127.0.0.1" and
      (.protocol == "tcp4" or .protocol == "tcp") and ($host == "" or .host_port == ($host | tonumber))) |
    "Mapped: \(.host_ip):\(.host_port) -> sandbox:\(.sandbox_port)/\(.protocol)"' <<< "$mappings") || return
  if [[ -n $existing ]]; then
    printf '%s\n' "$existing"
    return 0
  fi
  sbx --no-input port publish "$name" "${host_port:+$host_port:}$port/tcp4" >/dev/null || return
  mappings=$(sbx port ls "$name" --format json) || {
    echo 'Port was published, but its host binding could not be read; check sbx port ls.' >&2; return 1;
  }
  existing=$(jq -r --argjson port "$port" --arg host "$host_port" '
    .[] | select(.sandbox_port == $port and .host_ip == "127.0.0.1" and .protocol == "tcp4" and
      ($host == "" or .host_port == ($host | tonumber))) |
    "Mapped: \(.host_ip):\(.host_port) -> sandbox:\(.sandbox_port)/\(.protocol)"' <<< "$mappings") || return
  if [[ -z $existing ]]; then
    echo 'Port was published, but no matching IPv4 loopback binding was reported; check sbx port ls.' >&2; return 1
  fi
  printf '%s\n' "$existing"
}
