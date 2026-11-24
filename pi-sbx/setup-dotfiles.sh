#!/usr/bin/env bash
set -eu

dotfiles="$HOME/dotfiles"

if [ -d "$dotfiles/.git" ]; then
  git -C "$dotfiles" fetch --depth 1 origin master
  git -C "$dotfiles" checkout --detach FETCH_HEAD
else
  git clone --depth 1 --branch master \
    https://github.com/IzumiSy/dotfiles.git \
    "$dotfiles"
fi

bash "$dotfiles/setup" install pi/AGENTS.md pi/settings.json nvim

bashrc_source='source "$HOME/dotfiles/bash/common.sh"'
grep -qxF "$bashrc_source" "$HOME/.bashrc" 2>/dev/null ||
  printf '\n%s\n' "$bashrc_source" >> "$HOME/.bashrc"

exec pi "$@"
