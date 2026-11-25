import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const script = fileURLToPath(new URL("../herdr/workspace-tools/workflow.mjs", import.meta.url));

function fixture(t) {
  const tmp = mkdtempSync(join(tmpdir(), "herdr-tools-"));
  t.after(() => rmSync(tmp, { recursive: true, force: true }));
  const home = join(tmp, "home with 'quotes'");
  const cwd = join(home, "project");
  const bin = join(tmp, "bin");
  mkdirSync(cwd, { recursive: true });
  mkdirSync(bin);
  const mock = join(bin, "mock");
  writeFileSync(mock, `#!${process.execPath}
import { appendFileSync, mkdirSync } from 'node:fs';
import { basename } from 'node:path';
const command = basename(process.argv[1]);
const args = process.argv.slice(2);
appendFileSync(process.env.LOG, JSON.stringify({command, args}) + '\\n');
if (process.env.FAIL === command || process.env.FAIL === args.slice(0, 2).join(' ')) {
  console.error('test backend failure'); process.exit(17);
}
if (command === 'sbx') console.log(process.env.SANDBOXES || '[]');
if (command === 'gh') mkdirSync(args[3]);
if (command === 'herdr') {
  const result = args[1] === 'create'
    ? {workspace: {workspace_id: 'w99'}, root_pane: {pane_id: 'w99:p1'}}
    : {type: 'ok'};
  console.log(JSON.stringify({result}));
}
`);
  chmodSync(mock, 0o755);
  // The stub uses ESM regardless of the invoked binary name.
  writeFileSync(join(bin, "package.json"), '{"type":"module"}');
  for (const command of ["herdr", "sbx", "gh"]) symlinkSync(mock, join(bin, command));
  const log = join(tmp, "log");
  return {
    home, cwd,
    run(mode, input = "", env = {}, context = { workspace_id: "w12", workspace_cwd: cwd }) {
      writeFileSync(log, "");
      const result = spawnSync(process.execPath, [script, mode], {
        input, encoding: "utf8",
        env: { ...process.env, HOME: home, PATH: `${bin}:${process.env.PATH}`, LOG: log,
          HERDR_BIN_PATH: join(bin, "herdr"), HERDR_PLUGIN_ID: "dotfiles.workspace-tools",
          HERDR_PLUGIN_CONTEXT_JSON: JSON.stringify(context), ...env },
      });
      const calls = readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse);
      return { ...result, calls };
    },
  };
}

const callsFor = (result, command, verb) => result.calls.filter((call) => call.command === command && (!verb || call.args.slice(0, 2).join(" ") === verb));

// Execute the injected shell text with mock functions to check both layers of quoting and cwd.
function checkShell(command, expectedCommand, expectedCwd, expectedId) {
  const args = spawnSync("/bin/bash", ["-c", `function bash() { printf '%s' "$2"; }; ${command}`], { encoding: "utf8" });
  assert.equal(args.status, 0, args.stderr);
  const result = spawnSync("/bin/bash", ["-c", `function source() { :; }; function ${expectedCommand}() { printf '%s\\n%s' "$PWD" "$1"; }; ${args.stdout}`], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  const [cwd, id] = result.stdout.split("\n");
  assert.equal(realpathSync(cwd), realpathSync(expectedCwd));
  assert.equal(id, expectedId);
}

test("workspace action opens the manifest popup", (t) => {
  const result = fixture(t).run("new-workspace");
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.calls[0].args, ["plugin", "pane", "open", "--plugin", "dotfiles.workspace-tools", "--entrypoint", "picker"]);
});

test("default local workspace keeps the normal shell; cancel creates nothing", (t) => {
  const f = fixture(t);
  const result = f.run("picker", "\n\n");
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.calls[0].args, ["workspace", "create", "--cwd", realpathSync(f.cwd), "--label", "project", "--focus"]);
  for (const input of ["q\n", "", "2\n"]) assert.equal(f.run("picker", input).calls.length, 0);
});

test("local picker expands ~ and rejects files/missing directories", (t) => {
  const f = fixture(t);
  assert.equal(f.run("picker", "1\n~\n").calls[0].args[3], realpathSync(f.home));
  writeFileSync(join(f.home, "file"), "do not overwrite");
  for (const path of ["~/file", "~/missing"]) {
    const result = f.run("picker", `1\n${path}\n`);
    assert.equal(result.status, 1);
    assert.equal(callsFor(result, "herdr", "workspace create").length, 0);
  }
});

