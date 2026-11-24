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

bash "$dotfiles/setup" install \
  nvim \
  pi/AGENTS.md \
  pi/settings.json \
  git/_gitconfig \
  git/_gitignore_global \
  git/_tigrc

exec pi "$@"
