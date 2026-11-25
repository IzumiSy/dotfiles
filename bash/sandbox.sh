# Pi sandbox shortcuts
# shortcut: directory basenames must be unique within an ID; use path-based names if they collide.
unalias sbpi sbbash sbstop 2>/dev/null || true
function sbpi() {
  local id="${1:-${HERDR_WORKSPACE_ID:-}}"
  if [[ -z $id ]]; then
    echo 'Usage: sbpi [id] [sbx arguments...] (id is required when HERDR_WORKSPACE_ID is unset)' >&2
    return 1
  fi
  if (( $# > 0 )); then
    shift
  fi
  HERDR_AGENT=pi sbx run --clone --name "pi-sbx-${PWD##*/}-$id" "$HOME/Devs/dotfiles/pi-sbx" . "$@"
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
