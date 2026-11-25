#!/usr/bin/env bash
set -euo pipefail

# Reloading the config must replace the old aliases, too.
shopt -s expand_aliases
alias sbpi='echo old sbpi alias'
alias sbbash='echo old sbbash alias'
alias sbstop='echo old sbstop alias'
source "$(dirname "$0")/../bash/sandbox.sh"

gh() {
  [[ $* == 'auth token' ]] || return 98
  [[ ${GH_STATUS:-0} == 0 ]] || return "$GH_STATUS"
  if [[ ${GH_EMPTY:-0} == 0 ]]; then
    printf '%s\n' 'test-github-token'
  fi
}

sbx() {
  if [[ $1 == run ]]; then
    [[ ${HERDR_AGENT:-} == pi ]] || return 99
    [[ ${GITHUB_SECRET_SANDBOX:-} == "$4" ]] || return 98
  else
    [[ ${HERDR_AGENT:-} != pi ]] || return 99
  fi
  if [[ $1 == secret ]]; then
    [[ $(printf '%s\n' "$@") == "$(printf '%s\n' secret set-custom --sandbox "$4" --host api.github.com --host github.com --env GH_TOKEN --placeholder sbx-gh-token-proxy-managed --command 'gh auth token')" ]] || return 98
    [[ ${SBX_SECRET_STATUS:-0} == 0 ]] || return "$SBX_SECRET_STATUS"
    local token
    token=$(gh auth token) || return
    [[ $token == test-github-token ]] || return 1
    GITHUB_SECRET_SANDBOX=$4
    printf '%s\n' 'sbx-gh-token-proxy-managed'
    return 0
  fi
  printf '%s\n' "$@"
  return "${SBX_STATUS:-0}"
}
unset SBX_STATUS SBX_SECRET_STATUS HERDR_AGENT GITHUB_SECRET_SANDBOX GH_STATUS GH_EMPTY

# All shortcuts use the current workspace and preserve argument boundaries.
export HERDR_WORKSPACE_ID=w12
export HOME='/test/home with spaces'
name="pi-sbx-${PWD##*/}-w12"
[[ $(sbpi) == "$(printf '%s\n' run --clone --name "$name" --env GH_TOKEN=sbx-gh-token-proxy-managed "$HOME/Devs/dotfiles/pi-sbx" .)" ]]
[[ $(sbbash) == "$(printf '%s\n' exec -it -w "$PWD" "$name" bash)" ]]
[[ $(sbstop) == "$(printf '%s\n' stop "$name")" ]]

# An explicit ID overrides the workspace; remaining arguments are forwarded.
name="pi-sbx-${PWD##*/}-manual"
[[ $(sbpi manual -- --continue 'argument with spaces') == "$(printf '%s\n' run --clone --name "$name" --env GH_TOKEN=sbx-gh-token-proxy-managed "$HOME/Devs/dotfiles/pi-sbx" . -- --continue 'argument with spaces')" ]]
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
  [[ $(sbpi manual) == "$(printf '%s\n' run --clone --name "$name" --env GH_TOKEN=sbx-gh-token-proxy-managed "$HOME/Devs/dotfiles/pi-sbx" .)" ]]
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

# Failed or empty token resolution and secret storage must prevent sbx run.
unset SBX_STATUS
for failure in command empty storage; do
  unset GH_STATUS GH_EMPTY SBX_SECRET_STATUS GITHUB_SECRET_SANDBOX
  case $failure in
    command) export GH_STATUS=17; expected=17 ;;
    empty) export GH_EMPTY=1; expected=1 ;;
    storage) export SBX_SECRET_STATUS=19; expected=19 ;;
  esac
  status=0
  output=$(sbpi 2>&1) || status=$?
  [[ $status == "$expected" ]]
  [[ -z $output ]]
done
unset GH_STATUS GH_EMPTY SBX_SECRET_STATUS

# The agent hint is scoped to sbx run, not the caller or sandbox-shell shortcuts.
[[ -z ${HERDR_AGENT+x} ]]
unset SBX_STATUS
export HERDR_AGENT=caller GH_TOKEN=caller-token
sbpi >/dev/null
[[ $HERDR_AGENT == caller ]]
[[ $GH_TOKEN == caller-token ]]
sbbash >/dev/null
sbstop >/dev/null

printf 'sbpi/sbbash/sbstop checks passed\n'
