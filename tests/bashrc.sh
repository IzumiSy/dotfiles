#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/bashrc.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# Check source order and symlink resolution without initializing host tools.
mkdir -p "$tmp/repo with spaces/bash" "$tmp/home"
cp "$root/_bashrc" "$tmp/repo with spaces/_bashrc"
ln -s "$tmp/repo with spaces/_bashrc" "$tmp/home/.bashrc"
for file in base sandbox nvm rbenv cargo tools; do
  printf 'printf "%%s\\n" "%s" >> "$LOAD_ORDER"\n' "$file" > "$tmp/repo with spaces/bash/$file.sh"
done
printf 'function exists() { return 1; }\n' >> "$tmp/repo with spaces/bash/base.sh"

for entry in "$tmp/repo with spaces/_bashrc" "$tmp/home/.bashrc"; do
  : > "$tmp/load-order"
  LOAD_ORDER="$tmp/load-order" /bin/bash --noprofile --norc -c '
    source "$1"
    [[ ! ${_dotfiles_bash_dir+x} ]]
  ' bash "$entry"
  [[ $(< "$tmp/load-order") == $'base\nsandbox\nnvm\nrbenv\ncargo\ntools' ]]
done

# Tool-specific aliases override base defaults only when the tools exist.
mkdir -p "$tmp/bin" "$tmp/empty-bin"
for tool in eza bat; do
  printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/$tool"
  chmod +x "$tmp/bin/$tool"
done
for tools_available in yes no; do
  (
    if [[ $tools_available == yes ]]; then
      PATH="$tmp/bin"
    else
      PATH="$tmp/empty-bin"
    fi
    # Stub Linux-only completion files without initializing host tools.
    source() {
      case "$1" in
        /etc/bash_completion.d/git-prompt|/etc/profile.d/bash_completion.sh) return 0 ;;
        *) builtin source "$@" ;;
      esac
    }
    source "$root/bash/base.sh" </dev/null
    source "$root/bash/tools.sh"
    if [[ $tools_available == yes ]]; then
      [[ $(alias ls) == "alias ls='eza'" ]]
      [[ $(alias ll) == *'eza -lh --time-style=long-iso --group-directories-first'* ]]
      [[ $(alias lla) == *'eza -lha --bytes --time-style=long-iso --group-directories-first'* ]]
      [[ $(alias cat) == *'bat -p --theme=Dracula'* ]]
    else
      [[ $(alias ls) == "alias ls='ls --color=auto'" ]]
      [[ $(alias ll) == "alias ll='ls -lh'" ]]
      [[ $(alias lla) == "alias lla='ls -lha'" ]]
    fi
    declare -F killport hist >/dev/null
  )
done

printf 'modular Bash startup checks passed\n'
