#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sbpmap.XXXXXX")
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/project/subdir"
export PATH="$tmp/bin:$PATH" SBPMAP_FIXTURES="$tmp" SBPMAP_ROOT="$root"

# Never change real port mappings or execute commands in a real sandbox.
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
    [[ $# == 5 && $2 == port ]] || exit 98
    if [[ $3 == unpublish ]]; then
      printf 'native-unpublish-output\n'
      exit "${SBPMAP_UNPUBLISH_STATUS:-0}"
    fi
    [[ $3 == publish && $5 == */tcp4 ]] || exit 98
    [[ ${SBPMAP_PUBLISH_STATUS:-0} == 0 ]] || exit "$SBPMAP_PUBLISH_STATUS"
    spec=${5%/tcp4}; port=${spec##*:}; host=49152
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
[[ $# == 4 && $1 == --prompt && $3 == --on-cancel && $4 == error ]] || exit 98
printf 'peco\t%s\n' "$2" >> "$SBPMAP_FIXTURES/calls"
case "$2" in
  'Sandbox> ') mode=${SBPMAP_SANDBOX_PECO:-select}; row=${SBPMAP_SANDBOX_ROW:-1} ;;
  'Port> ') mode=${SBPMAP_PECO:-select}; row=1 ;;
  'Unmap> ') mode=${SBPMAP_UNMAP_PECO:-select}; row=${SBPMAP_UNMAP_ROW:-1} ;;
  *) exit 99 ;;
esac
case "$mode" in
  cancel) exit 130 ;;
  empty) exit 0 ;;
  forged)
    case "$2" in
      'Sandbox> ') printf 'sbx-project-manual\trunning\t/elsewhere\n' ;;
      'Port> ') printf '8000\tpython\t127.0.0.2\tunmapped\n' ;;
      'Unmap> ') printf 'sbx-project-w12\t127.0.0.1:65530:3000/tcp4\n' ;;
    esac ;;
  multiple) awk 'NR <= 2 { print }' ;;
  select) awk -v row="$row" 'NR == row { print }' ;;
  *) exit 99 ;;
esac
SH
chmod +x "$tmp/bin/sbx" "$tmp/bin/peco"

# Every mapping change uses genuine terminal descriptors and isolated fixtures.
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
name = "sbx-project-w12"
base = [{"name": name, "status": "running", "workspaces": [str(fixtures / "project")]}]
manual = dict(base[0], name="sbx-project-manual", workspaces=["/elsewhere"])
listeners = [
    {"port": 3000, "address": "0.0.0.0", "process": "node", "loopback": False},
    {"port": 8000, "address": "127.0.0.2", "process": "python", "loopback": True},
]
command = ["/bin/bash", "--noprofile", "--norc", "-c",
           'source "$1/bash/sandbox.sh"; cd "$2/project/subdir"; sb "$3" "${@:4}"',
           "bash", os.environ["SBPMAP_ROOT"], str(fixtures)]
prompt = "Host port [Enter: auto]: "
sandbox_stage = "peco\tSandbox> \n"
port_stage = "peco\tPort> \n"
unmap_stage = "peco\tUnmap> \n"

def terminal(args=(), text=b"\n", environment=None, sandboxes=None, ports=None, before=(), subcommand="map"):
    for file, value in (("sandboxes", base if sandboxes is None else sandboxes),
                        ("ports", listeners if ports is None else ports), ("before", before)):
        (fixtures / file).write_text(json.dumps(value))
    (fixtures / "calls").write_text("")
    (fixtures / "published").unlink(missing_ok=True)
    (fixtures / "after").unlink(missing_ok=True)
    env = dict(os.environ, HERDR_ENV="1", HERDR_WORKSPACE_ID="w12")
    for key, value in (environment or {}).items():
        if value is None:
            env.pop(key, None)
        else:
            env[key] = value
    master, slave = pty.openpty()
    process = None
    output = b""
    sent = False
    try:
        process = subprocess.Popen([*command, subcommand, *args], stdin=slave, stdout=slave, stderr=slave, env=env)
        os.close(slave)
        slave = None
        deadline = time.monotonic() + 10
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
            if text is not None and not sent and prompt.encode() in output:
                os.write(master, text)
                sent = True
        else:
            raise AssertionError(f"Interactive sb {subcommand} timed out: " + output.decode())
        return process.wait(timeout=2), output.decode(), (fixtures / "calls").read_text()
    finally:
        if slave is not None:
            os.close(slave)
        os.close(master)
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()

def publications(calls):
    return [line for line in calls.splitlines() if line.startswith("sbx\t--no-input\tport\tpublish\t")]

def removals(calls):
    return [line for line in calls.splitlines() if line.startswith("sbx\t--no-input\tport\tunpublish\t")]