test("GitHub clone opens Pi with an explicit, safely quoted cwd and ID", (t) => {
  const f = fixture(t);
  const result = f.run("picker", "2\nhttps://github.com/owner/my_repo.git\n");
  assert.equal(result.status, 0, result.stderr);
  const cwd = join(f.home, ".herdr-workspaces", "owner", "my-repo");
  assert.deepEqual(callsFor(result, "gh")[0].args, ["repo", "clone", "owner/my_repo", cwd]);
  assert.equal(callsFor(result, "herdr", "workspace create")[0].args[3], cwd);
  checkShell(callsFor(result, "herdr", "pane run")[0].args[3], "sbpi", cwd, "w99");
  const again = f.run("picker", "2\nowner/my_repo\n");
  assert.equal(again.status, 1);
  assert.match(again.stderr, /already exists/);
  assert.equal(callsFor(again, "gh").length, 0);
});

test("GitHub rejects unsafe input and preserves symlink destinations", (t) => {
  const f = fixture(t);
  for (const repo of ["owner/..", "owner/.", "../repo", "--flag/repo", "https://evil.invalid/owner/repo", "owner/repo;echo evil"]) {
    const result = f.run("picker", `2\n${repo}\n`);
    assert.equal(result.status, 1);
    assert.equal(callsFor(result, "gh").length, 0);
  }
  const parent = join(f.home, ".herdr-workspaces", "owner");
  mkdirSync(parent, { recursive: true });
  symlinkSync(join(f.home, "missing"), join(parent, "repo"));
  const result = f.run("picker", "2\ngit@github.com:owner/repo.git\n");
  assert.equal(result.status, 1);
  assert.match(result.stderr, /already exists/);
  assert.equal(callsFor(result, "gh").length, 0);
});

test("clone and workspace creation failures prevent later launch", (t) => {
  const f = fixture(t);
  for (const fail of ["gh", "workspace create"]) {
    const result = f.run("picker", `2\nowner/${fail === "gh" ? "first" : "second"}\n`, { FAIL: fail });
    assert.equal(result.status, 1);
    assert.equal(callsFor(result, "herdr", "pane run").length, 0);
    if (fail === "gh") assert.equal(callsFor(result, "herdr", "workspace create").length, 0);
  }
});

test("new tabs attach existing running or stopped sandboxes from subdirectories", (t) => {
  const f = fixture(t);
  mkdirSync(join(f.cwd, "subdir"));
  for (const status of ["running", "stopped"]) {
    const sandbox = { name: `pi-sbx-${basename(f.cwd)}-w12`, status, workspaces: [f.cwd] };
    const result = f.run("new-tab", "", { SANDBOXES: JSON.stringify([sandbox]) }, { workspace_id: "w12", workspace_cwd: join(f.cwd, "subdir") });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(callsFor(result, "herdr", "tab create")[0].args, ["tab", "create", "--workspace", "w12", "--cwd", f.cwd, "--focus"]);
    checkShell(callsFor(result, "herdr", "pane run")[0].args[3], "sbbash", f.cwd, "w12");
  }
});

test("non-sandbox tabs use Herdr's normal cwd policy, not another workspace's sandbox", (t) => {
  const f = fixture(t);
  const sandboxes = [
    { name: "pi-sbx-project-w13", workspaces: [f.cwd] },
    { name: "pi-sbx-project-w12", workspaces: [join(f.home, "unrelated", "project")] },
  ];
  const result = f.run("new-tab", "", { SANDBOXES: JSON.stringify(sandboxes) });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(callsFor(result, "herdr", "tab create")[0].args, ["tab", "create", "--workspace", "w12", "--focus"]);
  assert.equal(callsFor(result, "herdr", "pane run").length, 0);
});

test("sandbox backend failures, ambiguity, and absent context do not open host tabs", (t) => {
  const f = fixture(t);
  const parent = { name: `pi-sbx-${basename(f.home)}-w12`, workspaces: [f.home] };
  const child = { name: "pi-sbx-project-w12", workspaces: [f.cwd] };
  for (const [env, context] of [
    [{ FAIL: "sbx" }, undefined],
    [{ SANDBOXES: JSON.stringify([parent, child]) }, undefined],
    [{}, {}],
  ]) {
    const result = f.run("new-tab", "", env, context);
    assert.equal(result.status, 1);
    assert.equal(callsFor(result, "herdr", "tab create").length, 0);
  }
  assert.ok(existsSync(f.cwd));
});
