#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/sbx/entrypoint.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sbx.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export SBX_STARTUP_LOG="$tmp/calls" SBX_BASH_ARGS="$tmp/bash-args"
export SBX_COPILOT_SCRIPT="$root/sbx/configure-copilot.mjs"
export HOME="$tmp/home with spaces"
mkdir -p "$tmp/bin" "$HOME/dotfiles/.git"
printf 'export SBX_BASHRC_LOADED=1\n' > "$HOME/.bashrc"
cat > "$tmp/bin/stub" <<'SH'
#!/bin/sh
set -eu
case "${0##*/}" in
  git) exit "${GIT_STATUS:-0}" ;;
  node)
    [ "${SBX_BASHRC_LOADED:-}" = 1 ] || exit 98
    [ "$#" = 1 ] && [ "$1" = "$SBX_COPILOT_SCRIPT" ] || exit 98
    echo configure >> "$SBX_STARTUP_LOG"
    exit "${CONFIGURE_STATUS:-0}" ;;
  bash)
    if [ "${1:-}" = "$HOME/dotfiles/setup" ]; then
      echo setup >> "$SBX_STARTUP_LOG"
      exit "${SETUP_STATUS:-0}"
    fi
    [ "${SBX_BASHRC_LOADED:-}" = 1 ] || exit 98
    echo bash >> "$SBX_STARTUP_LOG"
    printf '%s\n' "$@" > "$SBX_BASH_ARGS"
    exit "${BASH_STATUS:-0}" ;;
  *) exit 99 ;;
esac
SH
chmod +x "$tmp/bin/stub"
for cmd in git node bash; do ln -s stub "$tmp/bin/$cmd"; done
export PATH="$tmp/bin:$PATH"
unset PI_COPILOT_BASE_URL CONFIGURE_STATUS BASH_STATUS GIT_STATUS SETUP_STATUS
run() {
  : > "$SBX_STARTUP_LOG"
  rm -f "$SBX_BASH_ARGS"
  status=0
  /bin/bash "$script" "$@" || status=$?
}

# Direct kit launches initialize dotfiles and open Bash, never Pi.
run
[[ $status == 0 && $(< "$SBX_STARTUP_LOG") == $'setup\nbash' ]]
[[ $(< "$SBX_BASH_ARGS") == '' ]]

# Proxy setup runs first and Bash argument boundaries are preserved.
export PI_COPILOT_BASE_URL=https://api.business.githubcopilot.com
run -c 'echo hello world'
[[ $status == 0 && $(< "$SBX_STARTUP_LOG") == $'setup\nconfigure\nbash' ]]
[[ $(< "$SBX_BASH_ARGS") == $'-c\necho hello world' ]]
GIT_STATUS=37 run
[[ $status == 37 && ! -s $SBX_STARTUP_LOG && ! -e $SBX_BASH_ARGS ]]
SETUP_STATUS=41 run
[[ $status == 41 && $(< "$SBX_STARTUP_LOG") == setup && ! -e $SBX_BASH_ARGS ]]
CONFIGURE_STATUS=43 run
[[ $status == 43 && $(< "$SBX_STARTUP_LOG") == $'setup\nconfigure' && ! -e $SBX_BASH_ARGS ]]
BASH_STATUS=47 run
[[ $status == 47 && $(< "$SBX_STARTUP_LOG") == $'setup\nconfigure\nbash' ]]

# Keep Pi installation and startup in the kit, not the host shortcut.
python3 - "$root/sbx/spec.yaml" <<'PY'
import pathlib
import sys
spec = pathlib.Path(sys.argv[1]).read_text()
assert 'FROM docker.io/sbx/shell-docker-image:latest' in spec
assert 'RUN npm install -g @earendil-works/pi-coding-agent pnpm' in spec
assert 'unset NPM_CONFIG_PREFIX' in spec
assert 'source "$NVM_DIR/nvm.sh"' in spec
for alias in ('jod', 'krypton', 'lithium'):
    assert f'nvm install lts/{alias}' in spec
assert 'ENTRYPOINT ["/bin/bash", "/tmp/entrypoint.sh"]' in spec
assert 'COPY --chown=1000:1000 configure-copilot.mjs /tmp/configure-copilot.mjs' in spec
assert 'COPY --chown=1000:1000 entrypoint.sh /tmp/entrypoint.sh' in spec
assert 'COPY --chown=1000:1000 bashrc.sh /home/agent/.bashrc' in spec
assert 'pi-image' not in spec and 'ENTRYPOINT ["tini"' not in spec
PY

printf 'sbx kit startup checks passed\n'
