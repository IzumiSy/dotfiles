#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/runner.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo with spaces"
mkdir -p "$repo/tests" "$repo/bash" "$repo/sbx" "$tmp/bin" "$tmp/sbx"
cp "$root/test" "$repo/test"
cp "$root/tests/run" "$repo/tests/run"
for file in setup _bashrc bash/stub.sh sbx/stub.sh; do
  printf ':\n' > "$repo/$file"
done

# The shared runner gives tests a clean environment and removes their homes.
cat > "$repo/tests/probe.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ -d $HOME && -d $TMPDIR ]]
[[ ! ${DOTFILES_RUNNER_LEAK+x} && ! ${GIT_DIR+x} && ! ${BASH_ENV+x} ]]
[[ $GIT_CONFIG_GLOBAL == /dev/null && $GIT_CONFIG_NOSYSTEM == 1 ]]
printf 'private config\n' > "$HOME/config"
printf 'probe-home=%s\n' "$HOME"
SH
output=$(DOTFILES_RUNNER_LEAK=secret GIT_DIR=/nonexistent \
  /bin/bash "$repo/tests/run")
home=${output##*$'\n'probe-home=}
[[ $home == */dotfiles-tests.*/probe.sh/home && ! -e $home ]]

# A failed test keeps its exit status and still cleans up.
printf 'exit 23\n' >> "$repo/tests/probe.sh"
status=0
/bin/bash "$repo/tests/run" > "$tmp/output" || status=$?
[[ $status == 23 ]]
output=$(< "$tmp/output")
home=${output##*$'\n'probe-home=}
[[ $home == */dotfiles-tests.*/probe.sh/home && ! -e $home ]]

# Test the host launcher without creating or removing a real sandbox.
cat > "$tmp/bin/sbx" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == --no-input ]]
command=$2
shift 2
printf '%s\n' "$@" > "$SBX_CALLS/$command"
case "$command" in
  create) exit "${SBX_CREATE_STATUS:-0}" ;;
  exec) exit "${SBX_EXEC_STATUS:-0}" ;;
  rm) exit 0 ;;
  *) exit 99 ;;
esac
SH
chmod +x "$tmp/bin/sbx"
export PATH="$tmp/bin:$PATH" SBX_CALLS="$tmp/sbx"

/bin/bash "$repo/test"
create=$(< "$SBX_CALLS/create")
[[ $create == --name$'\n'dotfiles-tests-* ]]
[[ $create == *"$(printf '%s\n' --skills off --static-mcp none --deny-network '**' shell)"$'\n'*/dotfiles-test-workspace.*$'\n'"$repo:/workspace:ro" ]]
while IFS= read -r arg; do
  case "$arg" in
    */dotfiles-test-workspace.*) [[ ! -e $arg ]] ;;
  esac
done < "$SBX_CALLS/create"
exec_args=$(< "$SBX_CALLS/exec")
[[ $exec_args == --user$'\n'agent$'\n'--workdir$'\n'/workspace$'\n'dotfiles-tests-* ]]
[[ $exec_args == *"$(printf '%s\n' env -i HOME=/tmp PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/bash --noprofile --norc tests/run)" ]]
[[ -s $SBX_CALLS/rm ]]

for failure in create exec; do
  rm "$SBX_CALLS/rm"
  status=0
  if [[ $failure == create ]]; then
    SBX_CREATE_STATUS=23 /bin/bash "$repo/test" || status=$?
  else
    SBX_EXEC_STATUS=23 /bin/bash "$repo/test" || status=$?
  fi
  [[ $status == 23 && -s $SBX_CALLS/rm ]]
done

printf 'isolated test runner checks passed\n'
