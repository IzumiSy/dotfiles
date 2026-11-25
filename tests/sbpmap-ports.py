#!/usr/bin/env python3
"""Self-check the listener scanner against a temporary proc-shaped tree."""

import os
from pathlib import Path
import runpy
import socket
import struct
import subprocess
import sys
import tempfile


scan = runpy.run_path(str(Path(__file__).resolve().parents[1] / "bash/sbpmap-ports.py"))["scan"]


def tcp_row(address, port, inode, state="0A"):
    address_hex = struct.unpack("=I", socket.inet_aton(address))[0]
    return f"0: {address_hex:08X}:{port:04X} 00000000:0000 {state} 0:0 00:0 0 1000 0 {inode}\n"


def process(root, pid, name, inodes):
    directory = root / str(pid)
    (directory / "fd").mkdir(parents=True)
    if name is not None:
        (directory / "comm").write_text(name)
    for number, inode in enumerate(inodes):
        (directory / "fd" / str(number)).symlink_to(f"socket:[{inode}]")


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    (root / "net").mkdir()
    tcp = root / "net/tcp"
    tcp.write_text(
        "sl local_address rem_address st tx_queue tr retrnsmt uid timeout inode\n"
        + tcp_row("0.0.0.0", 3000, 10)
        + tcp_row("0.0.0.0", 3000, 11)
        + tcp_row("127.0.0.2", 8000, 20)
        + tcp_row("192.168.1.5", 65535, 30)
        + tcp_row("127.0.0.1", 5432, 40, "01")
        + tcp_row("0.0.0.0", 5173, 50)
    )
    process(root, 100, "node\n", [10, 11])
    process(root, 101, "node\n", [10])
    process(root, 102, "py\tworker\x1b\n", [20])
    process(root, 103, None, [30])
    (root / "104").mkdir()  # Disappearing/missing process files are harmless.
    process(root, 105, "other\n", [])
    (root / "105/fd/0").write_text("not a socket symlink")

    assert scan(root) == [
        {"port": 3000, "address": "0.0.0.0", "process": "node", "loopback": False},
        {"port": 5173, "address": "0.0.0.0", "process": "-", "loopback": False},
        {"port": 8000, "address": "127.0.0.2", "process": "py worker", "loopback": True},
        {"port": 65535, "address": "192.168.1.5", "process": "-", "loopback": False},
    ]

    # An empty table is different from a missing/unreadable table.
    tcp.write_text("sl local_address rem_address st tx_queue tr retrnsmt uid timeout inode\n")
    assert scan(root) == []
    tcp.unlink()
    try:
        scan(root)
    except FileNotFoundError:
        pass
    else:
        raise AssertionError("Missing /proc/net/tcp must not look like zero listeners")

    # A project's Python modules must not shadow the scanner's standard library.
    tcp.write_text("sl local_address rem_address st tx_queue tr retrnsmt uid timeout inode\n")
    shadow = root / "shadow"
    shadow.mkdir()
    (shadow / "json.py").write_text('raise RuntimeError("project json.py imported")\n')
    source = (Path(__file__).resolve().parents[1] / "bash/sbpmap-ports.py").read_text()
    result = subprocess.run(
        [sys.executable, "-I", "-"],
        input="__name__ = 'scanner_test'\n" + source + f"\nassert scan({str(root)!r}) == []\n",
        cwd=shadow, env=dict(os.environ, PYTHONPATH=str(shadow)), text=True, capture_output=True,
    )
    assert result.returncode == 0, result.stderr

print("sbpmap IPv4 TCP listener scanner checks passed")
