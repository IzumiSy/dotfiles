#!/usr/bin/env bash
set -euo pipefail

# Reloading the config must replace the old aliases, too.
shopt -s expand_aliases
alias sbpi='echo old sbpi alias'
alias sbbash='echo old sbbash alias'
alias sbstop='echo old sbstop alias'
alias sbstatus='echo old sbstatus alias'
source "$(dirname "$0")/../bash/sandbox.sh"

# Use an external Pi so type -P resolves an absolute path with spaces.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sbpi.XXXXXX")
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
  printf 'metadata output\n'
  printf 'metadata error\n' >&2
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
  else
    [[ ${HERDR_AGENT:-} != pi ]] || return 99
  fi
  if [[ $1 == secret ]]; then
    if [[ -n ${SBX_SECRET_LOG:-} ]]; then
      printf 'secret\n' >> "$SBX_SECRET_LOG"
    fi
    local token
    if [[ ${8:-} == COPILOT_GITHUB_TOKEN ]]; then
      local expected_command
      printf -v expected_command 'env HOME=%q PATH=%q PI_CODING_AGENT_DIR=%q %q auth print-bearer-token --provider github-copilot --min-expiry 5m' \
        "$HOME" "$PATH" "${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}" "$PI_STUB"
      [[ $(printf '%s\n' "$@") == "$(printf '%s\n' secret set-custom --sandbox "$4" --host "${EXPECTED_COPILOT_HOST:-api.business.githubcopilot.com}" --env COPILOT_GITHUB_TOKEN --placeholder sbx-copilot-token-proxy-managed --command "$expected_command" --refresh 1m)" ]] || return 98
      [[ $expected_command != *test-secret* && $expected_command != *test-github-token* ]] || return 98
      [[ ${SBX_COPILOT_STATUS:-0} == 0 ]] || return "$SBX_COPILOT_STATUS"
      token=$(eval "$expected_command") || return
      [[ -n $token ]] || return 1
      COPILOT_SECRET_SANDBOX=$4
      printf '%s\n' 'sbx-copilot-token-proxy-managed'
    else
      [[ $(printf '%s\n' "$@") == "$(printf '%s\n' secret set-custom --sandbox "$4" --host api.github.com --host github.com --env GH_TOKEN --placeholder sbx-gh-token-proxy-managed --command 'gh auth token')" ]] || return 98
      [[ ${SBX_SECRET_STATUS:-0} == 0 ]] || return "$SBX_SECRET_STATUS"
      token=$(gh auth token) || return
      [[ $token == test-github-token ]] || return 1
      GITHUB_SECRET_SANDBOX=$4
      printf '%s\n' 'sbx-gh-token-proxy-managed'
    fi
    return 0
  fi
  printf '%s\n' "$@"
  return "${SBX_STATUS:-0}"
}
unset SBX_STATUS SBX_SECRET_STATUS SBX_COPILOT_STATUS HERDR_AGENT GITHUB_SECRET_SANDBOX COPILOT_SECRET_SANDBOX GH_STATUS GH_EMPTY
unset PI_STATUS PI_TOKEN PI_CODING_AGENT_DIR EXPECTED_PI_DIR EXPECTED_COPILOT_HOST SBX_SECRET_LOG
unset HERDR_ENV HERDR_PANE_ID HERDR_TEST_STATUS HERDR_TEST_LOG

# All shortcuts use the current workspace and preserve argument boundaries.
export HERDR_WORKSPACE_ID=w12
export HOME='/test/home with spaces'
name="pi-sbx-${PWD##*/}-w12"
[[ $(sbpi) == "$(printf '%s\n' run --clone --name "$name" --env GH_TOKEN=sbx-gh-token-proxy-managed --env COPILOT_GITHUB_TOKEN=sbx-copilot-token-proxy-managed --env PI_COPILOT_BASE_URL=https://api.business.githubcopilot.com "$HOME/Devs/dotfiles/pi-sbx" .)" ]]
[[ $(sbbash) == "$(printf '%s\n' exec -it -w "$PWD" "$name" bash)" ]]
[[ $(sbstop) == "$(printf '%s\n' stop "$name")" ]]
[[ $(sbstatus) == "$(printf '%s\n' inspect "$name")" ]]

