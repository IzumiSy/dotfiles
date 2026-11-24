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

mkdir -p "$HOME/.pi/agent"

for file in AGENTS.md settings.json; do
  test -f "$dotfiles/pi/$file"
  [ "$(readlink "$HOME/.pi/agent/$file")" = "$dotfiles/pi/$file" ] ||
    ln -s "$dotfiles/pi/$file" "$HOME/.pi/agent/$file"
done

test -f "$dotfiles/bash/common.sh"
bashrc_source='source "$HOME/dotfiles/bash/common.sh"'
grep -qxF "$bashrc_source" "$HOME/.bashrc" 2>/dev/null ||
  printf '\n%s\n' "$bashrc_source" >> "$HOME/.bashrc"

exec pi "$@"
