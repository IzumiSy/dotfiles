#!/usr/bin/env bash
set -eu

: "${DOTFILES_COMMIT:?DOTFILES_COMMIT is required}"

git clone --no-checkout \
  https://github.com/IzumiSy/dotfiles.git \
  /home/agent/dotfiles

git -C /home/agent/dotfiles checkout --detach "$DOTFILES_COMMIT"

test -f /home/agent/dotfiles/pi/AGENTS.md
test -f /home/agent/dotfiles/pi/settings.json

mkdir -p /home/agent/.pi/agent

ln -s \
  /home/agent/dotfiles/pi/AGENTS.md \
  /home/agent/dotfiles/pi/settings.json \
  /home/agent/.pi/agent/
