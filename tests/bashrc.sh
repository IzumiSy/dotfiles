#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/bashrc.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# Check source order and symlink resolution without initializing host tools.
mkdir -p "$tmp/repo with spaces/bash" "$tmp/home"
cp "$root/_bashrc" "$tmp/repo with spaces/_bashrc"
ln -s "$tmp/repo with spaces/_bashrc" "$tmp/home/.bashrc"
for file in common commands sandbox tools; do
  printf 'printf "%%s\\n" "%s" >> "$LOAD_ORDER"\n' "$file" > "$tmp/repo with spaces/bash/$file.sh"
done
printf 'function exists() { return 1; }\n' >> "$tmp/repo with spaces/bash/common.sh"

for entry in "$tmp/repo with spaces/_bashrc" "$tmp/home/.bashrc"; do
  : > "$tmp/load-order"
  LOAD_ORDER="$tmp/load-order" /bin/bash --noprofile --norc -c '
    source "$1"
    [[ ! ${_dotfiles_bash_dir+x} ]]
  ' bash "$entry"
  [[ $(< "$tmp/load-order") == $'common\ncommands\nsandbox\ntools' ]]
done

# Preserve both tool-backed aliases and the original standard-command defaults.
for tools_available in yes no; do
  (
    exists() { [[ $tools_available == yes ]]; }
    set +e
    source "$root/bash/commands.sh"
    set -e
    if [[ $tools_available == yes ]]; then
      [[ $(alias ls) == "alias ls='eza'" ]]
      [[ $(alias cat) == *'bat -p --theme=Dracula'* ]]
    else
      [[ $(alias ls) == "alias ls='ls --color=auto'" ]]
      [[ $(alias ll) == *'ls -Flh1v --group-directories-first'* ]]
    fi
    declare -F killport hist >/dev/null
  )
done

printf 'modular Bash startup checks passed\n'
