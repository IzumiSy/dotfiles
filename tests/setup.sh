#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/setup.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home with spaces"
export XDG_CONFIG_HOME="$HOME/xdg config"
mkdir -p "$HOME" "$tmp/work"
cd "$tmp/work"

# Only selected entries are linked, even when called outside the repository.
bash "$root/setup" install nvim pi/AGENTS.md pi/settings.json git/config git/ignore >/dev/null
[[ $(readlink "$XDG_CONFIG_HOME/git/config") == "$root/git/config" ]]
[[ $(readlink "$XDG_CONFIG_HOME/git/ignore") == "$root/git/ignore" ]]
[[ ! -e $HOME/.gitconfig && ! -L $HOME/.gitconfig ]]
[[ ! -e $HOME/.gitignore_global && ! -L $HOME/.gitignore_global ]]
! git config --file "$XDG_CONFIG_HOME/git/config" --get core.excludesfile >/dev/null
env -u GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM=1 git init -q "$tmp/work"
env -u GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM=1 git -C "$tmp/work" check-ignore -q .pnpm-store/test
[[ $(readlink "$HOME/.config/nvim") == "$root/nvim" ]]
[[ $(readlink "$HOME/.pi/agent/AGENTS.md") == "$root/pi/AGENTS.md" ]]
[[ $(readlink "$HOME/.pi/agent/settings.json") == "$root/pi/settings.json" ]]
[[ ! -e $HOME/.bashrc && ! -L $HOME/.bashrc ]]
[[ ! -e $HOME/.config/herdr ]]
[[ ! -e $HOME/.pi/agent/sandbox.json && ! -L $HOME/.pi/agent/sandbox.json ]]
bash "$root/setup" install nvim >/dev/null

# Validate every selector before creating any links.
if bash "$root/setup" install _vimrc unknown-link 2> "$tmp/error"; then
  echo 'setup unexpectedly accepted an unknown link' >&2
  exit 1
fi
[[ $(< "$tmp/error") == *'unknown link: unknown-link'* ]]
[[ ! -e $HOME/.vimrc && ! -L $HOME/.vimrc ]]

# Partial uninstall is idempotent and leaves other selected entries intact.
bash "$root/setup" uninstall nvim >/dev/null
bash "$root/setup" uninstall nvim >/dev/null
[[ ! -L $HOME/.config/nvim ]]
[[ $(readlink "$HOME/.pi/agent/settings.json") == "$root/pi/settings.json" ]]

# Uninstall preserves unrelated links; install can replace them.
mkdir "$tmp/other-nvim"
ln -s "$tmp/other-nvim" "$HOME/.config/nvim"
bash "$root/setup" uninstall nvim >/dev/null
[[ $(readlink "$HOME/.config/nvim") == "$tmp/other-nvim" ]]
bash "$root/setup" install nvim >/dev/null
[[ $(readlink "$HOME/.config/nvim") == "$root/nvim" ]]
[[ ! -e $tmp/other-nvim/nvim ]]

# Regular files are still protected.
printf 'local vimrc\n' > "$HOME/.vimrc"
if bash "$root/setup" install _vimrc >/dev/null 2> "$tmp/error"; then
  echo 'setup unexpectedly overwrote a regular file' >&2
  exit 1
fi
[[ $(< "$HOME/.vimrc") == 'local vimrc' ]]

# With no selectors, the existing full-install and full-uninstall behavior remains.
export HOME="$tmp/full-home"
unset XDG_CONFIG_HOME
mkdir "$HOME"
git config --file "$HOME/.gitconfig" core.checkstat minimal
bash "$root/setup" >/dev/null
[[ $(readlink "$HOME/.bashrc") == "$root/_bashrc" ]]
[[ $(readlink "$HOME/.config/herdr/config.toml") == "$root/herdr/config.toml" ]]
[[ $(readlink "$HOME/.config/git/config") == "$root/git/config" ]]
[[ $(readlink "$HOME/.config/git/ignore") == "$root/git/ignore" ]]
[[ ! -e $HOME/.gitignore_global && ! -L $HOME/.gitignore_global ]]
[[ $(git config --file "$HOME/.gitconfig" --get core.checkstat) == minimal ]]
[[ $(readlink "$HOME/.pi/agent/sandbox.json") == "$root/pi/sandbox.json" ]]
bash "$root/setup" uninstall >/dev/null
[[ -z $(find "$HOME" -type l -print) ]]
[[ $(git config --file "$HOME/.gitconfig" --get core.checkstat) == minimal ]]

printf 'setup selection checks passed\n'
