#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/bash-common.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
shopt -s expand_aliases
original_path=$PATH
source "$root/bash/common.sh" > "$tmp/startup-output"

# Shared settings are quiet, keep the image PATH, and need no host-only tools.
[[ ! -s $tmp/startup-output ]]
[[ $PATH == "$original_path" ]]
[[ $PS1 == *'\h'* && $PS1 == *'\t'* && $PS1 == *'\w'* ]]
[[ $(alias rm) == "alias rm='rm -i'" ]]
[[ $(alias cp) == "alias cp='cp -i'" ]]
[[ $(alias mv) == "alias mv='mv -i'" ]]
for shortcut in x c ll lla gad gadi gcm gch glo gs gpl gcmb gpo gpof; do
  alias "$shortcut" >/dev/null
done
declare -F gd >/dev/null

mkdir "$tmp/dir with spaces"
touch "$tmp/dir with spaces/visible" "$tmp/dir with spaces/.hidden"
listing=$(ll "$tmp/dir with spaces")
[[ $listing == *visible* && $listing != *'.hidden'* ]]
[[ $(lla "$tmp/dir with spaces") == *'.hidden'* ]]

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

printf 'shared Bash checks passed\n'
