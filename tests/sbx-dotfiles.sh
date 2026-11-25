#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/sbx/entrypoint.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sbx-dotfiles.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home with spaces" BASH_ARGS="$tmp/bash-args"
export GIT_CONFIG_GLOBAL="$tmp/gitconfig" GIT_CONFIG_NOSYSTEM=1
unset XDG_CONFIG_HOME PI_COPILOT_BASE_URL
mkdir -p "$HOME" "$tmp/bin" "$tmp/remote/pi" "$tmp/remote/bash" "$tmp/remote/nvim" "$tmp/remote/git"
cp "$root/setup" "$root/_starship.toml" "$tmp/remote/"
cp "$root/bash/base.sh" "$root/bash/nvm.sh" "$root/bash/tools.sh" "$tmp/remote/bash/"
cp "$root/nvim/init.lua" "$root/nvim/lazy-lock.json" "$tmp/remote/nvim/"
cp "$root/git/config" "$root/git/ignore" "$root/git/_tigrc" "$tmp/remote/git/"
cp "$root/sbx/bashrc.sh" "$HOME/.bashrc"
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

git config --file "$HOME/.gitconfig" safe.directory "$tmp/workspace"
git config --file "$HOME/.gitconfig" core.excludesfile "$HOME/.gitignore_global"
cp "$HOME/.gitconfig" "$tmp/expected.gitconfig"
git config --file "$tmp/expected.gitconfig" core.excludesfile "$HOME/.config/git/ignore"

# Model the image's persistent environment without accessing the host's /etc.
source() {
  if [[ $1 == /etc/sandbox-persistent.sh ]]; then
    export SANDBOX_PERSISTENT_LOADED=1
    export PATH="$SANDBOX_BASE_PATH" NPM_CONFIG_PREFIX=/usr/local/share/npm-global
    export BASH_ENV=/etc/sandbox-persistent.sh
  else
    builtin source "$@"
  fi
}
# Intercept only the final exec; all setup and child-shell checks use real Bash.
exec() {
  [[ $1 == bash && $SANDBOX_PERSISTENT_LOADED == 1 ]] || exit 98
  shift
  [[ ! ${NPM_CONFIG_PREFIX+x} && $BASH_ENV == "$HOME/.bashrc" ]] || exit 98
  [[ $(command node --version) == v22.0.0 ]] || exit 98
  printf '%s\n' "$@" > "$BASH_ARGS"
  exit "${BASH_STATUS:-0}"
}
export -f source exec
cat > "$tmp/bin/starship" <<'SH'
#!/bin/sh
[ "$*" = 'init bash' ] || exit 98
printf 'export STARSHIP_INITIALIZED=1\nexport PS1="starship-prompt"\n'
SH
cat > "$tmp/bin/peco" <<'SH'
#!/bin/sh
if [ "$*" = --version ]; then echo mock-peco; else cat; fi
SH
chmod +x "$tmp/bin/starship" "$tmp/bin/peco"
export PATH="$tmp/bin:$PATH" SANDBOX_BASE_PATH="$tmp/bin:$PATH"
mkdir -p "$HOME/.nvm/versions/node/v22.0.0/bin"
cat > "$HOME/.nvm/nvm.sh" <<'SH'
[[ $SANDBOX_PERSISTENT_LOADED == 1 && ! ${NPM_CONFIG_PREFIX+x} ]] || return 1
export PATH="$NVM_DIR/versions/node/v22.0.0/bin:$PATH"
nvm() { printf 'mock-nvm\n'; }
SH
printf '#!/bin/sh\nprintf "v22.0.0\\n"\n' > "$HOME/.nvm/versions/node/v22.0.0/bin/node"
chmod +x "$HOME/.nvm/versions/node/v22.0.0/bin/node"

# First launch clones dotfiles, links every previous sandbox setting, and enters Bash.
bash "$script" -c 'echo argument with spaces'
[[ $(< "$BASH_ARGS") == $'-c\necho argument with spaces' ]]
[[ $(git -C "$HOME/dotfiles" rev-parse HEAD) == "$(git -C "$tmp/remote" rev-parse master)" ]]
for pair in 'pi/AGENTS.md:.pi/agent/AGENTS.md' 'pi/settings.json:.pi/agent/settings.json' \
  '_starship.toml:.starship.toml' 'nvim:.config/nvim' 'git/config:.config/git/config' \
  'git/ignore:.config/git/ignore' 'git/_tigrc:.tigrc'; do
  [[ $(readlink "$HOME/${pair#*:}") == "$HOME/dotfiles/${pair%%:*}" ]]
