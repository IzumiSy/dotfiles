#!/usr/bin/env python3
"""List IPv4 TCP listeners in the sandbox's network namespace."""

import json
import os
from pathlib import Path
import socket
import struct
import sys


def scan(proc_root="/proc"):
    root = Path(proc_root)
    listeners = []
    for line in (root / "net/tcp").read_text().splitlines()[1:]:
        fields = line.split()
        if len(fields) < 10 or fields[3] != "0A":
            continue
        address, port = fields[1].split(":")
        address = socket.inet_ntoa(struct.pack("=I", int(address, 16)))
        listeners.append((int(port, 16), address, f"socket:[{fields[9]}]"))

    if not listeners:
        return []

    processes = {inode: set() for _, _, inode in listeners}
    for pid in root.iterdir():
        if not pid.name.isdecimal():
            continue
        try:
            name = (pid / "comm").read_text(errors="replace")
            name = " ".join("".join(c if c.isprintable() else " " for c in name).split()) or "-"
            for fd in (pid / "fd").iterdir():
                try:
                    inode = os.readlink(fd)
                except OSError:
                    continue
                if inode in processes:
                    processes[inode].add(name)
        except OSError:
            # Processes may disappear or hide their descriptors while scanning.
            continue

    rows = {
        (port, address, name)
        for port, address, inode in listeners
        for name in processes[inode] or {"-"}
    }
    return [
        {"port": port, "address": address, "process": name, "loopback": address.startswith("127.")}
        for port, address, name in sorted(rows)
    ]


if __name__ == "__main__":
    try:
        print(json.dumps(scan()))
    except OSError as error:
        print(f"Cannot inspect sandbox TCP listeners: {error}", file=sys.stderr)
        sys.exit(1)
