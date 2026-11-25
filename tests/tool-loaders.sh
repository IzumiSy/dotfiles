#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/tool-loaders.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home with spaces"
unset HOMEBREW_PREFIX
mkdir -p "$HOME" "$tmp/bin"

# A missing nvm install and unset Homebrew prefix must be safe with nounset.
(
  source "$root/bash/nvm.sh"
  [[ $NVM_DIR == "$HOME/.nvm" ]]
  ! declare -F nvm >/dev/null
)

# Homebrew is a fallback; a home-directory installation takes precedence.
export HOMEBREW_PREFIX="$tmp/homebrew"
mkdir -p "$HOMEBREW_PREFIX/opt/nvm" "$HOME/.nvm"
printf 'nvm() { echo homebrew; }\n' > "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
(
  source "$root/bash/nvm.sh" >/dev/null
  [[ $(nvm --version) == homebrew ]]
)
printf 'nvm() { echo local; }\n' > "$HOME/.nvm/nvm.sh"
bash --noprofile --norc -c '
  set -eu
  source "$1" >/dev/null
  [[ $NVM_DIR == "$HOME/.nvm" && $(nvm --version) == local ]]
' bash "$root/bash/nvm.sh"

# rbenv can be loaded independently, without the host .bashrc's exists helper.
(
  PATH="$tmp/bin"
  source "$root/bash/rbenv.sh"
)
mkdir -p "$HOME/.rbenv/bin"
printf '#!/bin/sh\ncase "$*" in\n  "init --no-rehash -") echo "export RBENV_INITIALIZED=1" ;;\n  rehash) exit 0 ;;\n  *) exit 1 ;;\nesac\n' > "$tmp/bin/rbenv"
chmod +x "$tmp/bin/rbenv"
(
  export PATH="$tmp/bin:$PATH"
  source "$root/bash/rbenv.sh" >/dev/null
  [[ $RBENV_INITIALIZED == 1 && $PATH == "$HOME/.rbenv/bin:"* ]]
)

# Cargo startup needs neither an exists helper nor Rust already on PATH.
(
  PATH="$tmp/bin"
  source "$root/bash/cargo.sh"
  [[ ! ${CARGO_LOADED+x} ]]
)
mkdir -p "$HOME/.cargo"
printf 'export CARGO_LOADED=1\nexport PATH="$HOME/.cargo/bin:$PATH"\n' > "$HOME/.cargo/env"
bash --noprofile --norc -c '
  set -eu
  source "$1"
  [[ $CARGO_LOADED == 1 && $PATH == "$HOME/.cargo/bin:"* ]]
' bash "$root/bash/cargo.sh"

printf 'independent tool loader checks passed\n'
