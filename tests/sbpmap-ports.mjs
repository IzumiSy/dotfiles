import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, unlinkSync, writeFileSync } from "node:fs";
import { endianness, tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import { scan } from "../sbx/sbpmap-ports.mjs";

const tmp = mkdtempSync(join(tmpdir(), "sbpmap-ports-"));
after(() => rmSync(tmp, { recursive: true, force: true }));
const header = "sl local_address rem_address st tx_queue tr retrnsmt uid timeout inode\n";
function fixture() {
  const root = mkdtempSync(join(tmp, "proc-"));
  mkdirSync(join(root, "net"));
  return root;
}
function tcpRow(address, port, inode, state = "0A") {
  const bytes = Buffer.from(address.split(".").map(Number));
  if (endianness() === "LE") bytes.reverse();
  return `0: ${bytes.toString("hex")}:${port.toString(16).padStart(4, "0")} 00000000:0000 ${state} 0:0 00:0 0 1000 0 ${inode}\n`;
}
function processFiles(root, pid, name, inodes) {
  const directory = join(root, String(pid));
  mkdirSync(join(directory, "fd"), { recursive: true });
  if (name !== null) writeFileSync(join(directory, "comm"), name);
  for (const [number, inode] of inodes.entries()) {
    symlinkSync(`socket:[${inode}]`, join(directory, "fd", String(number)));
  }
}

test("scans IPv4 listeners, deduplicates owners and tolerates missing process files", () => {
  const root = fixture();
  writeFileSync(join(root, "net/tcp"), header +
    tcpRow("192.168.1.5", 65535, 30) + tcpRow("0.0.0.0", 3000, 10) +
    tcpRow("0.0.0.0", 3000, 11) + tcpRow("127.0.0.2", 8000, 20) +
    tcpRow("127.0.0.1", 5432, 40, "01") + tcpRow("0.0.0.0", 5173, 50) + "short row\n");
  processFiles(root, 100, "node\n", [10, 11]);
  processFiles(root, 101, "node\n", [10]);
  processFiles(root, 102, "py\tworker\x1b\n", [20]);
  processFiles(root, 103, null, [30]);
  mkdirSync(join(root, "104"));
  processFiles(root, 105, "other\n", []);
  writeFileSync(join(root, "105/fd/0"), "not a socket symlink");
  processFiles(root, 106, " \x00\n", [50]);
  processFiles(root, "not-a-pid", "ignored\n", [10]);
  const expected = [
    { port: 3000, address: "0.0.0.0", process: "node", loopback: false },
    { port: 5173, address: "0.0.0.0", process: "-", loopback: false },
    { port: 8000, address: "127.0.0.2", process: "py worker", loopback: true },
    { port: 65535, address: "192.168.1.5", process: "-", loopback: false },
  ];
  assert.deepEqual(scan(root), expected);
  processFiles(root, 107, "another\n", [10]);
  assert.deepEqual(scan(root), [{ ...expected[0], process: "another" }, ...expected]);
});

test("distinguishes an empty table from a missing or malformed table", () => {
  const root = fixture();
  const tcp = join(root, "net/tcp");
  writeFileSync(tcp, header);
  assert.deepEqual(scan(root), []);
  writeFileSync(tcp, header + "0: ZZZZZZZZ:0BB8 00000000:0000 0A 0:0 00:0 0 1000 0 10\n");
  assert.throws(() => scan(root), /Invalid IPv4 TCP listener address/);
  unlinkSync(tcp);
  assert.throws(() => scan(root), { code: "ENOENT" });
});

test("runs as a file and through ESM stdin without importing project modules", () => {
  const root = fixture();
  writeFileSync(join(root, "net/tcp"), header + tcpRow("0.0.0.0", 3000, 10));
  const shadow = join(root, "shadow");
  mkdirSync(shadow);
  writeFileSync(join(shadow, "package.json"), '{"type":"commonjs"}');
  writeFileSync(join(shadow, "fs.js"), 'throw new Error("project fs.js imported");\n');
  const source = readFileSync(new URL("../sbx/sbpmap-ports.mjs", import.meta.url), "utf8");
  // Change only the default proc root so the CLI can be checked on macOS too.
  assert.ok(source.includes('procRoot = "/proc"'));
  const input = source.replace('procRoot = "/proc"', `procRoot = ${JSON.stringify(root)}`);
  const script = join(tmp, "scanner.mjs");
  writeFileSync(script, input);
  for (const args of [[script], ["--input-type=module", "-"]]) {
    const run = () => spawnSync(process.execPath, args, {
      input, cwd: shadow, env: { ...process.env, NODE_PATH: shadow }, encoding: "utf8",
    });
    const result = run();
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), [
      { port: 3000, address: "0.0.0.0", process: "-", loopback: false },
    ]);
    unlinkSync(join(root, "net/tcp"));
    const failure = run();
    assert.equal(failure.status, 1);
    assert.equal(failure.stdout, "");
    assert.match(failure.stderr, /Cannot inspect sandbox TCP listeners:.*ENOENT/);
    writeFileSync(join(root, "net/tcp"), header + tcpRow("0.0.0.0", 3000, 10));
  }
});