# An explicit ID overrides the workspace; remaining arguments are forwarded.
name="pi-sbx-${PWD##*/}-manual"
[[ $(sbpi manual -- --continue 'argument with spaces') == "$(printf '%s\n' run --clone --name "$name" --env GH_TOKEN=sbx-gh-token-proxy-managed --env COPILOT_GITHUB_TOKEN=sbx-copilot-token-proxy-managed --env PI_COPILOT_BASE_URL=https://api.business.githubcopilot.com "$HOME/Devs/dotfiles/pi-sbx" . -- --continue 'argument with spaces')" ]]
[[ $(sbbash manual -lc 'echo hello') == "$(printf '%s\n' exec -it -w "$PWD" "$name" bash -lc 'echo hello')" ]]
[[ $(sbstop manual --json) == "$(printf '%s\n' stop "$name" --json)" ]]
[[ $(sbstatus manual --format json) == "$(printf '%s\n' inspect "$name" --format json)" ]]

# Outside herdr, an unset or empty workspace requires an explicit ID.
for state in unset empty; do
  if [[ $state == unset ]]; then
    unset HERDR_WORKSPACE_ID
  else
    HERDR_WORKSPACE_ID=''
  fi
  for cmd in sbpi sbbash sbstop sbstatus; do
    if output=$("$cmd" 2>&1); then
      echo "$cmd unexpectedly succeeded without an ID" >&2
      exit 1
    fi
    [[ $output == *"Usage: $cmd"* ]]
    [[ $output == *HERDR_WORKSPACE_ID* ]]
  done
  [[ $(sbpi manual) == "$(printf '%s\n' run --clone --name "$name" --env GH_TOKEN=sbx-gh-token-proxy-managed --env COPILOT_GITHUB_TOKEN=sbx-copilot-token-proxy-managed --env PI_COPILOT_BASE_URL=https://api.business.githubcopilot.com "$HOME/Devs/dotfiles/pi-sbx" .)" ]]
  [[ $(sbbash manual) == "$(printf '%s\n' exec -it -w "$PWD" "$name" bash)" ]]
  [[ $(sbstop manual) == "$(printf '%s\n' stop "$name")" ]]
  [[ $(sbstatus manual) == "$(printf '%s\n' inspect "$name")" ]]
done

# Sandbox failures must reach the caller.
export HERDR_WORKSPACE_ID=w12 SBX_STATUS=23
for cmd in sbpi sbbash sbstop sbstatus; do
  status=0
  "$cmd" >/dev/null || status=$?
  [[ $status == 23 ]]
done

# Failed or empty token resolution and secret storage must prevent sbx run.
unset SBX_STATUS
for failure in command empty storage; do
  unset GH_STATUS GH_EMPTY SBX_SECRET_STATUS GITHUB_SECRET_SANDBOX COPILOT_SECRET_SANDBOX
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