def published(calls, target=name, spec="3000/tcp4"):
    assert publications(calls) == [f"sbx\t--no-input\tport\tpublish\t{target}\t{spec}\t"], calls
    assert port_stage in calls, calls
    assert f"sbx\texec\t-i\t{target}\t" in calls, calls

def untouched(calls):
    assert "sbx\texec\t" not in calls and not publications(calls) and not removals(calls), calls

# Explicit and inherited IDs must not publish into another workspace.
status, output, calls = terminal(args=("manual",), sandboxes=[*base, manual])
assert status == 0 and sandbox_stage not in calls, output
published(calls, manual["name"])
status, output, calls = terminal(sandboxes=[manual, *base])
assert status == 0 and sandbox_stage not in calls, output
published(calls)
status, output, calls = terminal(sandboxes=[dict(base[0], name="sbx-project-w120"),
                                          dict(base[0], name="other-project-w12")])
assert status == 1, output
untouched(calls)

# Outside Herdr, stale/absent IDs must allow selection from the complete inventory.
custom = dict(base[0], name="custom-sandbox", workspaces=["/elsewhere"])
for context in ({"HERDR_ENV": None, "HERDR_WORKSPACE_ID": None},
                {"HERDR_ENV": "0"}, {"HERDR_WORKSPACE_ID": ""}):
    status, output, calls = terminal(sandboxes=[*base, custom],
                                    environment=dict(context, SBPMAP_SANDBOX_ROW="2"))
    assert status == 0 and sandbox_stage in calls, output
    published(calls, custom["name"])
second = dict(base[0], name="sbx-second-w12", workspaces=["/elsewhere"])
status, output, calls = terminal(sandboxes=[*base, second], environment={"SBPMAP_SANDBOX_ROW": "2"})
assert status == 0 and sandbox_stage in calls, output
published(calls, second["name"])

# Sandbox cancellation, forged out-of-scope choices, and stopped sandboxes do not execute.
for mode in ("cancel", "empty", "forged"):
    status, output, calls = terminal(sandboxes=[*base, second, manual], environment={"SBPMAP_SANDBOX_PECO": mode})
    assert status != 0 and sandbox_stage in calls and port_stage not in calls, (status, output, calls)
    if mode != "forged":
        assert status == 130, (status, output)
    untouched(calls)
status, output, calls = terminal(sandboxes=[dict(base[0], status="stopped")])
assert status == 1 and sandbox_stage not in calls, output
untouched(calls)

# Unsupported flags and extra positional arguments have no side effects.
for args in (("--id",), ("--id", "manual"), ("--unknown",), ("manual", "extra")):
    status, output, calls = terminal(args=args)
    assert status == 1 and not calls, output

# Port cancellation and invalid/EOF host input must reach their own stage without publishing.
for mode in ("cancel", "empty"):
    status, output, calls = terminal(environment={"SBPMAP_PECO": mode})
    assert status == 130 and port_stage in calls, output
    assert not publications(calls), calls
for text in (b"0\n", b"65536\n", b"-1\n", b"not-a-port\n", b"\x04"):
    status, output, calls = terminal(text=text)
    assert status == (130 if text == b"\x04" else 1) and prompt in output and port_stage in calls, output
    assert not publications(calls), calls

# Loopback-only services are not selectable, and even a forged blocked port must not publish.
for ports in ([], [listeners[1]]):
    status, output, calls = terminal(ports=ports)
    assert status == 1 and port_stage not in calls and not publications(calls), output
status, output, calls = terminal(environment={"SBPMAP_PECO": "forged"})
assert status == 1 and port_stage in calls and prompt not in output and not publications(calls), output

# Compatible loopback mappings are reused; wildcard/UDP/IPv6 bindings require a new mapping.
for protocol in ("tcp4", "tcp"):
    binding = {"host_ip": "127.0.0.1", "host_port": 8080, "sandbox_port": 3000, "protocol": protocol}
    status, output, calls = terminal(before=[binding])
    assert status == 0 and prompt not in output and not publications(calls), output
for ip, protocol in (("0.0.0.0", "tcp4"), ("127.0.0.1", "udp4"), ("::1", "tcp6")):
    binding = {"host_ip": ip, "host_port": 8080, "sandbox_port": 3000, "protocol": protocol}
    status, output, calls = terminal(before=[binding], text=b"09090\n")
    assert status == 0 and prompt in output, output
    published(calls, spec="9090:3000/tcp4")

# Native failures keep their status; readback failure must not publish a second time.
for failure in ("LS", "PORT_LS", "EXEC", "PUBLISH"):
    status, output, calls = terminal(environment={f"SBPMAP_{failure}_STATUS": "23"})
    assert status == 23, output
    if failure == "PUBLISH":
        published(calls)
        assert not (fixtures / "published").exists()
    else:
        assert not publications(calls), calls
        if failure in ("LS", "PORT_LS"):
            untouched(calls)