done
[[ ! -e $HOME/.pi/agent/sandbox.json && ! -L $HOME/.pi/agent/sandbox.json ]]
cmp "$tmp/expected.gitconfig" "$HOME/.gitconfig"
cmp "$root/sbx/bashrc.sh" "$HOME/.bashrc"
env -u GIT_CONFIG_GLOBAL git -C "$HOME/dotfiles" check-ignore -q .pnpm-store/test

# Interactive shells retain nvm, shared aliases, prompt, history, and helpers.
bash --noprofile --rcfile "$HOME/.bashrc" -ic '
  set -eu
  [[ ! ${NPM_CONFIG_PREFIX+x} && $BASH_ENV == "$HOME/.bashrc" ]]
  [[ $(nvm --version) == mock-nvm && $(command node --version) == v22.0.0 ]]
  [[ :$SHELLOPTS: == *:ignoreeof:* && $HISTCONTROL == ignoreboth:erasedups ]]
  [[ $(alias gs) == *"git status --short"* && $(alias pco) == *"peco"* ]]
  declare -F gd hist killport >/dev/null
  [[ $STARSHIP_INITIALIZED == 1 && $PS1 == starship-prompt ]]
  [[ $STARSHIP_CONFIG == "$HOME/.starship.toml" ]]
' </dev/null 2>/dev/null
for attempt in 1 2; do
  output=$(BASH_ENV="$HOME/.bashrc" bash -c '
    set -eu
    [[ ! ${NPM_CONFIG_PREFIX+x} && ! ${STARSHIP_INITIALIZED+x} ]]
    [[ $PATH == "$NVM_DIR/versions/node/v22.0.0/bin:$SANDBOX_BASE_PATH" ]]
    [[ $(nvm --version) == mock-nvm && $(command node --version) == v22.0.0 ]]
    bash -c '\''[[ $(nvm --version) == mock-nvm && $(command node --version) == v22.0.0 ]]'\''
  ')
  [[ -z $output ]]
done

# Reattachment fetches updated settings, keeps Bash config, and preserves shell status.
printf 'second\n' > "$tmp/remote/pi/AGENTS.md"
git -C "$tmp/remote" commit -qam second
status=0
BASH_STATUS=23 bash "$script" || status=$?
[[ $status == 23 && $(< "$HOME/.pi/agent/AGENTS.md") == second ]]
cmp "$tmp/expected.gitconfig" "$HOME/.gitconfig"
cmp "$root/sbx/bashrc.sh" "$HOME/.bashrc"

# Regular settings/directories are preserved and prevent entry into Bash.
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

# Proxy setup runs after dotfiles and must prevent Bash if configuration fails.
export COPILOT_CONFIG_ARGS="$tmp/copilot-config-args"
node() { printf '%s\n' "$@" > "$COPILOT_CONFIG_ARGS"; return "${NODE_STATUS:-0}"; }
export -f node
PI_COPILOT_BASE_URL=https://api.business.githubcopilot.com bash "$script"
[[ $(< "$COPILOT_CONFIG_ARGS") == "$root/sbx/configure-copilot.mjs" ]]
rm "$BASH_ARGS"
status=0
PI_COPILOT_BASE_URL=https://api.business.githubcopilot.com NODE_STATUS=29 bash "$script" || status=$?
[[ $status == 29 && ! -e $BASH_ARGS ]]

# Local edits and fetch failures are never silently discarded or ignored.
printf 'local edit\n' > "$HOME/dotfiles/pi/AGENTS.md"
printf 'third\n' > "$tmp/remote/pi/AGENTS.md"
git -C "$tmp/remote" commit -qam third
if bash "$script"; then echo 'setup discarded local edits' >&2; exit 1; fi
[[ $(< "$HOME/dotfiles/pi/AGENTS.md") == 'local edit' && ! -e $BASH_ARGS ]]
mv "$tmp/remote" "$tmp/offline"
if bash "$script"; then echo 'setup ignored fetch failure' >&2; exit 1; fi
[[ ! -e $BASH_ARGS ]]

printf 'sbx dotfiles and Bash initialization checks passed\n'