# The Copilot API host follows the token, not an assumed Individual endpoint.
for endpoint in individual base; do
  if [[ $endpoint == individual ]]; then
    export PI_TOKEN='tid=test;proxy-ep=proxy.individual.githubcopilot.com;test-secret'
    export EXPECTED_COPILOT_HOST=api.individual.githubcopilot.com
  else
    export PI_TOKEN='proxy-ep=proxy.githubcopilot.com'
    export EXPECTED_COPILOT_HOST=api.githubcopilot.com
  fi
  [[ $(sbpi) == "$(printf '%s\n' run --clone --name "pi-sbx-${PWD##*/}-w12" --env GH_TOKEN=sbx-gh-token-proxy-managed --env COPILOT_GITHUB_TOKEN=sbx-copilot-token-proxy-managed --env "PI_COPILOT_BASE_URL=https://$EXPECTED_COPILOT_HOST" "$HOME/Devs/dotfiles/pi-sbx" .)" ]]
done
unset PI_TOKEN EXPECTED_COPILOT_HOST

# The host auth directory is pinned in both initial and replayed commands.
export PI_CODING_AGENT_DIR='/host/pi config with spaces' EXPECTED_PI_DIR='/host/pi config with spaces'
sbpi >/dev/null
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
  output=$(sbpi 2>&1) || status=$?
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
  output=$(sbpi 2>&1) || status=$?
  [[ $status != 0 ]]
  [[ ! -s $SBX_SECRET_LOG ]]
  [[ $output != *test-secret* && $output != *$'run\n'* ]]
done
unset PI_TOKEN SBX_SECRET_LOG

# Even shell tracing must not reveal the exported host token.
export PI_TOKEN='proxy-ep=proxy.business.githubcopilot.com;trace-hidden-secret'
status=0
output=$( { set -x; SBX_SECRET_STATUS=19 sbpi; } 2>&1) || status=$?
[[ $status == 19 && $output != *trace-hidden-secret* ]]
unset PI_TOKEN

# A missing external Pi or relative auth directory cannot become a replay command.
status=0
output=$(PATH="$tmp/no-pi" sbpi 2>&1) || status=$?
[[ $status != 0 ]]
[[ $output != *$'run\n'* ]]
status=0
output=$(PI_CODING_AGENT_DIR=relative/pi sbpi 2>&1) || status=$?
[[ $status != 0 ]]
[[ $output != *$'run\n'* ]]

# The agent hint is scoped to sbx run, not the caller or sandbox-shell shortcuts.
[[ -z ${HERDR_AGENT+x} ]]
unset SBX_STATUS
export HERDR_AGENT=caller GH_TOKEN=caller-token COPILOT_GITHUB_TOKEN=caller-copilot-token PI_COPILOT_BASE_URL=caller-base-url
sbpi >/dev/null
[[ $HERDR_AGENT == caller ]]
[[ $GH_TOKEN == caller-token ]]
[[ $COPILOT_GITHUB_TOKEN == caller-copilot-token ]]
[[ $PI_COPILOT_BASE_URL == caller-base-url ]]
sbbash >/dev/null
sbstop >/dev/null
sbstatus >/dev/null

# Sandbox display metadata surrounds run, without an agent guard or state takeover.
export HERDR_ENV=1 HERDR_PANE_ID=w12:p3 HERDR_TEST_LOG="$tmp/herdr-calls"
for id in '' manual; do
  name="pi-sbx-${PWD##*/}-${id:-w12}"
  expected_metadata=$(printf '%s\n' pane report-metadata "$HERDR_PANE_ID" \
    --source user:sbx --display-agent "$name" 'sbx run' \
    pane report-metadata "$HERDR_PANE_ID" --source user:sbx --clear-display-agent)
  for run_status in 0 23 130; do
    for metadata_status in 0 37; do
      : > "$HERDR_TEST_LOG"
      status=0
      output=$(HERDR_TEST_STATUS=$metadata_status SBX_STATUS=$run_status sbpi ${id:+"$id"} 2>&1) || status=$?
      [[ $status == "$run_status" ]]
      [[ $output == run$'\n'* && $output != *metadata* ]]
      [[ $(< "$HERDR_TEST_LOG") == "$expected_metadata" ]]
    done
  done
done

# Missing Herdr context skips metadata, even if a stale pane ID is inherited.
for context in unset outside missing-pane empty-pane; do
  export HERDR_ENV=1 HERDR_PANE_ID=w12:p3
  case $context in
    unset) unset HERDR_ENV ;;
    outside) HERDR_ENV=0 ;;
    missing-pane) unset HERDR_PANE_ID ;;
    empty-pane) HERDR_PANE_ID='' ;;
  esac
  : > "$HERDR_TEST_LOG"
  sbpi >/dev/null
  [[ $(< "$HERDR_TEST_LOG") == 'sbx run' ]]
done

# Failed authentication and non-agent shortcuts do not touch display metadata.
export HERDR_ENV=1 HERDR_PANE_ID=w12:p3
: > "$HERDR_TEST_LOG"
status=0
PI_STATUS=29 sbpi >/dev/null 2>&1 || status=$?
[[ $status == 29 && ! -s $HERDR_TEST_LOG ]]
sbbash >/dev/null
sbstop >/dev/null
sbstatus >/dev/null
[[ ! -s $HERDR_TEST_LOG ]]

printf 'sbpi/sbbash/sbstop/sbstatus checks passed\n'
