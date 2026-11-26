#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/bash/sandbox.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/sbpmap.XXXXXX")
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/project/subdir" "$tmp/project-other"
export PATH="$tmp/bin:$PATH" HERDR_WORKSPACE_ID=w12
export SBPMAP_FIXTURES="$tmp" SBPMAP_ROOT="$root"
name=sbx-project-w12

# Never publish real ports or execute commands in a real sandbox.
cat > "$tmp/bin/sbx" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\t' "${0##*/}" "$@" >> "$SBPMAP_FIXTURES/calls"
printf '\n' >> "$SBPMAP_FIXTURES/calls"
case "$1" in
  ls)
    [[ $* == 'ls --format json' ]] || exit 98
    [[ ${SBPMAP_LS_STATUS:-0} == 0 ]] || exit "$SBPMAP_LS_STATUS"
    cat "$SBPMAP_FIXTURES/sandboxes" ;;
  exec)
    [[ $# == 6 && $2 == -i && $4 == node && $5 == --input-type=module && $6 == - ]] || exit 98
    [[ ${SBPMAP_EXEC_STATUS:-0} == 0 ]] || exit "$SBPMAP_EXEC_STATUS"
    cat "$SBPMAP_FIXTURES/ports" ;;
  port)
    [[ $2 == ls && $# == 5 && $4 == --format && $5 == json ]] || exit 98
    if [[ -e $SBPMAP_FIXTURES/published ]]; then
      [[ ${SBPMAP_AFTER_STATUS:-0} == 0 ]] || exit "$SBPMAP_AFTER_STATUS"
      cat "$SBPMAP_FIXTURES/after"
    else
      [[ ${SBPMAP_PORT_LS_STATUS:-0} == 0 ]] || exit "$SBPMAP_PORT_LS_STATUS"
      cat "$SBPMAP_FIXTURES/before"
    fi ;;
  --no-input)
    [[ $# == 5 && $2 == port && $3 == publish ]] || exit 98
    [[ ${SBPMAP_PUBLISH_STATUS:-0} == 0 ]] || exit "$SBPMAP_PUBLISH_STATUS"
    spec=${5%/tcp4}
    [[ $5 == */tcp4 ]] || exit 98
    port=${spec##*:}; host=49152
    if [[ $spec == *:* ]]; then host=${spec%%:*}; fi
    jq --argjson port "$port" --argjson host "$host" \
      '. + [{host_ip:"127.0.0.1",host_port:$host,sandbox_port:$port,protocol:"tcp4"}]' \
      "$SBPMAP_FIXTURES/before" > "$SBPMAP_FIXTURES/after"
    : > "$SBPMAP_FIXTURES/published" ;;
  *) exit 99 ;;
esac
SH
cat > "$tmp/bin/peco" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'peco\n' >> "$SBPMAP_FIXTURES/calls"
[[ $* == *'--on-cancel error'* ]] || exit 98
case "${SBPMAP_PECO:-select}" in
  cancel) exit 130 ;;
  empty) exit 0 ;;
  select) awk 'NR == 1 { print }' ;;
  *) exit 99 ;;
esac
SH
chmod +x "$tmp/bin/sbx" "$tmp/bin/peco"

reset() {
  unset SBPMAP_LS_STATUS SBPMAP_EXEC_STATUS SBPMAP_PORT_LS_STATUS SBPMAP_AFTER_STATUS
  unset SBPMAP_PUBLISH_STATUS SBPMAP_PECO
  export HERDR_WORKSPACE_ID=w12
  rm -f "$tmp/published"
  : > "$tmp/calls"
  printf '[]\n' > "$tmp/before"
  jq -n --arg name "$name" --arg workspace "$tmp/project" \
    '[{name:$name,status:"running",workspaces:[$workspace]}]' > "$tmp/sandboxes"
  printf '%s\n' '[{"port":3000,"address":"0.0.0.0","process":"node","loopback":false},{"port":8000,"address":"127.0.0.2","process":"python","loopback":true}]' > "$tmp/ports"
}
run() {
  : > "$tmp/calls"
  status=0
  sb map "$@" >/dev/null 2>&1 || status=$?
}
no_publish() { ! grep -q $'^sbx\t--no-input\tport\tpublish\t' "$tmp/calls"; }
no_exec() { ! grep -q $'^sbx\texec\t' "$tmp/calls"; }
published() {
  [[ $(grep $'^sbx\t--no-input\tport\tpublish\t' "$tmp/calls") == "$(printf '%s\t' sbx --no-input port publish "$1" "$2")" ]]
}

# Explicit IDs must publish to the requested sandbox, not the inherited workspace.
cd "$tmp/project/subdir"
reset
jq '.[0].name = "sbx-project-manual"' "$tmp/sandboxes" > "$tmp/changed"
mv "$tmp/changed" "$tmp/sandboxes"
run --id manual 3000
[[ $status == 0 ]]
published sbx-project-manual 3000/tcp4

# Match the exact ID suffix and sandbox prefix; never fall back to another workspace.
reset
printf '%s\n' '[{"name":"sbx-project-w120","status":"running"},{"name":"other-project-w12","status":"running"}]' > "$tmp/sandboxes"
run 3000
[[ $status == 1 ]]
no_exec; no_publish
for id_state in unset empty; do
  reset
  if [[ $id_state == unset ]]; then unset HERDR_WORKSPACE_ID; else HERDR_WORKSPACE_ID=''; fi
  run 3000
  [[ $status == 1 && ! -s $tmp/calls ]]
