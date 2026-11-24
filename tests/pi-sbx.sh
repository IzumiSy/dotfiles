#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/pi-sbx/setup-dotfiles.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/pi-sbx.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home with spaces"
export GIT_CONFIG_GLOBAL="$tmp/gitconfig" GIT_CONFIG_NOSYSTEM=1
export PI_ARGS="$tmp/pi-args"
mkdir -p "$HOME" "$tmp/bin" "$tmp/remote/pi" "$tmp/remote/bash"
cp "$root/bash/common.sh" "$tmp/remote/bash/common.sh"
printf 'export SANDBOX_BASHRC_KEPT=1\n' > "$HOME/.bashrc"
bashrc_source='source "$HOME/dotfiles/bash/common.sh"'

# Use a local remote and a fake Pi; no network or sandbox is needed.
git config --global url."file://$tmp/remote".insteadOf https://github.com/IzumiSy/dotfiles.git
git init -q "$tmp/remote"
git -C "$tmp/remote" symbolic-ref HEAD refs/heads/master
git -C "$tmp/remote" config user.name Test
git -C "$tmp/remote" config user.email test@example.invalid
git -C "$tmp/remote" config commit.gpgsign false
printf 'first\n' > "$tmp/remote/pi/AGENTS.md"
printf '{}\n' > "$tmp/remote/pi/settings.json"
git -C "$tmp/remote" add .
git -C "$tmp/remote" commit -qm first

cat > "$tmp/bin/pi" <<'SH'
#!/bin/sh
printf '%s\n' "$@" > "$PI_ARGS"
exit "${PI_EXIT:-0}"
SH
chmod +x "$tmp/bin/pi"
export PATH="$tmp/bin:$PATH"

# First launch clones master, links the config, and preserves Pi arguments.
bash "$script" --continue 'argument with spaces'
[[ $(git -C "$HOME/dotfiles" rev-parse HEAD) == "$(git -C "$tmp/remote" rev-parse master)" ]]
[[ $(readlink "$HOME/.pi/agent/AGENTS.md") == "$HOME/dotfiles/pi/AGENTS.md" ]]
[[ $(readlink "$HOME/.pi/agent/settings.json") == "$HOME/dotfiles/pi/settings.json" ]]
[[ $(< "$PI_ARGS") == $'--continue\nargument with spaces' ]]
[[ $(grep -cxF "$bashrc_source" "$HOME/.bashrc") == 1 ]]
bash --noprofile --rcfile "$HOME/.bashrc" -ic '
  set -eu
  [[ $SANDBOX_BASHRC_KEPT == 1 ]]
  [[ $(alias gs) == *"git status --short"* ]]
  declare -F gd >/dev/null
  [[ $PS1 == *"\h"* && $PS1 == *"\w"* ]]
' 2>/dev/null

# Reusing the sandbox updates shared settings without duplicating the Bash source line.
printf 'second\n' > "$tmp/remote/pi/AGENTS.md"
printf '\nalias shared_updated="echo second"\n' >> "$tmp/remote/bash/common.sh"
git -C "$tmp/remote" commit -qam second
status=0
PI_EXIT=23 bash "$script" || status=$?
[[ $status == 23 ]]
[[ $(git -C "$HOME/dotfiles" rev-parse HEAD) == "$(git -C "$tmp/remote" rev-parse master)" ]]
[[ $(< "$HOME/.pi/agent/AGENTS.md") == second ]]
[[ $(grep -cxF "$bashrc_source" "$HOME/.bashrc") == 1 ]]
bash --noprofile --rcfile "$HOME/.bashrc" -ic 'alias shared_updated >/dev/null' 2>/dev/null

# An unexpected config file must not be overwritten when linking.
rm "$HOME/.pi/agent/settings.json" "$PI_ARGS"
printf 'local config\n' > "$HOME/.pi/agent/settings.json"
if bash "$script"; then
  echo 'setup unexpectedly replaced an existing config file' >&2
  exit 1
fi
[[ $(< "$HOME/.pi/agent/settings.json") == 'local config' ]]
[[ ! -e $PI_ARGS ]]
rm "$HOME/.pi/agent/settings.json"
bash "$script"

# Conflicting local edits are not discarded, and Pi must not launch.
printf 'local edit\n' > "$HOME/dotfiles/pi/AGENTS.md"
printf 'third\n' > "$tmp/remote/pi/AGENTS.md"
git -C "$tmp/remote" commit -qam third
rm "$PI_ARGS"
if bash "$script"; then
  echo 'setup unexpectedly overwrote local edits' >&2
  exit 1
fi
[[ $(< "$HOME/dotfiles/pi/AGENTS.md") == 'local edit' ]]
[[ ! -e $PI_ARGS ]]

# Fetch errors must not silently launch Pi with stale config.
mv "$tmp/remote" "$tmp/offline"
if bash "$script"; then
  echo 'setup unexpectedly succeeded with an unavailable remote' >&2
  exit 1
fi
[[ ! -e $PI_ARGS ]]

printf 'pi-sbx checks passed\n'
