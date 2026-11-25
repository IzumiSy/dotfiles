#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/sbx/entrypoint.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sbx.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export SBX_STARTUP_LOG="$tmp/calls" SBX_BASH_ARGS="$tmp/bash-args"
export SBX_COPILOT_SCRIPT="$root/sbx/configure-copilot.mjs"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/stub" <<'SH'
#!/bin/sh
set -eu
case "${0##*/}" in
  node)
    [ "$#" = 1 ] && [ "$1" = "$SBX_COPILOT_SCRIPT" ] || exit 98
    echo configure >> "$SBX_STARTUP_LOG"
    exit "${CONFIGURE_STATUS:-0}" ;;
  bash)
    echo bash >> "$SBX_STARTUP_LOG"
    printf '%s\n' "$@" > "$SBX_BASH_ARGS"
    exit "${BASH_STATUS:-0}" ;;
  *) exit 99 ;;
esac
SH
chmod +x "$tmp/bin/stub"
for cmd in node bash; do ln -s stub "$tmp/bin/$cmd"; done
export PATH="$tmp/bin:$PATH"
unset PI_COPILOT_BASE_URL CONFIGURE_STATUS BASH_STATUS
run() {
  : > "$SBX_STARTUP_LOG"
  rm -f "$SBX_BASH_ARGS"
  status=0
  /bin/bash "$script" "$@" || status=$?
}

# Direct kit launches without a proxy still open a login shell, never Pi.
run
[[ $status == 0 && $(< "$SBX_STARTUP_LOG") == bash ]]
[[ $(< "$SBX_BASH_ARGS") == -l ]]

# Proxy setup runs first and Bash argument boundaries are preserved.
export PI_COPILOT_BASE_URL=https://api.business.githubcopilot.com
run -c 'echo hello world'
[[ $status == 0 && $(< "$SBX_STARTUP_LOG") == $'configure\nbash' ]]
[[ $(< "$SBX_BASH_ARGS") == $'-l\n-c\necho hello world' ]]
CONFIGURE_STATUS=43 run
[[ $status == 43 && $(< "$SBX_STARTUP_LOG") == configure && ! -e $SBX_BASH_ARGS ]]
BASH_STATUS=47 run
[[ $status == 47 && $(< "$SBX_STARTUP_LOG") == $'configure\nbash' ]]

# Keep Pi installation and startup in the kit, not the host shortcut.
python3 - "$root/sbx/spec.yaml" <<'PY'
import pathlib
import sys
spec = pathlib.Path(sys.argv[1]).read_text()
assert 'FROM docker.io/sbx/shell-image:latest' in spec
assert 'RUN npm install -g @earendil-works/pi-coding-agent && pi --version' in spec
assert 'ENTRYPOINT ["tini", "--", "/bin/bash", "/tmp/entrypoint.sh"]' in spec
assert 'COPY --chown=1000:1000 configure-copilot.mjs /tmp/configure-copilot.mjs' in spec
assert 'COPY --chown=1000:1000 entrypoint.sh /tmp/entrypoint.sh' in spec
assert 'pi-image' not in spec and 'dotfiles' not in spec
PY

printf 'sbx kit startup checks passed\n'