status, output, calls = terminal(environment={"SBPMAP_AFTER_STATUS": "29"})
assert status == 1, output
published(calls)

# Unmap must remove only the selected complete binding, never every host port or protocol.
bindings = [
    {"host_ip": ip, "host_port": port, "sandbox_port": 3000, "protocol": protocol}
    for ip, port, protocol in (("127.0.0.1", 49156, "tcp4"), ("127.0.0.1", 49157, "tcp4"),
                               ("0.0.0.0", 49156, "udp4"), ("::1", 49156, "tcp6"),
                               ("::", 49156, "udp6"), ("127.0.0.1", 49156, "tcp"),
                               ("::1", 49156, "udp"))
]
specs = ("127.0.0.1:49156:3000/tcp4", "127.0.0.1:49157:3000/tcp4", "0.0.0.0:49156:3000/udp4",
         "[::1]:49156:3000/tcp6", "[::]:49156:3000/udp6", "127.0.0.1:49156:3000/tcp", "[::1]:49156:3000/udp")
for row, spec in enumerate(specs, 1):
    status, output, calls = terminal(subcommand="unmap", args=("manual",), sandboxes=[*base, manual],
                                    before=bindings, environment={"SBPMAP_UNMAP_ROW": str(row)})
    assert status == 0 and unmap_stage in calls and sandbox_stage not in calls, (status, output, calls)
    assert removals(calls) == [f"sbx\t--no-input\tport\tunpublish\t{manual['name']}\t{spec}\t"], calls
    assert f"sbx\tport\tls\t{manual['name']}\t--format\tjson\t" in calls, calls
    assert "sbx\texec\t" not in calls and not publications(calls), calls
    assert "Unmapped:" in output and "native-unpublish-output" not in output, output

# Cancellation or a forged/multiline choice must not reach unpublish.
status, output, calls = terminal(subcommand="unmap", before=bindings, sandboxes=[*base, second],
                                environment={"SBPMAP_SANDBOX_PECO": "cancel"})
assert status == 130 and sandbox_stage in calls and unmap_stage not in calls, (status, output, calls)
untouched(calls)
for mode in ("cancel", "empty", "forged", "multiple"):
    status, output, calls = terminal(subcommand="unmap", before=bindings,
                                    environment={"SBPMAP_UNMAP_PECO": mode})
    assert status != 0 and unmap_stage in calls, (status, output, calls)
    if mode in ("cancel", "empty"):
        assert status == 130, (status, output)
    untouched(calls)

# Missing or malformed binding fields must never become a broader unpublish specification.
for before in ([], None, [dict(bindings[0], host_port=0)], [dict(bindings[0], host_port=1.5)],
               [dict(bindings[0], host_port="49156/evil")], [dict(bindings[0], sandbox_port=65536)],
               [dict(bindings[0], sandbox_port="3000/tcp4")], [dict(bindings[0], host_ip=None)],
               [dict(bindings[0], host_ip="attacker.invalid/path")], [dict(bindings[0], protocol="icmp")]):
    status, output, calls = terminal(subcommand="unmap", before=before)
    assert status != 0 and unmap_stage not in calls, (status, output, calls)
    untouched(calls)

# Native inspection failures do not remove ports; removal failures keep their status and no success text.
for failure in ("LS", "PORT_LS"):
    status, output, calls = terminal(subcommand="unmap", before=bindings,
                                    environment={f"SBPMAP_{failure}_STATUS": "23"})
    assert status == 23 and unmap_stage not in calls and "Unmapped:" not in output, output
    untouched(calls)
status, output, calls = terminal(subcommand="unmap", before=bindings,
                                environment={"SBPMAP_UNPUBLISH_STATUS": "31"})
assert status == 31 and unmap_stage in calls and "Unmapped:" not in output, output
assert removals(calls) == [f"sbx\t--no-input\tport\tunpublish\t{name}\t{specs[0]}\t"], calls
assert "sbx\texec\t" not in calls and not publications(calls), calls
assert "native-unpublish-output" not in output, output
for args in (("--id",), ("--id", "manual"), ("--unknown",), ("manual", "extra")):
    status, output, calls = terminal(subcommand="unmap", args=args, before=bindings)
    assert status == 1 and not calls, output

# Nonterminal invocation must never inspect or change a sandbox's mappings.
for subcommand in ("map", "unmap"):
    (fixtures / "calls").write_text("")
    result = subprocess.run([*command, subcommand], stdin=subprocess.DEVNULL, capture_output=True, timeout=10)
    assert result.returncode == 1 and not (fixtures / "calls").read_text(), result.stderr.decode()
PY

printf 'sandbox port publication and removal safety checks passed\n'
