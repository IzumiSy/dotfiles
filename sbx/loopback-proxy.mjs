import { readFileSync } from "node:fs";
import { createConnection, createServer, isIP } from "node:net";
import { endianness, networkInterfaces } from "node:os";
import { pathToFileURL } from "node:url";

export function parseListeners(table) {
  return table.split("\n").slice(1).flatMap((line) => {
    const fields = line.trim().split(/\s+/);
    if (fields.length < 10 || fields[3] !== "0A") return [];
    const [hex, portHex] = fields[1].split(":");
    if (!/^(?:[\da-f]{8}|[\da-f]{32})$/i.test(hex) || !/^[\da-f]{4}$/i.test(portHex)) {
      throw new Error("Invalid TCP listener address in /proc");
    }
    const bytes = Buffer.from(hex, "hex");
    if (endianness() === "LE") {
      for (let i = 0; i < bytes.length; i += 4) bytes.subarray(i, i + 4).reverse();
    }
    const address = bytes.length === 4 ? [...bytes].join(".") :
      Array.from({ length: 8 }, (_, i) => bytes.readUInt16BE(i * 2).toString(16)).join(":");
    const loopback = bytes.length === 4 ? bytes[0] === 127 :
      bytes.subarray(0, 15).every((byte) => byte === 0) && bytes[15] === 1 ||
      bytes.subarray(0, 10).every((byte) => byte === 0) && bytes[10] === 255 &&
      bytes[11] === 255 && bytes[12] === 127;
    return [{ address, port: parseInt(portHex, 16), loopback }];
  });
}

export function ingressAddress(routes, interfaces) {
  // shortcut: use the default-route IPv4 interface; revisit for multi-homed sandboxes.
  const defaults = routes.split("\n").slice(1).map((line) => line.trim().split(/\s+/))
    .filter((fields) => fields[1] === "00000000" && (parseInt(fields[3], 16) & 1))
    .sort((a, b) => Number(a[6]) - Number(b[6]));
  for (const [name] of defaults) {
    const address = interfaces[name]?.find((entry) => entry.family === "IPv4" && !entry.internal)?.address;
    if (address) return address;
  }
  throw new Error("No default-route IPv4 address available");
}

export function bridgeTargets(listeners, bindAddress, ownPorts) {
  const blocked = new Set();
  const candidates = new Map();
  for (const { address, port, loopback } of listeners) {
    if (!loopback) {
      if (address !== bindAddress || !ownPorts.has(port)) blocked.add(port);
      continue;
    }
    if (!candidates.has(port)) candidates.set(port, new Set());
    candidates.get(port).add(address);
  }
  const targets = new Map();
  for (const [port, addresses] of candidates) {
    if (blocked.has(port)) continue;
    // Prefer IPv4 when localhost listens on both families; don't guess between different loopback IPs.
    const ipv4 = [...addresses].filter((address) => isIP(address) === 4);
    const choices = ipv4.length ? ipv4 : [...addresses];
    if (choices.length === 1) targets.set(port, choices[0]);
  }
  return targets;
}

export function createRelay(bindAddress, port, upstream, sockets) {
  const server = createServer({ allowHalfOpen: true }, (client) => {
    const remote = createConnection({ host: upstream, port, allowHalfOpen: true });
    for (const socket of [client, remote]) {
      sockets.add(socket);
      socket.on("close", () => sockets.delete(socket));
      socket.on("error", () => { client.destroy(); remote.destroy(); });
    }
    // FIN is forwarded by pipe; an abrupt close must also release its peer.
    client.on("close", () => { if (!client.readableEnded) remote.destroy(); });
    remote.on("close", () => { if (!remote.readableEnded) client.destroy(); });
    client.pipe(remote);
    remote.pipe(client);
  });
  server.listen(port, bindAddress);
  return server;
}

function main() {
  if (process.platform !== "linux") throw new Error("Loopback proxy requires Linux /proc");
  // An abstract Unix socket provides a namespace-local lock with automatic crash cleanup.
  const lock = createServer((socket) => socket.destroy());
  const relays = new Map();
  const sockets = new Set();
  let timer;
  let bindAddress;
  let lastError;
  const stop = () => {
    clearInterval(timer);
    for (const relay of relays.values()) relay.server.close();
    for (const socket of sockets) socket.destroy();
    lock.close();
  };
  const poll = () => {
    try {
      const address = ingressAddress(readFileSync("/proc/net/route", "utf8"), networkInterfaces());
      const listeners = parseListeners(readFileSync("/proc/net/tcp", "utf8"));
      try {
        listeners.push(...parseListeners(readFileSync("/proc/net/tcp6", "utf8")));
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
      }
      if (address !== bindAddress) {
        for (const relay of relays.values()) relay.server.close();
        relays.clear();
        bindAddress = address;
      }
      const ownPorts = new Set([...relays].filter(([, relay]) => relay.server.listening).map(([port]) => port));
      const targets = bridgeTargets(listeners, bindAddress, ownPorts);
      for (const [port, relay] of relays) {
        if (targets.get(port) !== relay.upstream) {
          relay.server.close();
          relays.delete(port);
          console.log(`Stopped relay on ${bindAddress}:${port}`);
        }
      }
      for (const [port, upstream] of targets) {
        if (relays.has(port)) continue;
        const server = createRelay(bindAddress, port, upstream, sockets);
        const relay = { server, upstream };
        relays.set(port, relay);
        server.on("listening", () => console.log(`Relay ${bindAddress}:${port} -> ${upstream}:${port}`));
        server.on("error", (error) => {
          server.close();
          if (relays.get(port) === relay) relays.delete(port);
          console.error(`Cannot relay port ${port}: ${error.code || error.message}`);
        });
      }
      lastError = undefined;
    } catch (error) {
      // A failed scan must not leave previously discovered services exposed.
      for (const relay of relays.values()) relay.server.close();
      relays.clear();
      if (error.message !== lastError) console.error(`Cannot scan listeners: ${error.message}`);
      lastError = error.message;
    }
  };
  lock.on("error", (error) => {
    if (error.code === "EADDRINUSE") {
      console.log("Loopback proxy is already running");
    } else {
      console.error(`Cannot acquire loopback proxy lock: ${error.code || error.message}`);
      process.exitCode = 1;
    }
  });
  lock.listen("\0dotfiles-loopback-proxy", () => {
    process.on("SIGTERM", stop);
    process.on("SIGINT", stop);
    poll();
    timer = setInterval(poll, 1000);
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
