#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/sbx/entrypoint.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sbx-dotfiles.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home with spaces" BASH_ARGS="$tmp/bash-args"
export GIT_CONFIG_GLOBAL="$tmp/gitconfig" GIT_CONFIG_NOSYSTEM=1
unset XDG_CONFIG_HOME PI_COPILOT_BASE_URL
mkdir -p "$HOME" "$tmp/remote/pi" "$tmp/remote/nvim" "$tmp/remote/git"
cp "$root/setup" "$root/_starship.toml" "$tmp/remote/"
cp "$root/git/config" "$root/git/ignore" "$root/git/_tigrc" "$tmp/remote/git/"
printf ':\n' > "$tmp/remote/nvim/init.lua"
printf 'first\n' > "$tmp/remote/pi/AGENTS.md"
printf '{}\n' > "$tmp/remote/pi/settings.json"
git init -q "$tmp/remote"
git -C "$tmp/remote" symbolic-ref HEAD refs/heads/master
git -C "$tmp/remote" config user.name Test
git -C "$tmp/remote" config user.email test@example.invalid
git -C "$tmp/remote" config commit.gpgsign false
git -C "$tmp/remote" add .
git -C "$tmp/remote" commit -qm first
git config --global url."file://$tmp/remote".insteadOf https://github.com/IzumiSy/dotfiles.git

# Keep real Git/setup, but do not initialize tools or open a shell.
printf ':\n' > "$HOME/.bashrc"
exec() {
  [[ $1 == bash ]] || exit 98
  printf '%s\n' "$@" > "$BASH_ARGS"
  exit 0
}
export -f exec

git config --file "$HOME/.gitconfig" safe.directory "$tmp/workspace"
git config --file "$HOME/.gitconfig" core.excludesfile "$HOME/.gitignore_global"
cp "$HOME/.gitconfig" "$tmp/expected.gitconfig"
git config --file "$tmp/expected.gitconfig" core.excludesfile "$HOME/.config/git/ignore"

# Initialization and updates preserve the existing Bash and unrelated Git settings.
bash "$script"
cmp "$tmp/expected.gitconfig" "$HOME/.gitconfig"
[[ $(< "$HOME/.bashrc") == ':' ]]
printf 'second\n' > "$tmp/remote/pi/AGENTS.md"
git -C "$tmp/remote" commit -qam second
bash "$script"
cmp "$tmp/expected.gitconfig" "$HOME/.gitconfig"
[[ $(< "$HOME/.bashrc") == ':' ]]

# Existing regular settings/directories must prevent shell entry and stay intact.
for target in .pi/agent/settings.json .config/nvim; do
  rm "$HOME/$target" "$BASH_ARGS"
  if [[ $target == .config/nvim ]]; then
    mkdir "$HOME/$target"
    printf 'local config\n' > "$HOME/$target/init.lua"
  else
    printf 'local config\n' > "$HOME/$target"
  fi
  if bash "$script"; then echo 'setup overwrote existing config' >&2; exit 1; fi
  [[ ! -e $BASH_ARGS ]]
  if [[ -d $HOME/$target ]]; then
    [[ $(< "$HOME/$target/init.lua") == 'local config' && ! -e $HOME/$target/nvim ]]
    rm "$HOME/$target/init.lua"; rmdir "$HOME/$target"
  else
    [[ $(< "$HOME/$target") == 'local config' ]]
    rm "$HOME/$target"
  fi
  bash "$script"
done

# Failed credential configuration must prevent shell entry.
export COPILOT_CONFIG_SCRIPT="$root/sbx/configure-copilot.mjs"
node() {
  [[ $# == 1 && $1 == "$COPILOT_CONFIG_SCRIPT" ]] || return 98
  return 29
}
export -f node
rm "$BASH_ARGS"
status=0
PI_COPILOT_BASE_URL=https://api.business.githubcopilot.com bash "$script" || status=$?
[[ $status == 29 && ! -e $BASH_ARGS ]]

# Local edits and fetch failures must not be discarded or ignored.
printf 'local edit\n' > "$HOME/dotfiles/pi/AGENTS.md"
printf 'third\n' > "$tmp/remote/pi/AGENTS.md"
git -C "$tmp/remote" commit -qam third
if bash "$script"; then echo 'setup discarded local edits' >&2; exit 1; fi
[[ $(< "$HOME/dotfiles/pi/AGENTS.md") == 'local edit' && ! -e $BASH_ARGS ]]
mv "$tmp/remote" "$tmp/offline"
if bash "$script"; then echo 'setup ignored fetch failure' >&2; exit 1; fi
[[ $(< "$HOME/dotfiles/pi/AGENTS.md") == 'local edit' && ! -e $BASH_ARGS ]]

printf 'sbx dotfiles protection checks passed\n'
