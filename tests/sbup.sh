#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../bash/sandbox.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sbup.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin with spaces" "$tmp/home with spaces"
export HOME="$tmp/home with spaces" HERDR_WORKSPACE_ID=w12

# Use an external Pi so replay commands must quote absolute paths with spaces.
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
  if [[ ${GH_EMPTY:-0} == 0 ]]; then printf '%s\n' 'test-github-token'; fi
}

sbx() {
  printf '%s\n' "$1" >> "$tmp/calls"
  case "$1" in
    secret)
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
      else
        [[ $(printf '%s\n' "$@") == "$(printf '%s\n' secret set github --sandbox "$5" --force --command 'gh auth token' --refresh on-demand)" ]] || return 98
        [[ ${SBX_SECRET_STATUS:-0} == 0 ]] || return "$SBX_SECRET_STATUS"
        token=$(gh auth token) || return
        [[ $token == test-github-token ]] || return 1
        GITHUB_SECRET_SANDBOX=$5
      fi ;;
    run)
      [[ ${GITHUB_SECRET_SANDBOX:-} == "$4" && ${COPILOT_SECRET_SANDBOX:-} == "$4" ]] || exit 98
      [[ $(printf '%s\n' "${@: -7}") == "$(printf '%s\n' --kit-arg "copilot_host=${EXPECTED_COPILOT_HOST:-api.business.githubcopilot.com}" --env "PI_COPILOT_BASE_URL=https://${EXPECTED_COPILOT_HOST:-api.business.githubcopilot.com}" -- -c :)" ]] || exit 98
      [[ $* != *test-secret* && $* != *test-github-token* ]] || exit 98 ;;
    exec)
      [[ ${GITHUB_SECRET_SANDBOX:-} == "$5" && ${COPILOT_SECRET_SANDBOX:-} == "$5" ]] || return 98 ;;
    *) return 99 ;;
  esac
}
no_launch() { ! grep -Eq '^(run|exec)$' "$tmp/calls"; }

# Managed endpoint flags come last so forwarded overrides cannot desynchronize them.
: > "$tmp/calls"
sb up manual --kit-arg copilot_host=api.individual.githubcopilot.com --env PI_COPILOT_BASE_URL=https://wrong.invalid
[[ $(< "$tmp/calls") == $'secret\nsecret\nrun\nexec' ]]

# Automatic removal must not delete a sandbox before shell entry.
for flag in --rm --rm=true; do
  : > "$tmp/calls"
  status=0
  sb up manual "$flag" >/dev/null 2>&1 || status=$?
  [[ $status != 0 && ! -s $tmp/calls ]]
done

# Failed or empty GitHub authentication and secret storage prevent launch.
for failure in command empty storage; do
  unset GH_STATUS GH_EMPTY SBX_SECRET_STATUS GITHUB_SECRET_SANDBOX COPILOT_SECRET_SANDBOX
  case $failure in
    command) export GH_STATUS=17; expected=17 ;;
    empty) export GH_EMPTY=1; expected=1 ;;
    storage) export SBX_SECRET_STATUS=19; expected=19 ;;
  esac
  : > "$tmp/calls"
  status=0
  output=$(sb up 2>&1) || status=$?
  [[ $status == "$expected" && -z $output ]]
  no_launch
done
unset GH_STATUS GH_EMPTY SBX_SECRET_STATUS

# Trusted token endpoints control both the credential scope and API base URL.
for endpoint in individual base; do
  if [[ $endpoint == individual ]]; then
    export PI_TOKEN='tid=test;proxy-ep=proxy.individual.githubcopilot.com;test-secret'
    export EXPECTED_COPILOT_HOST=api.individual.githubcopilot.com
  else
    export PI_TOKEN='proxy-ep=proxy.githubcopilot.com'
    export EXPECTED_COPILOT_HOST=api.githubcopilot.com
  fi
  sb up
done
unset PI_TOKEN EXPECTED_COPILOT_HOST

# The host auth directory is pinned in both initial and replayed commands.
export PI_CODING_AGENT_DIR='/host/pi config with spaces' EXPECTED_PI_DIR='/host/pi config with spaces'
sb up
[[ $PI_CODING_AGENT_DIR == '/host/pi config with spaces' ]]
unset PI_CODING_AGENT_DIR EXPECTED_PI_DIR

# Failed Copilot authentication or secret storage must stop launch.
for failure in token storage; do
  unset PI_STATUS SBX_COPILOT_STATUS GITHUB_SECRET_SANDBOX COPILOT_SECRET_SANDBOX
  case $failure in
    token) export PI_STATUS=29; expected=29 ;;
    storage) export SBX_COPILOT_STATUS=31; expected=31 ;;
  esac
  : > "$tmp/calls"
  status=0
  output=$(sb up 2>&1) || status=$?
  [[ $status == "$expected" && $output != *test-secret* ]]
  no_launch
  if [[ $failure == token ]]; then [[ ! -s $tmp/calls ]]; fi
done
unset PI_STATUS SBX_COPILOT_STATUS

# Empty, malformed, or untrusted endpoints cannot register secrets or leak tokens.
for token in '' 'test-secret' \
  'proxy-ep=proxy.business.githubcopilot.com.attacker.invalid;test-secret' \
  'proxy-ep=proxy.attacker.invalid;test-secret' \
  'proxy-ep=proxy.business.githubcopilot.com/path;test-secret'; do
  export PI_TOKEN="$token"
  : > "$tmp/calls"
  status=0
  output=$(sb up 2>&1) || status=$?
  [[ $status != 0 && ! -s $tmp/calls && $output != *test-secret* ]]
done
unset PI_TOKEN

# Even shell tracing must not reveal the exported host token.
export PI_TOKEN='proxy-ep=proxy.business.githubcopilot.com;trace-hidden-secret'
: > "$tmp/calls"
status=0
output=$( { set -x; SBX_SECRET_STATUS=19 sb up; } 2>&1) || status=$?
[[ $status == 19 && $output != *trace-hidden-secret* ]]
no_launch
unset PI_TOKEN

# Missing external Pi and relative auth paths cannot become replay commands.
for failure in missing-pi relative-auth; do
  : > "$tmp/calls"
  status=0
  if [[ $failure == missing-pi ]]; then
    output=$(PATH="$tmp/no-pi" sb up 2>&1) || status=$?
  else
    output=$(PI_CODING_AGENT_DIR=relative/pi sb up 2>&1) || status=$?
  fi
  [[ $status != 0 && ! -s $tmp/calls ]]
done

# Launching a sandbox must not overwrite the caller's credentials or endpoint.
export GH_TOKEN=caller-token COPILOT_GITHUB_TOKEN=caller-copilot-token PI_COPILOT_BASE_URL=caller-base-url
sb up
[[ $GH_TOKEN == caller-token && $COPILOT_GITHUB_TOKEN == caller-copilot-token ]]
[[ $PI_COPILOT_BASE_URL == caller-base-url ]]

printf 'sb up authentication safety checks passed\n'
