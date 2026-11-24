#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/pi-sbx/setup-dotfiles.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/pi-sbx.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home with spaces"
unset XDG_CONFIG_HOME
export GIT_CONFIG_GLOBAL="$tmp/gitconfig" GIT_CONFIG_NOSYSTEM=1
export PI_ARGS="$tmp/pi-args"
mkdir -p "$HOME" "$tmp/bin" "$tmp/remote/pi" "$tmp/remote/bash" "$tmp/remote/nvim" "$tmp/remote/git"
cp "$root/setup" "$tmp/remote/setup"
cp "$root/bash/base.sh" "$tmp/remote/bash/base.sh"
cp "$root/nvim/init.lua" "$root/nvim/lazy-lock.json" "$tmp/remote/nvim/"
cp "$root/git/config" "$root/git/ignore" "$root/git/_tigrc" "$tmp/remote/git/"
# Model the image COPY and stub its Linux-only persistent environment on the host.
cp "$root/pi-sbx/bashrc.sh" "$HOME/.bashrc"
source() {
  if [[ $1 == /etc/sandbox-persistent.sh ]]; then
    export SANDBOX_PERSISTENT_LOADED=1
  else
    builtin source "$@"
  fi
}
export -f source

# Use a local remote and a fake Pi; no network or sandbox is needed.
git config --global url."file://$tmp/remote".insteadOf https://github.com/IzumiSy/dotfiles.git

# Model a generated Git config with an explicit legacy ignore default.
git config --file "$HOME/.gitconfig" safe.directory "$tmp/workspace"
git config --file "$HOME/.gitconfig" core.checkstat minimal
git config --file "$HOME/.gitconfig" core.excludesfile "$HOME/.gitignore_global"
git config --file "$tmp/extra.gitconfig" test.marker retained
git config --file "$HOME/.gitconfig" include.path "$tmp/extra.gitconfig"
cp "$HOME/.gitconfig" "$tmp/expected.gitconfig"
git config --file "$tmp/expected.gitconfig" core.excludesfile "$HOME/.config/git/ignore"

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
[[ $(readlink "$HOME/.config/nvim") == "$HOME/dotfiles/nvim" ]]
cmp "$root/nvim/init.lua" "$HOME/.config/nvim/init.lua"
cmp "$root/nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
[[ ! -e $HOME/.pi/agent/sandbox.json && ! -L $HOME/.pi/agent/sandbox.json ]]
[[ -f $HOME/.gitconfig && ! -L $HOME/.gitconfig ]]
[[ $(readlink "$HOME/.config/git/config") == "$HOME/dotfiles/git/config" ]]
cmp "$tmp/expected.gitconfig" "$HOME/.gitconfig"
[[ $(readlink "$HOME/.config/git/ignore") == "$HOME/dotfiles/git/ignore" ]]
[[ ! -e $HOME/.gitignore_global && ! -L $HOME/.gitignore_global ]]
[[ $(readlink "$HOME/.tigrc") == "$HOME/dotfiles/git/_tigrc" ]]
[[ $(git config --file "$HOME/.gitconfig" --get safe.directory) == "$tmp/workspace" ]]
[[ $(git config --file "$HOME/.gitconfig" --get core.checkstat) == minimal ]]
[[ $(git config --file "$HOME/.gitconfig" --get-all include.path) == "$tmp/extra.gitconfig" ]]
[[ $(env -u GIT_CONFIG_GLOBAL git -C "$HOME" config --get test.marker) == retained ]]
[[ $(env -u GIT_CONFIG_GLOBAL git -C "$HOME" config --get core.pager) == delta ]]
[[ $(env -u GIT_CONFIG_GLOBAL git -C "$HOME" config --get core.excludesfile) == "$HOME/.config/git/ignore" ]]
env -u GIT_CONFIG_GLOBAL git -C "$HOME/dotfiles" check-ignore -q .pnpm-store/test

