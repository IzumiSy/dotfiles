#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/setup.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home with spaces"
mkdir -p "$HOME" "$tmp/work"
cd "$tmp/work"

# Only selected entries are linked, even when called outside the repository.
bash "$root/setup" install nvim pi/AGENTS.md pi/settings.json >/dev/null
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
mkdir "$HOME"
bash "$root/setup" >/dev/null
[[ $(readlink "$HOME/.bashrc") == "$root/_bashrc" ]]
[[ $(readlink "$HOME/.config/herdr/config.toml") == "$root/herdr/config.toml" ]]
[[ $(readlink "$HOME/.gitconfig") == "$root/git/_gitconfig" ]]
[[ $(readlink "$HOME/.pi/agent/sandbox.json") == "$root/pi/sandbox.json" ]]
bash "$root/setup" uninstall >/dev/null
[[ -z $(find "$HOME" -type l -print) ]]

printf 'setup selection checks passed\n'
