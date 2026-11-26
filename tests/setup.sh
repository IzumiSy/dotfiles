#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/setup.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home with spaces"
mkdir -p "$HOME" "$tmp/work"
cd "$tmp/work"

# Validate every selector before creating any links.
if bash "$root/setup" install _vimrc unknown-link 2> "$tmp/error"; then
  echo 'setup unexpectedly accepted an unknown link' >&2
  exit 1
fi
[[ ! -e $HOME/.vimrc && ! -L $HOME/.vimrc ]]

# A partial uninstall must leave other managed links intact.
bash "$root/setup" install nvim pi/settings.json >/dev/null
bash "$root/setup" uninstall nvim >/dev/null
[[ ! -L $HOME/.config/nvim ]]
[[ $(readlink "$HOME/.pi/agent/settings.json") == "$root/pi/settings.json" ]]

# Uninstall preserves unrelated links; replacement never writes into their targets.
mkdir "$tmp/other-nvim"
printf 'local config\n' > "$tmp/other-nvim/init.lua"
ln -s "$tmp/other-nvim" "$HOME/.config/nvim"
bash "$root/setup" uninstall nvim >/dev/null
[[ $(readlink "$HOME/.config/nvim") == "$tmp/other-nvim" ]]
bash "$root/setup" install nvim >/dev/null
[[ $(< "$tmp/other-nvim/init.lua") == 'local config' && ! -e $tmp/other-nvim/nvim ]]

# Regular files must never be overwritten or removed.
printf 'local vimrc\n' > "$HOME/.vimrc"
if bash "$root/setup" install _vimrc >/dev/null 2> "$tmp/error"; then
  echo 'setup unexpectedly overwrote a regular file' >&2
  exit 1
fi
bash "$root/setup" uninstall _vimrc >/dev/null
[[ $(< "$HOME/.vimrc") == 'local vimrc' ]]

# Full install/uninstall preserves existing global Git configuration.
export HOME="$tmp/full-home"
mkdir "$HOME"
printf '[core]\n\tcheckstat = minimal\n' > "$HOME/.gitconfig"
cp "$HOME/.gitconfig" "$tmp/expected.gitconfig"
bash "$root/setup" >/dev/null
cmp "$tmp/expected.gitconfig" "$HOME/.gitconfig"
bash "$root/setup" uninstall >/dev/null
[[ -z $(find "$HOME" -type l -print) ]]
cmp "$tmp/expected.gitconfig" "$HOME/.gitconfig"

printf 'setup file protection checks passed\n'
