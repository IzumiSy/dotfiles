#!/usr/bin/env bash
set -euo pipefail

eval "$(awk '/^function killport\(\) \{/,/^}/' "$(dirname "$0")/../_bashrc")"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/killport.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
lsof_status=0 kill_status=0

# Mock both commands so no real processes are inspected or stopped.
lsof() {
  printf '%s\n' "$*" >> "$tmp/lsof"
  [[ $# == 2 && $1 == "-tiTCP:$expected_port" && $2 == -sTCP:LISTEN ]] || return 99
  printf '123\n456\n'
  return "$lsof_status"
}

kill() {
  printf '%s\n' "$*" >> "$tmp/kills"
  if [[ $1 == 456 ]]; then
    return "$kill_status"
  fi
}

# Single ports, inclusive ranges, equal endpoints, and leading zeros work.
for expected_port in 1 80 65535 00080 3000-3010 1-65535 80-80 00080-00090; do
  : > "$tmp/kills"
  output=$(killport "$expected_port")
  [[ $output == "Sent SIGTERM to 2 process(es) on port $expected_port." ]]
  [[ $(< "$tmp/kills") == $'123\n456' ]]
done

# Invalid arguments fail before lsof or kill is called.
assert_invalid() {
  : > "$tmp/lsof"
  : > "$tmp/kills"
  if output=$(killport "$@" 2>&1); then
    printf 'Unexpectedly accepted: %s\n' "$*" >&2
    exit 1
  else
    [[ $? == 1 ]]
  fi
  [[ $output == 'Usage: killport <port|start-end: 1-65535>' ]]
  [[ ! -s $tmp/lsof && ! -s $tmp/kills ]]
}

assert_invalid
assert_invalid 80 81
for invalid in '' 0 65536 100000 abc -1 3000- -3010 3010-3000 \
  0-80 80-65536 65536-65536 80-100000 80--90 80-90-100 80,90 '80 - 90' '1+1'; do
  assert_invalid "$invalid"
done

# lsof failures are preserved and do not send any signals.
expected_port=3000-3010
lsof_status=7
: > "$tmp/kills"
if killport "$expected_port"; then
  echo 'Unexpectedly ignored lsof failure' >&2
  exit 1
else
  [[ $? == 7 ]]
fi
[[ ! -s $tmp/kills ]]

# Signal failures are preserved and only successful signals are counted.
lsof_status=0 kill_status=3
if output=$(killport "$expected_port"); then
  echo 'Unexpectedly ignored kill failure' >&2
  exit 1
else
  [[ $? == 3 ]]
fi
[[ $output == "Sent SIGTERM to 1 process(es) on port $expected_port." ]]

printf 'killport checks passed\n'
