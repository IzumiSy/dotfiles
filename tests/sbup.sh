#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../bash/sandbox.sh"
expected_run() {
  printf '%s\n' run --clone --name "$name" "$HOME/Devs/dotfiles/sbx" . "$@" \
    --kit-arg "copilot_host=${EXPECTED_COPILOT_HOST:-api.business.githubcopilot.com}" \
    --env "PI_COPILOT_BASE_URL=https://${EXPECTED_COPILOT_HOST:-api.business.githubcopilot.com}" -- -c :
}
expected_up() {
  expected_run "$@"
  printf '%s\n' exec -it -w "$PWD" "$name" bash
}

# Use an external Pi so type -P resolves an absolute path with spaces.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sbup.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin with spaces"
export PI_STUB="$tmp/bin with spaces/pi"
cat > "$PI_STUB" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ $(printf '%s\n' "$@") == "$(printf '%s\n' auth print-bearer-token --provider github-copilot --min-expiry 5m)" ]] || exit 98
[[ ${PI_CODING_AGENT_DIR:-} == "${EXPECTED_PI_DIR:-$HOME/.pi/agent}" ]] || exit 98
[[ ${PI_STATUS:-0} == 0 ]] || exit "$PI_STATUS"
printf '%s\n' "${PI_TOKEN-tid=test;exp=9999999999;proxy-ep=proxy.business.githubcopilot.com;test-secret}"
SH
chmod +x "$PI_STUB"
export PATH="$tmp/bin with spaces:$PATH"

gh() {
  [[ $* == 'auth token' ]] || return 98
  [[ ${GH_STATUS:-0} == 0 ]] || return "$GH_STATUS"
  if [[ ${GH_EMPTY:-0} == 0 ]]; then
    printf '%s\n' 'test-github-token'
  fi
}

