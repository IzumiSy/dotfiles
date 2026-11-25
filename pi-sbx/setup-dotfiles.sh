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
  _starship.toml \
  nvim \
  pi/AGENTS.md \
  pi/settings.json \
  git/config \
  git/ignore \
  git/_tigrc

# sbx explicitly sets this global default; keep its other settings intact.
if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
  git config --file "$HOME/.gitconfig" core.excludesfile \
    "${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
fi

source "$HOME/.bashrc"

if [[ -n ${PI_COPILOT_BASE_URL:-} ]]; then
  node "$(dirname "$0")/configure-copilot.mjs"
fi

exec pi "$@"
