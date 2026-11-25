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
export SBPMAP_NAME=sbx-project-w12
name=$SBPMAP_NAME

# These are the only sbx/peco executables the test can reach, including PTY children.
cat > "$tmp/bin/stub" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\t' "${0##*/}" "$@" >> "$SBPMAP_FIXTURES/calls"
printf '\n' >> "$SBPMAP_FIXTURES/calls"
if [[ ${0##*/} == peco ]]; then
  [[ $* == *'--on-cancel error'* ]] || exit 98
  [[ ${SBPMAP_PECO_STATUS:-0} == 0 ]] || exit "$SBPMAP_PECO_STATUS"
  if [[ ${SBPMAP_PECO_EMPTY:-0} == 1 ]]; then exit 0; fi
  awk -v row="${SBPMAP_PECO_ROW:-1}" 'NR == row { print }'
  exit 0
fi
case "$1" in
  ls)
    [[ $* == 'ls --format json' ]] || exit 98
    [[ ${SBPMAP_LS_STATUS:-0} == 0 ]] || exit "$SBPMAP_LS_STATUS"
    cat "$SBPMAP_FIXTURES/sandboxes" ;;
  exec)
    [[ $# == 6 && $2 == -i && $4 == node && $5 == --input-type=module && $6 == - ]] || exit 98
    grep -q 'export function scan' || exit 98
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
chmod +x "$tmp/bin/stub"
ln -s stub "$tmp/bin/sbx"
ln -s stub "$tmp/bin/peco"

reset() {
  unset SBPMAP_LS_STATUS SBPMAP_EXEC_STATUS SBPMAP_PORT_LS_STATUS SBPMAP_AFTER_STATUS
  unset SBPMAP_PUBLISH_STATUS SBPMAP_PECO_STATUS SBPMAP_PECO_EMPTY SBPMAP_PECO_ROW
  export HERDR_WORKSPACE_ID=w12
  rm -f "$tmp/published"
  : > "$tmp/calls"
  printf '[]\n' > "$tmp/before"
  jq -n --arg name "$name" --arg workspace "$tmp/project" \
    '[{name:$name,status:"running",workspaces:[$workspace]}]' > "$tmp/sandboxes"
  printf '%s\n' '[{"port":3000,"address":"0.0.0.0","process":"node","loopback":false},{"port":5173,"address":"192.168.1.5","process":"-","loopback":false},{"port":8000,"address":"127.0.0.2","process":"python","loopback":true}]' > "$tmp/ports"
}
run() {
  : > "$tmp/calls"
  status=0
  output=$(sbpmap "$@" 2>&1) || status=$?
}
no_publish() { ! grep -q $'^sbx\t--no-input\tport\tpublish\t' "$tmp/calls"; }
no_exec() { ! grep -q $'^sbx\texec\t' "$tmp/calls"; }
published() {
  [[ $(grep $'^sbx\t--no-input\tport\tpublish\t' "$tmp/calls") == "$(printf '%s\t' sbx --no-input port publish "$1" "$2")" ]]
}

# A unique workspace match works from a subdirectory, with auto or fixed host ports.
reset
cd "$tmp/project/subdir"
run 3000
[[ $status == 0 && $output == *'Mapped: 127.0.0.1:49152 -> sandbox:3000/tcp4'* ]]
published "$name" 3000/tcp4
reset
run 08080:03000
[[ $status == 0 && $output == *'127.0.0.1:8080 -> sandbox:3000/tcp4'* ]]
published "$name" 8080:3000/tcp4

# Manual IDs override the environment; numbers otherwise remain ports, never IDs.
reset
jq '.[0].name = "sbx-project-manual"' "$tmp/sandboxes" > "$tmp/changed"
mv "$tmp/changed" "$tmp/sandboxes"
run --id manual 3000
[[ $status == 0 ]]
published sbx-project-manual 3000/tcp4
reset
run 12
[[ $status == 1 && $output == *'Port 12 has no reachable'* ]]
no_publish

# Match the exact ID suffix and sandbox prefix; never fall back to another workspace.
reset
printf '%s\n' '[{"name":"sbx-project-w120","status":"running"},{"name":"other-project-w12","status":"running"}]' > "$tmp/sandboxes"
run 3000
[[ $status == 1 && $output == *'No sandbox found for workspace w12'* ]]
no_exec; no_publish
for id_state in unset empty; do
  reset
  if [[ $id_state == unset ]]; then unset HERDR_WORKSPACE_ID; else HERDR_WORKSPACE_ID=''; fi
  run 3000
  [[ $status == 1 && $output == *HERDR_WORKSPACE_ID* && ! -s $tmp/calls ]]
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
run --help
[[ $status == 0 && $output == Usage:* && ! -s $tmp/calls ]]

# The valid port endpoints are inclusive.
for port in 1 65535; do
  reset
  jq -n --argjson port "$port" '[{port:$port,address:"0.0.0.0",process:"-",loopback:false}]' > "$tmp/ports"
  run "$port"
  [[ $status == 0 ]]
  published "$name" "$port/tcp4"
done

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
[[ $status == 1 && $output == *'Multiple sandboxes'* ]]
no_exec; no_publish
cd "$tmp/project/subdir"
reset
jq '.[0].status = "stopped"' "$tmp/sandboxes" > "$tmp/changed"
mv "$tmp/changed" "$tmp/sandboxes"
run 3000
[[ $status == 1 && $output == *'is not running'* ]]
no_exec; no_publish

# Reuse only compatible loopback bindings; explicit differing hosts add a mapping.
for protocol in tcp4 tcp; do
  for spec in 3000 8080:3000; do
    reset
    jq -n --arg protocol "$protocol" \
      '[{host_ip:"127.0.0.1",host_port:8080,sandbox_port:3000,protocol:$protocol}]' > "$tmp/before"
    run "$spec"
    [[ $status == 0 && $output == *"127.0.0.1:8080 -> sandbox:3000/$protocol"* ]]
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
[[ $status == 0 && $output == *'127.0.0.1:9090'* ]]
published "$name" 9090:3000/tcp4
for port in 8000 9999; do
  reset
  run "$port"
  [[ $status == 1 && $output == *'bind the service to 0.0.0.0'* ]]
  no_publish
done
reset
run </dev/null
[[ $status == 1 && $output == *'requires a terminal'* ]]
no_exec; no_publish

# Native failures keep their status; post-publication read failures never republish.
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
[[ $status == 1 && $output == *'Port was published, but its host binding could not be read'* ]]
published "$name" 3000/tcp4
reset

# PTYs supply genuine terminal descriptors without running peco or publishing ports.
python3 - <<'PY'
import errno
import json
import os
from pathlib import Path
import pty
import select
import subprocess
import time

fixtures = Path(os.environ["SBPMAP_FIXTURES"])
root = os.environ["SBPMAP_ROOT"]
name = os.environ["SBPMAP_NAME"]
base_sandboxes = (fixtures / "sandboxes").read_text()

def terminal(args=(), text=None, environment=None, before="[]"):
    (fixtures / "calls").write_text("")
    (fixtures / "published").unlink(missing_ok=True)
    (fixtures / "before").write_text(before)
    env = dict(os.environ, **(environment or {}))
    master, slave = pty.openpty()
    process = subprocess.Popen(
        ["/bin/bash", "--noprofile", "--norc", "-c",
         'source "$1/bash/sandbox.sh"; cd "$2/project/subdir"; sbpmap "${@:3}"',
         "bash", root, str(fixtures), *args],
        stdin=slave, stdout=slave, stderr=slave, env=env,
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
            raise AssertionError("Interactive sbpmap timed out: " + output.decode())
        status = process.wait(timeout=2)
    finally:
        os.close(master)
        if process.poll() is None:
            process.kill()
            process.wait()
    return status, output.decode(), (fixtures / "calls").read_text()

for text, spec in [(b"\n", "3000/tcp4"), (b"08080\n", "8080:3000/tcp4")]:
    status, output, calls = terminal(text=text)
    assert status == 0, output
    assert f"sbx\t--no-input\tport\tpublish\t{name}\t{spec}\t\n" in calls
    assert "Loopback-only listeners" in output and "8000: 127.0.0.2" in output
    assert "Mapped: 127.0.0.1:" in output

status, output, calls = terminal(text=b"\n", environment={"SBPMAP_PECO_ROW": "2"})
assert status == 0 and "sandbox:5173/tcp4" in output, output
assert f"sbx\t--no-input\tport\tpublish\t{name}\t5173/tcp4\t\n" in calls
status, output, calls = terminal(text=b"65536\n")
assert status == 1 and "Host port must be between" in output, output
assert "\tport\tpublish\t" not in calls
status, output, calls = terminal(text=b"\x04")
assert status == 130 and "\tport\tpublish\t" not in calls, output
for environment in [{"SBPMAP_PECO_STATUS": "130"}, {"SBPMAP_PECO_EMPTY": "1"}]:
    status, output, calls = terminal(environment=environment)
    assert status == 130 and "\tport\tpublish\t" not in calls, output

# An existing mapping is returned without prompting for another host port.
status, output, calls = terminal(before='[{"host_ip":"127.0.0.1","host_port":8080,"sandbox_port":3000,"protocol":"tcp4"}]')
assert status == 0 and "Mapped: 127.0.0.1:8080" in output, output
assert "Host port [Enter: auto]" not in output and "\tport\tpublish\t" not in calls

sandboxes = json.loads(base_sandboxes)
sandboxes.append({"name": "sbx-second-w12", "status": "running", "workspaces": [str(fixtures / "project")]})
(fixtures / "sandboxes").write_text(json.dumps(sandboxes))
status, output, calls = terminal(args=("3000",), environment={"SBPMAP_PECO_ROW": "2"})
assert status == 0 and "Sandbox: sbx-second-w12" in output, output
assert "sbx\t--no-input\tport\tpublish\tsbx-second-w12\t3000/tcp4\t" in calls
status, output, calls = terminal(args=("3000",), environment={"SBPMAP_PECO_STATUS": "130"})
assert status == 130 and "\texec\t" not in calls and "\tport\tpublish\t" not in calls, output
(fixtures / "sandboxes").write_text(base_sandboxes)

ports = (fixtures / "ports").read_text()
for listeners in [[], [{"port":8000,"address":"127.0.0.2","process":"python","loopback":True}]]:
    (fixtures / "ports").write_text(json.dumps(listeners))
    status, output, calls = terminal()
    assert status == 1 and "No reachable IPv4 TCP listeners found" in output, output
    assert "peco\t" not in calls and "\tport\tpublish\t" not in calls
(fixtures / "ports").write_text(ports)
PY

printf 'sbpmap workspace, mapping, validation and terminal checks passed\n'
