#!/usr/bin/env bash
set -euo pipefail

# Reloading the config must replace the old aliases, too.
shopt -s expand_aliases
alias sbpi='echo old sbpi alias'
alias sbbash='echo old sbbash alias'
alias sbstop='echo old sbstop alias'
source "$(dirname "$0")/../bash/sandbox.sh"

sbx() {
  printf '%s\n' "$@"
  return "${SBX_STATUS:-0}"
}
unset SBX_STATUS

# All shortcuts use the current workspace and preserve argument boundaries.
export HERDR_WORKSPACE_ID=w12
export HOME='/test/home with spaces'
name="pi-sbx-${PWD##*/}-w12"
[[ $(sbpi) == "$(printf '%s\n' run --clone --name "$name" "$HOME/Devs/dotfiles/pi-sbx" .)" ]]
[[ $(sbbash) == "$(printf '%s\n' exec -it -w "$PWD" "$name" bash)" ]]
[[ $(sbstop) == "$(printf '%s\n' stop "$name")" ]]

# An explicit ID overrides the workspace; remaining arguments are forwarded.
name="pi-sbx-${PWD##*/}-manual"
[[ $(sbpi manual -- --continue 'argument with spaces') == "$(printf '%s\n' run --clone --name "$name" "$HOME/Devs/dotfiles/pi-sbx" . -- --continue 'argument with spaces')" ]]
[[ $(sbbash manual -lc 'echo hello') == "$(printf '%s\n' exec -it -w "$PWD" "$name" bash -lc 'echo hello')" ]]
[[ $(sbstop manual --json) == "$(printf '%s\n' stop "$name" --json)" ]]

# Outside herdr, an unset or empty workspace requires an explicit ID.
for state in unset empty; do
  if [[ $state == unset ]]; then
    unset HERDR_WORKSPACE_ID
  else
    HERDR_WORKSPACE_ID=''
  fi
  for cmd in sbpi sbbash sbstop; do
    if output=$("$cmd" 2>&1); then
      echo "$cmd unexpectedly succeeded without an ID" >&2
      exit 1
    fi
    [[ $output == *"Usage: $cmd"* ]]
    [[ $output == *HERDR_WORKSPACE_ID* ]]
  done
  [[ $(sbpi manual) == "$(printf '%s\n' run --clone --name "$name" "$HOME/Devs/dotfiles/pi-sbx" .)" ]]
  [[ $(sbbash manual) == "$(printf '%s\n' exec -it -w "$PWD" "$name" bash)" ]]
  [[ $(sbstop manual) == "$(printf '%s\n' stop "$name")" ]]
done

# Sandbox failures must reach the caller.
export HERDR_WORKSPACE_ID=w12 SBX_STATUS=23
for cmd in sbpi sbbash sbstop; do
  status=0
  "$cmd" >/dev/null || status=$?
  [[ $status == 23 ]]
done

printf 'sbpi/sbbash/sbstop checks passed\n'
