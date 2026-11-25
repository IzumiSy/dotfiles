#!/usr/bin/env node
// List IPv4 TCP listeners in the sandbox's network namespace.
import { readFileSync, readdirSync, readlinkSync, realpathSync } from "node:fs";
import { endianness } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

export function scan(procRoot = "/proc") {
  const listeners = [];
  for (const line of readFileSync(join(procRoot, "net/tcp"), "utf8").split("\n").slice(1)) {
    const fields = line.trim().split(/\s+/);
    if (fields.length < 10 || fields[3] !== "0A") continue;
    const [hex, portHex] = fields[1].split(":");
    if (!/^[\da-f]{8}$/i.test(hex) || !/^[\da-f]{4}$/i.test(portHex)) {
      throw new Error("Invalid IPv4 TCP listener address in /proc");
    }
    const bytes = Buffer.from(hex, "hex");
    if (endianness() === "LE") bytes.reverse();
    listeners.push({ port: parseInt(portHex, 16), address: [...bytes].join("."), inode: `socket:[${fields[9]}]` });
  }
  if (!listeners.length) return [];

  const processes = new Map(listeners.map(({ inode }) => [inode, new Set()]));
  for (const pid of readdirSync(procRoot)) {
    if (!/^\d+$/.test(pid)) continue;
    try {
      const name = readFileSync(join(procRoot, pid, "comm"), "utf8")
        .replace(/[\p{C}\p{Z}]/gu, " ").replace(/\s+/gu, " ").trim() || "-";
      for (const fd of readdirSync(join(procRoot, pid, "fd"))) {
        let inode;
        try {
          inode = readlinkSync(join(procRoot, pid, "fd", fd));
        } catch {
          continue;
        }
        processes.get(inode)?.add(name);
      }
    } catch (error) {
      // Processes may disappear or hide their descriptors while scanning.
      if (!error.code) throw error;
    }
  }

  const rows = new Map();
  for (const { port, address, inode } of listeners) {
    const names = processes.get(inode);
    for (const name of names.size ? names : ["-"]) {
      rows.set(JSON.stringify([port, address, name]), {
        port, address, process: name, loopback: address.startsWith("127."),
      });
    }
  }
  const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
  return [...rows.values()].sort((a, b) =>
    a.port - b.port || compare(a.address, b.address) || compare(a.process, b.process));
}

if (process.argv[1] === "-" || process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href) {
  try {
    console.log(JSON.stringify(scan()));
  } catch (error) {
    console.error(`Cannot inspect sandbox TCP listeners: ${error.message}`);
    process.exitCode = 1;
  }
}
