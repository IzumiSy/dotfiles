#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/bash-base.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
shopt -s expand_aliases
source "$root/bash/base.sh" </dev/null

# Mock Git so testing branch protection never performs a real push.
git() {
  case "$1" in
    branch) printf '* %s\n' "$current_branch" ;;
    push) printf '%s\n' "$*" >> "$tmp/pushes" ;;
    *) echo "Unexpected Git command: $*" >&2; return 1 ;;
  esac
}

for current_branch in main master develop; do
  if gpo >/dev/null; then
    echo "gpo unexpectedly allowed a push to $current_branch" >&2
    exit 1
  fi
  if gpof >/dev/null; then
    echo "gpof unexpectedly allowed a push to $current_branch" >&2
    exit 1
  fi
done
[[ ! -e $tmp/pushes ]]

current_branch=feature/test
gpo
gpof
[[ $(< "$tmp/pushes") == $'push -u origin feature/test\npush -u origin feature/test --force-with-lease --force-if-includes' ]]

printf 'Git push safety checks passed\n'
