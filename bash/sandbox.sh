# Pi sandbox shortcuts
function sb() {
  local subcommand="${1:-help}"
  if (( $# > 0 )); then shift; fi
  case "$subcommand" in
    up) _sb_up "$@" ;;
    shell) _sb_shell "$@" ;;
    down) _sb_down "$@" ;;
    status) _sb_status "$@" ;;
    map) _sb_map "$@" ;;
    open) _sb_open "$@" ;;
    help|-h|--help)
      printf '%s\n' \
        'Usage: sb <command> [arguments...]' '' \
        '  up [id] [sbx arguments...] [-- bash arguments...]  Initialize and enter Bash' \
        '  shell [id] [bash arguments...]                    Open another Bash shell' \
        '  down [id] [sbx arguments...]                      Stop without removing' \
        '  status [id] [sbx arguments...]                    Inspect the sandbox' \
        '  map [id]                                         Interactively publish a port' \
        '  open [id]                                        Select a published port and open a browser' \
        '  help                                             Show this help' '' \
        'up/shell/down/status IDs default to HERDR_WORKSPACE_ID.' \
        'map/open select a sandbox: positional ID, otherwise the Herdr workspace ID, otherwise all.' ;;
    *)
      printf 'Unknown sb command: %s\n' "$subcommand" >&2
      sb help >&2
      return 1 ;;
  esac
}

# shortcut: directory basenames must be unique within an ID; use path-based names if they collide.
_sb_map_ports_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../sbx" && pwd)/sbpmap-ports.mjs"
function _sb_up() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sb up [id] [sbx arguments...] [-- bash arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  local sbx_argc=0 arg
  for arg in "$@"; do
    case "$arg" in
      --) break ;;
      -d|--detach|--detach=*|--rm|--rm=*)
        echo 'sb up opens a shell; use sbx directly for --detach or --rm.' >&2
        return 1 ;;
    esac
    ((sbx_argc += 1))
  done
  local name="sbx-${PWD##*/}-$id"
  local pi_path pi_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
  pi_path=$(type -P pi) || { echo 'sb up requires Pi installed on the host.' >&2; return 1; }
  if [[ $pi_path != /* || $pi_dir != /* ]]; then
    echo 'sb up requires absolute host Pi executable and authentication paths.' >&2
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
  sbx secret set github --sandbox "$name" --force \
    --command 'gh auth token' --refresh on-demand >/dev/null || return
  sbx secret set pi-copilot --sandbox "$name" --force \
    --command "$copilot_command" --refresh 1m >/dev/null || return
  if [[ ${HERDR_ENV:-} == 1 && -n ${HERDR_WORKSPACE_ID:-} ]]; then
    herdr workspace rename "$HERDR_WORKSPACE_ID" "$name" >/dev/null 2>&1 || true
  fi
  HERDR_AGENT=pi sbx run --clone --name "$name" "$HOME/Devs/dotfiles/sbx" . "${@:1:sbx_argc}" \
    --kit-arg "copilot_host=$copilot_host" --env "PI_COPILOT_BASE_URL=https://$copilot_host" -- -c : || {
    local status=$?
    case "$status" in 130|143) return "$status" ;; esac
    printf 'Sandbox initialization failed (exit %s); opening Bash for debugging.\n' "$status" >&2
  }
  shift "$sbx_argc"
  if [[ ${1:-} == -- ]]; then shift; fi
  HERDR_AGENT=pi _sb_shell "$id" "$@"
}

function _sb_shell() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sb shell [id] [bash arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  sbx exec -it -w "$PWD" "sbx-${PWD##*/}-$id" bash "$@"
}

function _sb_down() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sb down [id] [sbx arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  sbx stop "sbx-${PWD##*/}-$id" "$@"
}

function _sb_status() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sb status [id] [sbx arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  sbx inspect "sbx-${PWD##*/}-$id" "$@"
}

function _sb_select_sandbox() {
  local id="${1:-}" tool sandboxes matches rows selection
  if [[ -z $id && ${HERDR_ENV:-} == 1 ]]; then id="${HERDR_WORKSPACE_ID:-}"; fi
  for tool in sbx jq peco; do
    command -v "$tool" >/dev/null 2>&1 || { echo "Sandbox selection requires $tool on the host." >&2; return 1; }
  done
  sandboxes=$(sbx ls --format json) || return
  matches=$(jq -c --arg id "$id" '[.[] | select($id == "" or
    (.name | startswith("sbx-") and endswith("-" + $id)))]' <<< "$sandboxes") || return
  if [[ $matches == '[]' ]]; then
    echo "No sandboxes found${id:+ for workspace $id}." >&2
    return 1
  fi
  rows=$(jq -r '.[] | [.name, .status, ((.workspaces // []) | join(", "))] | @tsv' <<< "$matches") || return
  selection=$(peco --prompt 'Sandbox> ' --on-cancel error <<< "$rows") || return 130
  [[ -n $selection ]] || return 130
  jq -ce --arg name "${selection%%$'\t'*}" 'first(.[] | select(.name == $name))' <<< "$matches"
}

