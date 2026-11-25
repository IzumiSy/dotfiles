import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { readFileSync } from "node:fs";
import { createConnection, createServer } from "node:net";
import { endianness, networkInterfaces } from "node:os";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { bridgeTargets, createRelay, ingressAddress, parseListeners } from "../sbx/loopback-proxy.mjs";

const script = fileURLToPath(new URL("../sbx/loopback-proxy.mjs", import.meta.url));
const header = "sl local_address rem_address st tx_queue tr retrnsmt uid timeout inode\n";
function row(bytes, port, state = "0A") {
  bytes = Buffer.from(bytes);
  if (endianness() === "LE") {
    for (let i = 0; i < bytes.length; i += 4) bytes.subarray(i, i + 4).reverse();
  }
  return `0: ${bytes.toString("hex")}:${port.toString(16).padStart(4, "0")} 0:0 ${state} 0:0 00:0 0 1000 0 123\n`;
}

test("parse IPv4, IPv6 and mapped loopback listeners, excluding connections", () => {
  const table = header + row([127, 0, 0, 2], 3000) + row([0, 0, 0, 0], 5173) +
    row([...Array(15).fill(0), 1], 8000) +
    row([...Array(10).fill(0), 255, 255, 127, 0, 0, 1], 9000) +
    row([32, 1, ...Array(14).fill(0)], 8080) + row([127, 0, 0, 1], 5432, "01");
  assert.deepEqual(parseListeners(table), [
    { address: "127.0.0.2", port: 3000, loopback: true },
    { address: "0.0.0.0", port: 5173, loopback: false },
    { address: "0:0:0:0:0:0:0:1", port: 8000, loopback: true },
    { address: "0:0:0:0:0:ffff:7f00:1", port: 9000, loopback: true },
    { address: "2001:0:0:0:0:0:0:0", port: 8080, loopback: false },
  ]);
  assert.deepEqual(parseListeners(header), []);
  assert.throws(() => parseListeners(header + "0: invalid:0BB8 0:0 0A 0:0 00:0 0 1000 0 123"), /Invalid/);
});

test("choose the default-route IPv4 address, not a Docker bridge", () => {
  const routes = "Iface Destination Gateway Flags RefCnt Use Metric Mask\n" +
    "docker0 00000000 00000000 0000 0 0 0 00000000\n" +
    "eth1 00000000 0100000A 0003 0 0 100 00000000\n" +
    "eth0 00000000 0100000A 0003 0 0 10 00000000\n";
  const interfaces = Object.fromEntries(["docker0", "eth0", "eth1"].map((name, i) =>
    [name, [{ address: `10.0.${i}.2`, family: "IPv4", internal: false }]]));
  assert.equal(ingressAddress(routes, interfaces), "10.0.1.2");
  assert.throws(() => ingressAddress(routes, {}), /No default-route/);
});

test("avoid external listeners, ambiguous upstreams and recursive proxy discovery", () => {
  const listener = (address, port, loopback = true) => ({ address, port, loopback });
  const listeners = [
    listener("127.0.0.1", 3000), listener("0:0:0:0:0:0:0:1", 3000),
    listener("10.0.0.2", 3000, false),
    listener("127.0.0.1", 5173), listener("0.0.0.0", 5173, false),
    listener("127.0.0.1", 8000), listener("127.0.0.2", 8000),
    listener("0:0:0:0:0:0:0:1", 9000),
    listener("127.0.0.2", 8080), listener("127.0.0.2", 8080),
    listener("127.0.0.1", 4000), listener("0:0:0:0:0:0:0:0", 4000, false),
  ];
  assert.deepEqual([...bridgeTargets(listeners, "10.0.0.2", new Set([3000]))], [
    [3000, "127.0.0.1"], [9000, "0:0:0:0:0:0:0:1"], [8080, "127.0.0.2"],
  ]);
  assert.equal(bridgeTargets(listeners, "10.0.0.2", new Set()).has(3000), false);
});

async function listen(server, address, port = 0) {
  const ready = once(server, "listening");
  server.listen(port, address);
  await ready;
  return server.address().port;
}

async function exchange(address, port, payload) {
  const socket = createConnection({ host: address, port });
  socket.setTimeout(5000, () => socket.destroy(new Error("TCP test timed out")));
  const chunks = [];
  socket.on("data", (chunk) => chunks.push(chunk));
  const ended = once(socket, "end");
  socket.end(payload);
  await ended;
  socket.destroy();
  return Buffer.concat(chunks);
}