done
reset
for spec in 0 65536 00000 1:0 0:3000 65536:3000 3000:65536 -1 abc 3000/tcp4 127.0.0.1:8080:3000 1:2:3 ''; do
  run "$spec"
  [[ $status == 1 && ! -s $tmp/calls ]]
done
for args in '--id' '--unknown' '3000 5173'; do
  run $args
  [[ $status == 1 && ! -s $tmp/calls ]]
done
run --id '' 3000
[[ $status == 1 && ! -s $tmp/calls ]]

# Path matching is component-aware, not just a string prefix.
reset
jq --arg sibling "$tmp/project-other" \
  '. + [{name:"sbx-sibling-w12",status:"running",workspaces:[$sibling]}]' \
  "$tmp/sandboxes" > "$tmp/changed"
mv "$tmp/changed" "$tmp/sandboxes"
run 3000
[[ $status == 0 ]]
published "$name" 3000/tcp4
reset
jq '. + [{name:"sbx-second-w12",status:"running",workspaces:["/elsewhere"]}]' \
  "$tmp/sandboxes" > "$tmp/changed"
mv "$tmp/changed" "$tmp/sandboxes"
cd "$tmp"
run 3000
[[ $status == 1 ]]
no_exec; no_publish
cd "$tmp/project/subdir"
reset
jq '.[0].status = "stopped"' "$tmp/sandboxes" > "$tmp/changed"
mv "$tmp/changed" "$tmp/sandboxes"
run 3000
[[ $status == 1 ]]
no_exec; no_publish

# Reuse only compatible loopback bindings; explicit differing hosts add a mapping.
for protocol in tcp4 tcp; do
  for spec in 3000 8080:3000; do
    reset
    jq -n --arg protocol "$protocol" \
      '[{host_ip:"127.0.0.1",host_port:8080,sandbox_port:3000,protocol:$protocol}]' > "$tmp/before"
    run "$spec"
    [[ $status == 0 ]]
    no_publish
  done
done
for binding in '0.0.0.0 tcp4' '127.0.0.1 udp4' '::1 tcp6'; do
  reset
  read -r ip protocol <<< "$binding"
  jq -n --arg ip "$ip" --arg protocol "$protocol" \
    '[{host_ip:$ip,host_port:8080,sandbox_port:3000,protocol:$protocol}]' > "$tmp/before"
  run 3000
  [[ $status == 0 ]]
  published "$name" 3000/tcp4
done
reset
printf '%s\n' '[{"host_ip":"127.0.0.1","host_port":8080,"sandbox_port":3000,"protocol":"tcp4"}]' > "$tmp/before"
run 9090:3000
[[ $status == 0 ]]
published "$name" 9090:3000/tcp4
for port in 8000 9999; do
  reset
  run "$port"
  [[ $status == 1 ]]
  no_publish
done
reset
run </dev/null
[[ $status == 1 ]]
no_exec; no_publish

# Failed inspection must not publish; failed readback must not publish twice.
for failure in LS PORT_LS EXEC PUBLISH; do
  reset
  export "SBPMAP_${failure}_STATUS=23"
  run 3000
  [[ $status == 23 ]]
  if [[ $failure != PUBLISH ]]; then no_publish; fi
done
reset
export SBPMAP_AFTER_STATUS=29
run 3000
[[ $status == 1 ]]
published "$name" 3000/tcp4

# Genuine terminal input must not publish after cancellation or invalid host input.
reset
python3 - <<'PY'
import errno
import os
from pathlib import Path
import pty
import select
import subprocess
import time

fixtures = Path(os.environ["SBPMAP_FIXTURES"])

def rejected_input(text=None, mode="select", expected=130):
    (fixtures / "calls").write_text("")
    (fixtures / "published").unlink(missing_ok=True)
    master, slave = pty.openpty()
    process = subprocess.Popen(
        ["/bin/bash", "--noprofile", "--norc", "-c",
         'source "$1/bash/sandbox.sh"; cd "$2/project/subdir"; sb map',
         "bash", os.environ["SBPMAP_ROOT"], str(fixtures)],
        stdin=slave, stdout=slave, stderr=slave,
        env=dict(os.environ, SBPMAP_PECO=mode),
    )
    os.close(slave)
    output = b""
    sent = False
    deadline = time.monotonic() + 10
    try:
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    chunk = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                if not chunk:
                    break
                output += chunk
            if text is not None and not sent and b"Host port [Enter: auto]: " in output:
                os.write(master, text)
                sent = True
        else:
            raise AssertionError("Interactive sb map timed out: " + output.decode())
        assert process.wait(timeout=2) == expected, output.decode()
        assert text is None or sent, output.decode()
        calls = (fixtures / "calls").read_text()
        assert "peco\n" in calls, calls
        assert "\tport\tpublish\t" not in calls, calls
    finally:
        os.close(master)
        if process.poll() is None:
            process.kill()
            process.wait()

rejected_input(text=b"\x04")
rejected_input(text=b"65536\n", expected=1)
for mode in ("cancel", "empty"):
    rejected_input(mode=mode)
PY

printf 'sb map publication safety checks passed\n'