herdr() {
  printf '%s\n' "$@" >> "$tmp/herdr-calls"
  [[ $# == 4 && $1 == workspace && $2 == rename && $3 == "${HERDR_WORKSPACE_ID:-}" ]] || return 98
  printf 'rename output\n'
  printf 'rename error\n' >&2
  return "${HERDR_TEST_STATUS:-0}"
}

sbx() {
  if [[ $1 == run ]]; then
    if [[ -n ${HERDR_TEST_LOG:-} ]]; then
      printf 'sbx run\n' >> "$HERDR_TEST_LOG"
    fi
    [[ ${HERDR_AGENT:-} == pi ]] || return 99
    [[ ${GITHUB_SECRET_SANDBOX:-} == "$4" ]] || return 98
    [[ ${COPILOT_SECRET_SANDBOX:-} == "$4" ]] || return 98
  elif [[ $1 == exec && ${HERDR_AGENT:-} == pi ]]; then
    [[ ${GITHUB_SECRET_SANDBOX:-} == "$5" && ${COPILOT_SECRET_SANDBOX:-} == "$5" ]] || return 98
    if [[ -n ${HERDR_TEST_LOG:-} ]]; then printf 'sbx exec\n' >> "$HERDR_TEST_LOG"; fi
    if [[ -n ${SBX_EXEC_LOG:-} ]]; then printf '%s\n' "$@" >> "$SBX_EXEC_LOG"; fi
  else
    [[ ${HERDR_AGENT:-} != pi ]] || return 99
  fi
  if [[ $1 == secret ]]; then
    if [[ -n ${SBX_SECRET_LOG:-} ]]; then
      printf 'secret\n' >> "$SBX_SECRET_LOG"
    fi
    local token
    if [[ ${3:-} == pi-copilot ]]; then
      local expected_command
      printf -v expected_command 'env HOME=%q PATH=%q PI_CODING_AGENT_DIR=%q %q auth print-bearer-token --provider github-copilot --min-expiry 5m' \
        "$HOME" "$PATH" "${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}" "$PI_STUB"
      [[ $(printf '%s\n' "$@") == "$(printf '%s\n' secret set pi-copilot --sandbox "$5" --force --command "$expected_command" --refresh 1m)" ]] || return 98
      [[ $expected_command != *test-secret* && $expected_command != *test-github-token* ]] || return 98
      [[ ${SBX_COPILOT_STATUS:-0} == 0 ]] || return "$SBX_COPILOT_STATUS"
      token=$(eval "$expected_command") || return
      [[ -n $token ]] || return 1
      COPILOT_SECRET_SANDBOX=$5
      printf '%s\n' 'Saved command secret pi-copilot'
    else
      [[ $(printf '%s\n' "$@") == "$(printf '%s\n' secret set github --sandbox "$5" --force --command 'gh auth token' --refresh on-demand)" ]] || return 98
      [[ ${SBX_SECRET_STATUS:-0} == 0 ]] || return "$SBX_SECRET_STATUS"
      token=$(gh auth token) || return
      [[ $token == test-github-token ]] || return 1
      GITHUB_SECRET_SANDBOX=$5
      printf '%s\n' 'Saved command secret github'
    fi
    return 0
  fi
  printf '%s\n' "$@"
  if [[ $1 == exec ]]; then return "${SBX_EXEC_STATUS:-${SBX_STATUS:-0}}"; fi
  return "${SBX_STATUS:-0}"
}
unset SBX_EXEC_STATUS SBX_EXEC_LOG
unset SBX_STATUS SBX_SECRET_STATUS SBX_COPILOT_STATUS HERDR_AGENT GITHUB_SECRET_SANDBOX COPILOT_SECRET_SANDBOX GH_STATUS GH_EMPTY
unset PI_STATUS PI_TOKEN PI_CODING_AGENT_DIR EXPECTED_PI_DIR EXPECTED_COPILOT_HOST SBX_SECRET_LOG
unset HERDR_ENV HERDR_PANE_ID HERDR_TEST_STATUS HERDR_TEST_LOG

# All shortcuts use the current workspace and preserve argument boundaries.
export HERDR_WORKSPACE_ID=w12
export HOME='/test/home with spaces'
name="sbx-${PWD##*/}-w12"
[[ $(sbup) == "$(expected_up)" ]]
[[ $(sbbash) == "$(printf '%s\n' exec -it -w "$PWD" "$name" bash)" ]]
[[ $(sbdown) == "$(printf '%s\n' stop "$name")" ]]
[[ $(sbstatus) == "$(printf '%s\n' inspect "$name")" ]]

# An explicit ID overrides the workspace; remaining arguments are forwarded.
name="sbx-${PWD##*/}-manual"
[[ $(sbup manual --publish 3000:3000 --env 'EXAMPLE=argument with spaces') == "$(expected_up --publish 3000:3000 --env 'EXAMPLE=argument with spaces')" ]]
[[ $(sbup manual -- -c 'echo hello') == "$(expected_up; printf '%s\n' -c 'echo hello')" ]]
[[ $(sbup manual --publish 3000:3000 -- -c 'argument with spaces') == "$(expected_up --publish 3000:3000; printf '%s\n' -c 'argument with spaces')" ]]
# Managed endpoint flags come last so forwarded overrides cannot desynchronize them.
[[ $(sbup manual --kit-arg copilot_host=api.individual.githubcopilot.com --env PI_COPILOT_BASE_URL=https://wrong.invalid) == "$(expected_up --kit-arg copilot_host=api.individual.githubcopilot.com --env PI_COPILOT_BASE_URL=https://wrong.invalid)" ]]
[[ $(sbbash manual -lc 'echo hello') == "$(printf '%s\n' exec -it -w "$PWD" "$name" bash -lc 'echo hello')" ]]
[[ $(sbdown manual --json) == "$(printf '%s\n' stop "$name" --json)" ]]
[[ $(sbstatus manual --format json) == "$(printf '%s\n' inspect "$name" --format json)" ]]

# Outside herdr, an unset or empty workspace requires an explicit ID.
for state in unset empty; do
  if [[ $state == unset ]]; then
    unset HERDR_WORKSPACE_ID
  else
    HERDR_WORKSPACE_ID=''
  fi
  for cmd in sbup sbbash sbdown sbstatus; do
    if output=$("$cmd" 2>&1); then
      echo "$cmd unexpectedly succeeded without an ID" >&2
      exit 1
    fi
    [[ $output == *"Usage: $cmd"* ]]
    [[ $output == *HERDR_WORKSPACE_ID* ]]
  done
  [[ $(sbup manual) == "$(expected_up)" ]]
  [[ $(sbbash manual) == "$(printf '%s\n' exec -it -w "$PWD" "$name" bash)" ]]
  [[ $(sbdown manual) == "$(printf '%s\n' stop "$name")" ]]
  [[ $(sbstatus manual) == "$(printf '%s\n' inspect "$name")" ]]
done

# Sandbox failures must reach the caller.
export HERDR_WORKSPACE_ID=w12 SBX_STATUS=23
for cmd in sbup sbbash sbdown sbstatus; do
  status=0
  "$cmd" >/dev/null || status=$?
  [[ $status == 23 ]]
done

# Lifecycle flags cannot skip initialization or remove the sandbox before shell entry.
unset SBX_STATUS
export SBX_SECRET_LOG="$tmp/secret-calls"
for flag in -d --detach --detach=true --rm --rm=true; do
  : > "$SBX_SECRET_LOG"
  status=0
  output=$(sbup manual "$flag" 2>&1) || status=$?
  [[ $status == 1 && $output == *'use sbx directly'* && ! -s $SBX_SECRET_LOG ]]
done
unset SBX_SECRET_LOG

# Failed initialization still opens a debug shell; its status reaches the caller.
export SBX_EXEC_LOG="$tmp/shell-calls"
for run_status in 0 3 23 125; do
  for shell_status in 0 47 125; do
    : > "$SBX_EXEC_LOG"
    status=0
    output=$(SBX_STATUS=$run_status SBX_EXEC_STATUS=$shell_status sbup 2>&1) || status=$?
    [[ $status == "$shell_status" ]]
    [[ $(< "$SBX_EXEC_LOG") == "$(printf '%s\n' exec -it -w "$PWD" "sbx-${PWD##*/}-w12" bash)" ]]
    if [[ $run_status == 0 ]]; then
      [[ $output != *'initialization failed'* ]]
    else
      [[ $output == *"Sandbox initialization failed (exit $run_status); opening Bash for debugging."* ]]
    fi
  done
done

# Interrupts cancel sbup rather than opening another session.
for run_status in 130 143; do
  : > "$SBX_EXEC_LOG"
  status=0
  SBX_STATUS=$run_status sbup >/dev/null || status=$?
  [[ $status == "$run_status" && ! -s $SBX_EXEC_LOG ]]
done
unset SBX_EXEC_LOG

# Failed or empty token resolution and secret storage must prevent sbx run.
for failure in command empty storage; do
  unset GH_STATUS GH_EMPTY SBX_SECRET_STATUS GITHUB_SECRET_SANDBOX COPILOT_SECRET_SANDBOX
  case $failure in
    command) export GH_STATUS=17; expected=17 ;;
    empty) export GH_EMPTY=1; expected=1 ;;
    storage) export SBX_SECRET_STATUS=19; expected=19 ;;
  esac
  status=0
  output=$(sbup 2>&1) || status=$?
  [[ $status == "$expected" ]]
  [[ -z $output ]]
done
unset GH_STATUS GH_EMPTY SBX_SECRET_STATUS

# The Copilot API host follows the token, not an assumed Individual endpoint.
for endpoint in individual base; do
  if [[ $endpoint == individual ]]; then
    export PI_TOKEN='tid=test;proxy-ep=proxy.individual.githubcopilot.com;test-secret'
    export EXPECTED_COPILOT_HOST=api.individual.githubcopilot.com
  else
    export PI_TOKEN='proxy-ep=proxy.githubcopilot.com'
    export EXPECTED_COPILOT_HOST=api.githubcopilot.com
  fi
  name="sbx-${PWD##*/}-w12"
  [[ $(sbup) == "$(expected_up)" ]]
done
unset PI_TOKEN EXPECTED_COPILOT_HOST

# The host auth directory is pinned in both initial and replayed commands.
export PI_CODING_AGENT_DIR='/host/pi config with spaces' EXPECTED_PI_DIR='/host/pi config with spaces'
sbup >/dev/null
[[ $PI_CODING_AGENT_DIR == '/host/pi config with spaces' ]]
unset PI_CODING_AGENT_DIR EXPECTED_PI_DIR

# Failed token export or Copilot secret storage must stop launch with the same status.
for failure in token storage; do
  unset PI_STATUS SBX_COPILOT_STATUS GITHUB_SECRET_SANDBOX COPILOT_SECRET_SANDBOX
  case $failure in
    token) export PI_STATUS=29; expected=29 ;;
    storage) export SBX_COPILOT_STATUS=31; expected=31 ;;
  esac
  status=0
  output=$(sbup 2>&1) || status=$?
  [[ $status == "$expected" ]]
  if [[ $failure == token ]]; then
    [[ $output == *'check the host Pi login'* ]]
  else
    [[ -z $output ]]
  fi
done
unset PI_STATUS SBX_COPILOT_STATUS

# Empty, malformed, or untrusted endpoints must not register a secret or leak a token.
export SBX_SECRET_LOG="$tmp/secret-calls"
for token in '' 'test-secret' \
  'proxy-ep=proxy.business.githubcopilot.com.attacker.invalid;test-secret' \
  'proxy-ep=proxy.attacker.invalid;test-secret' \
  'proxy-ep=proxy.business.githubcopilot.com/path;test-secret'; do
  export PI_TOKEN="$token"
  : > "$SBX_SECRET_LOG"
  status=0
  output=$(sbup 2>&1) || status=$?
  [[ $status != 0 ]]
  [[ ! -s $SBX_SECRET_LOG ]]
  [[ $output != *test-secret* && $output != *$'run\n'* ]]
done
unset PI_TOKEN SBX_SECRET_LOG

# Even shell tracing must not reveal the exported host token.
export PI_TOKEN='proxy-ep=proxy.business.githubcopilot.com;trace-hidden-secret'
status=0
output=$( { set -x; SBX_SECRET_STATUS=19 sbup; } 2>&1) || status=$?
[[ $status == 19 && $output != *trace-hidden-secret* ]]
unset PI_TOKEN

# A missing external Pi or relative auth directory cannot become a replay command.
status=0
output=$(PATH="$tmp/no-pi" sbup 2>&1) || status=$?
[[ $status != 0 ]]
[[ $output != *$'run\n'* ]]
status=0
output=$(PI_CODING_AGENT_DIR=relative/pi sbup 2>&1) || status=$?
[[ $status != 0 ]]
[[ $output != *$'run\n'* ]]

# The hint covers sbup's initialization and shell, not the caller or direct shortcuts.
[[ -z ${HERDR_AGENT+x} ]]
unset SBX_STATUS
export HERDR_AGENT=caller GH_TOKEN=caller-token COPILOT_GITHUB_TOKEN=caller-copilot-token PI_COPILOT_BASE_URL=caller-base-url
sbup >/dev/null
[[ $HERDR_AGENT == caller ]]
[[ $GH_TOKEN == caller-token ]]
[[ $COPILOT_GITHUB_TOKEN == caller-copilot-token ]]
[[ $PI_COPILOT_BASE_URL == caller-base-url ]]
sbbash >/dev/null
sbdown >/dev/null
sbstatus >/dev/null

# Rename the calling workspace before run; preserve the name and command status.
export HERDR_ENV=1 HERDR_WORKSPACE_ID=w12 HERDR_TEST_LOG="$tmp/herdr-calls"
unset HERDR_PANE_ID
for id in '' manual; do
  name="sbx-${PWD##*/}-${id:-w12}"
  for run_status in 0 23 130; do
    expected_rename=$(printf '%s\n' workspace rename "$HERDR_WORKSPACE_ID" "$name" 'sbx run')
    expected_output=$(expected_run)
    if [[ $run_status != 130 ]]; then
      expected_rename+=$'\nsbx exec'
      if [[ $run_status != 0 ]]; then
        expected_output+=$'\n'"Sandbox initialization failed (exit $run_status); opening Bash for debugging."
      fi
      expected_output+=$'\n'"$(printf '%s\n' exec -it -w "$PWD" "$name" bash)"
    fi
    for rename_status in 0 37; do
      : > "$HERDR_TEST_LOG"
      status=0
      output=$(HERDR_TEST_STATUS=$rename_status SBX_STATUS=$run_status sbup ${id:+"$id"} 2>&1) || status=$?
      [[ $status == "$run_status" ]]
      [[ $output == "$expected_output" ]]
      [[ $(< "$HERDR_TEST_LOG") == "$expected_rename" ]]
    done
  done
done

# Missing Herdr context skips renaming, even if a stale pane ID is inherited.
for context in unset outside missing-workspace empty-workspace; do
  export HERDR_ENV=1 HERDR_WORKSPACE_ID=w12 HERDR_PANE_ID=w12:p3
  case $context in
    unset) unset HERDR_ENV ;;
    outside) HERDR_ENV=0 ;;
    missing-workspace) unset HERDR_WORKSPACE_ID ;;
    empty-workspace) HERDR_WORKSPACE_ID='' ;;
  esac
  : > "$HERDR_TEST_LOG"
  sbup manual >/dev/null
  [[ $(< "$HERDR_TEST_LOG") == $'sbx run\nsbx exec' ]]
done

# Failed authentication and non-agent shortcuts do not rename the workspace.
export HERDR_ENV=1 HERDR_WORKSPACE_ID=w12 HERDR_PANE_ID=w12:p3
: > "$HERDR_TEST_LOG"
status=0
PI_STATUS=29 sbup >/dev/null 2>&1 || status=$?
[[ $status == 29 && ! -s $HERDR_TEST_LOG ]]
sbbash >/dev/null
sbdown >/dev/null
sbstatus >/dev/null
[[ ! -s $HERDR_TEST_LOG ]]

printf 'sbup/sbbash/sbdown/sbstatus checks passed\n'