test("relay binary data with backpressure and preserve replies after a client FIN", { timeout: 10000 }, async (t) => {
  const sockets = new Set();
  const upstream = createServer({ allowHalfOpen: true }, (socket) => {
    const chunks = [];
    socket.on("data", (chunk) => chunks.push(chunk));
    socket.on("end", () => socket.end(Buffer.concat(chunks)));
  });
  const port = await listen(upstream, "127.0.0.1");
  t.after(() => { upstream.close(); for (const socket of sockets) socket.destroy(); });
  const relay = createRelay("::1", port, "127.0.0.1", sockets);
  t.after(() => relay.close());
  await once(relay, "listening");
  const payload = Buffer.alloc(2 * 1024 * 1024, 0xa5);
  assert.deepEqual(await exchange("::1", port, payload), payload);
  await delay(20);
  assert.equal(sockets.size, 0);

  await new Promise((resolve) => upstream.close(resolve));
  const client = createConnection({ host: "::1", port });
  client.on("error", () => {});
  await new Promise((resolve) => client.on("close", resolve));
  await delay(20);
  assert.equal(sockets.size, 0, "failed upstream connections release both sockets");
});

test("kit packages the proxy and starts it independently of shell sessions", () => {
  const spec = readFileSync(new URL("../sbx/spec.yaml", import.meta.url), "utf8");
  assert.match(spec, /COPY loopback-proxy\.mjs \/opt\/loopback-proxy\.mjs/);
  assert.match(spec, /type: com\.docker\.sandbox\/lifecycle@1/);
  assert.match(spec, /command: \[sh, -c, 'exec node \/opt\/loopback-proxy\.mjs >> \/home\/agent\/loopback-proxy\.log 2>&1'\]/);
  assert.match(spec, /user: "1000"\n\s+background: true/);
});

test("Linux daemon discovers listeners, handles restarts, locks and shutdown", {
  skip: process.platform !== "linux", timeout: 20000,
}, async (t) => {
  const address = ingressAddress(readFileSync("/proc/net/route", "utf8"), networkInterfaces());
  const upstream = createServer((socket) => socket.pipe(socket));
  const port = await listen(upstream, "127.0.0.1");
  const daemon = spawn(process.execPath, [script], { stdio: ["ignore", "pipe", "pipe"] });
  let output = "";
  for (const stream of [daemon.stdout, daemon.stderr]) stream.on("data", (chunk) => { output += chunk; });
  t.after(async () => {
    upstream.close();
    if (daemon.exitCode === null) {
      const exited = once(daemon, "exit");
      daemon.kill("SIGTERM");
      await exited;
    }
  });
  async function waitFor(check) {
    const deadline = Date.now() + 5000;
    while (!check()) {
      assert.equal(daemon.exitCode, null, output);
      assert.ok(Date.now() < deadline, `Daemon did not converge: ${output}`);
      await delay(50);
    }
  }
  const hasRelay = () => parseListeners(readFileSync("/proc/net/tcp", "utf8"))
    .some((listener) => listener.address === address && listener.port === port);
  await waitFor(hasRelay);
  assert.equal((await exchange(address, port, Buffer.from("hello"))).toString(), "hello");
  const duplicate = spawn(process.execPath, [script], { stdio: ["ignore", "pipe", "pipe"] });
  let duplicateOutput = "";
  duplicate.stdout.on("data", (chunk) => { duplicateOutput += chunk; });
  assert.deepEqual(await once(duplicate, "exit"), [0, null]);
  assert.match(duplicateOutput, /already running/);

  await new Promise((resolve) => upstream.close(resolve));
  await waitFor(() => !hasRelay());
  await listen(upstream, "127.0.0.1", port);
  await waitFor(hasRelay);
  assert.equal((await exchange(address, port, Buffer.from("restarted"))).toString(), "restarted");
  await new Promise((resolve) => upstream.close(resolve));
  await waitFor(() => !hasRelay());
  await listen(upstream, "::1", port);
  await waitFor(hasRelay);
  assert.equal((await exchange(address, port, Buffer.from("ipv6-only"))).toString(), "ipv6-only");
  const exited = once(daemon, "exit");
  daemon.kill("SIGTERM");
  assert.deepEqual(await exited, [0, null]);
  assert.equal(hasRelay(), false);
});