# Repository-specific ignore settings still override the global default.
printf 'repo-only.tmp\n' > "$tmp/repo-ignore"
git -C "$HOME/dotfiles" config core.excludesfile "$tmp/repo-ignore"
env -u GIT_CONFIG_GLOBAL git -C "$HOME/dotfiles" check-ignore -q repo-only.tmp
git -C "$HOME/dotfiles" config --unset core.excludesfile
cmp "$root/git/config" "$HOME/dotfiles/git/config"
[[ $(< "$PI_ARGS") == $'--continue\nargument with spaces' ]]
cmp "$root/pi-sbx/bashrc.sh" "$HOME/.bashrc"
bash --noprofile --rcfile "$HOME/.bashrc" -ic '
  set -eu
  [[ $SANDBOX_PERSISTENT_LOADED == 1 ]]
  [[ $BASH_ENV == /etc/sandbox-persistent.sh ]]
  [[ :$SHELLOPTS: == *:ignoreeof:* ]]
  [[ $HISTCONTROL == ignoreboth:erasedups ]]
  [[ $(alias ls) == *"ls --color=auto"* ]]
  [[ $(alias gs) == *"git status --short"* ]]
  declare -F gd >/dev/null
  [[ $PS1 == *"\h"* && $PS1 == *"\w"* ]]
' </dev/null 2>/dev/null

# Reusing the sandbox updates shared settings without rewriting the image's Bash config.
printf 'second\n' > "$tmp/remote/pi/AGENTS.md"
printf '\nalias shared_updated="echo second"\n' >> "$tmp/remote/bash/base.sh"
printf '\n-- Updated Neovim config\n' >> "$tmp/remote/nvim/init.lua"
git -C "$tmp/remote" commit -qam second
status=0
PI_EXIT=23 bash "$script" || status=$?
[[ $status == 23 ]]
[[ $(git -C "$HOME/dotfiles" rev-parse HEAD) == "$(git -C "$tmp/remote" rev-parse master)" ]]
[[ $(< "$HOME/.pi/agent/AGENTS.md") == second ]]
[[ $(readlink "$HOME/.config/nvim") == "$HOME/dotfiles/nvim" ]]
[[ $(< "$HOME/.config/nvim/init.lua") == *'-- Updated Neovim config' ]]
cmp "$tmp/expected.gitconfig" "$HOME/.gitconfig"
cmp "$root/git/config" "$HOME/dotfiles/git/config"
cmp "$root/pi-sbx/bashrc.sh" "$HOME/.bashrc"
bash --noprofile --rcfile "$HOME/.bashrc" -ic 'alias shared_updated >/dev/null' </dev/null 2>/dev/null

# A legacy managed link is left untouched, without editing its source.
mv "$HOME/.gitconfig" "$tmp/generated.gitconfig"
ln -s dotfiles/git/config "$HOME/.gitconfig"
bash "$script"
[[ $(readlink "$HOME/.gitconfig") == dotfiles/git/config ]]
cmp "$root/git/config" "$HOME/dotfiles/git/config"
rm "$HOME/.gitconfig"

# XDG settings also work without creating a legacy global config.
bash "$script"
[[ ! -e $HOME/.gitconfig && ! -L $HOME/.gitconfig ]]
[[ $(env -u GIT_CONFIG_GLOBAL git -C "$HOME" config --get core.pager) == delta ]]
env -u GIT_CONFIG_GLOBAL git -C "$HOME/dotfiles" check-ignore -q .pnpm-store/test
mv "$tmp/generated.gitconfig" "$HOME/.gitconfig"

# The shared setup preserves existing regular files.
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

# An existing Neovim directory must not be overwritten or receive a nested symlink.
rm "$HOME/.config/nvim" "$PI_ARGS"
mkdir "$HOME/.config/nvim"
printf 'local Neovim config\n' > "$HOME/.config/nvim/init.lua"
if bash "$script"; then
  echo 'setup unexpectedly accepted an existing Neovim config directory' >&2
  exit 1
fi
[[ $(< "$HOME/.config/nvim/init.lua") == 'local Neovim config' ]]
[[ ! -e $HOME/.config/nvim/nvim && ! -L $HOME/.config/nvim/nvim ]]
[[ ! -e $PI_ARGS ]]
rm "$HOME/.config/nvim/init.lua"
rmdir "$HOME/.config/nvim"

# An existing config symlink is replaced without modifying its old target.
mkdir "$tmp/other-nvim"
printf 'old config\n' > "$tmp/other-nvim/init.lua"
ln -s "$tmp/other-nvim" "$HOME/.config/nvim"
bash "$script"
[[ $(readlink "$HOME/.config/nvim") == "$HOME/dotfiles/nvim" ]]
[[ $(< "$tmp/other-nvim/init.lua") == 'old config' ]]
[[ ! -e $tmp/other-nvim/nvim ]]
[[ -e $PI_ARGS ]]

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