function _sb_open() {
  local usage='Usage: sb open [id]' id="${1:-}" opener=open sandbox rows selection
  if (( $# > 1 )); then echo "$usage" >&2; return 1; fi
  case "$id" in
    -h|--help) echo "$usage"; return 0 ;;
    -*) echo "$usage" >&2; return 1 ;;
  esac
  if [[ $OSTYPE != darwin* ]]; then opener=xdg-open; fi
  command -v "$opener" >/dev/null 2>&1 || { echo "sb open requires $opener on the host." >&2; return 1; }

  sandbox=$(_sb_select_sandbox "$id") || return
  # shortcut: HTTP only; add scheme selection when HTTPS services are needed.
  rows=$(jq -r '
    .name as $name | .ports[]? |
    select(.protocol == "tcp" or .protocol == "tcp4" or .protocol == "tcp6") |
    select((.host_port | type) == "number" and .host_port >= 1 and .host_port <= 65535 and
      (.host_port | floor) == .host_port) |
    select(.host_ip | test("^[0-9.]+$|^[0-9a-fA-F:.]*:[0-9a-fA-F:.]+$")) |
    (if .host_ip == "0.0.0.0" then "127.0.0.1"
     elif .host_ip == "::" then "[::1]"
     elif (.host_ip | contains(":")) then "[" + .host_ip + "]"
     else .host_ip end) as $host |
    [$name, "\(.sandbox_port)/\(.protocol)", "http://\($host):\(.host_port)"] | @tsv
  ' <<< "$sandbox") || return
  if [[ -z $rows ]]; then
    echo 'No published TCP ports found.' >&2
    return 1
  fi
  selection=$(peco --prompt 'Open> ' --on-cancel error <<< "$rows") || return 130
  [[ -n $selection ]] || return 130
  "$opener" "${selection##*$'\t'}"
}

function _sb_map() {
  local usage='Usage: sb map [id]' id="${1:-}"
  if (( $# > 1 )); then echo "$usage" >&2; return 1; fi
  case "$id" in
    -h|--help) echo "$usage"; return 0 ;;
    -*) echo "$usage" >&2; return 1 ;;
  esac
  if [[ ! -t 0 || ! -t 2 ]]; then
    echo 'sb map requires a terminal.' >&2; return 1
  fi

  local sandbox name selection
  sandbox=$(_sb_select_sandbox "$id") || return
  name=$(jq -r '.name' <<< "$sandbox") || return
  if ! jq -e '.status == "running"' <<< "$sandbox" >/dev/null; then
    echo "Sandbox $name is not running; start it before mapping ports." >&2; return 1
  fi
  printf 'Sandbox: %s\n' "$name" >&2

  local mappings ports rows blocked existing port host_port=''
  mappings=$(sbx port ls "$name" --format json) || return
  # shortcut: sbx may start a sandbox stopped after this state check; avoid concurrent lifecycle commands.
  ports=$(sbx exec -i "$name" node --input-type=module - < "$_sb_map_ports_script") || return
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
  selection=$(peco --prompt 'Port> ' --on-cancel error <<< "$rows") || return 130
  [[ -n $selection ]] || return 130
  port=${selection%%$'\t'*}
  if ! jq -e --argjson port "$port" 'any(.[]; .port == $port and .loopback == false)' <<< "$ports" >/dev/null; then
    echo "Port $port has no reachable IPv4 TCP listener; bind the service to 0.0.0.0." >&2; return 1
  fi
  existing=$(jq -r --argjson port "$port" '
    .[] | select(.sandbox_port == $port and .host_ip == "127.0.0.1" and
      (.protocol == "tcp4" or .protocol == "tcp")) |
    "Mapped: \(.host_ip):\(.host_port) -> sandbox:\(.sandbox_port)/\(.protocol)"' <<< "$mappings") || return
  if [[ -n $existing ]]; then
    printf '%s\n' "$existing"
    return 0
  fi
  read -r -p 'Host port [Enter: auto]: ' host_port || return 130
  if [[ -n $host_port ]]; then
    if [[ ! $host_port =~ ^[0-9]{1,5}$ ]] || (( 10#$host_port < 1 || 10#$host_port > 65535 )); then
      echo 'Host port must be between 1 and 65535.' >&2; return 1
    fi
    host_port=$((10#$host_port))
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
