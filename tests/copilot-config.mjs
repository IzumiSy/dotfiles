import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { closeSync, existsSync, lstatSync, mkdirSync, mkdtempSync, openSync, readFileSync, readdirSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, test } from "node:test";

const tmp = mkdtempSync(join(tmpdir(), "copilot-config-"));
after(() => rmSync(tmp, { recursive: true, force: true }));
const script = fileURLToPath(new URL("../pi-sbx/configure-copilot.mjs", import.meta.url));
function run(home, extra = {}) {
  return spawnSync(process.execPath, [script], {
    encoding: "utf8",
    env: {
      HOME: home,
      COPILOT_GITHUB_TOKEN: "sbx-copilot-token-proxy-managed",
      PI_COPILOT_BASE_URL: "https://api.business.githubcopilot.com",
      ...extra,
    },
  });
}
function json(path) { return JSON.parse(readFileSync(path, "utf8")); }

test("replaces only Copilot credentials and endpoint, preserving other settings", () => {
  const home = join(tmp, "home with spaces");
  const dir = join(home, ".pi", "agent");
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "auth.json"), JSON.stringify({
    "github-copilot": { type: "oauth", refresh: "old-copilot-secret", access: "old-access", expires: 0 },
    openai: { type: "api_key", key: "other-provider-secret" },
  }));
  writeFileSync(join(dir, "models.json"), JSON.stringify({
    marker: "retained",
    providers: {
      "github-copilot": {
        baseUrl: "https://old.invalid", modelOverrides: { example: { reasoning: true } },
        models: [
          { id: "example", baseUrl: "https://api.individual.githubcopilot.com", reasoning: true },
          { id: "inherited", reasoning: false },
        ],
      },
      ollama: { baseUrl: "http://localhost:11434" },
    },
  }));
  const result = run(home);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "");
  assert.deepEqual(json(join(dir, "auth.json")), {
    "github-copilot": { type: "api_key", key: "sbx-copilot-token-proxy-managed" },
    openai: { type: "api_key", key: "other-provider-secret" },
  });
  assert.deepEqual(json(join(dir, "models.json")), {
    marker: "retained",
    providers: {
      "github-copilot": {
        baseUrl: "https://api.business.githubcopilot.com", modelOverrides: { example: { reasoning: true } },
        models: [
          { id: "example", baseUrl: "https://api.business.githubcopilot.com", reasoning: true },
          { id: "inherited", reasoning: false },
        ],
      },
      ollama: { baseUrl: "http://localhost:11434" },
    },
  });
  assert.equal(run(home).status, 0);
});

test("creates private placeholder config in the overridden agent directory", () => {
  const home = join(tmp, "new home");
  const dir = join(tmp, "config override with spaces");
  const result = run(home, { PI_CODING_AGENT_DIR: dir, PI_COPILOT_BASE_URL: "https://api.individual.githubcopilot.com" });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(json(join(dir, "models.json")).providers["github-copilot"].baseUrl, "https://api.individual.githubcopilot.com");
  assert.equal(statSync(join(dir, "auth.json")).mode & 0o777, 0o600);
  assert.equal(statSync(dir).mode & 0o777, 0o700);
  assert.deepEqual(readdirSync(dir).sort(), ["auth.json", "models.json"]);
  assert.equal(existsSync(join(home, ".pi")), false);
});

test("rejects real tokens and untrusted endpoints before writing configuration", () => {
  for (const extra of [
    { COPILOT_GITHUB_TOKEN: "real-token-must-not-be-written" },
    { PI_COPILOT_BASE_URL: "https://api.business.githubcopilot.com.attacker.invalid" },
    { PI_COPILOT_BASE_URL: "http://api.business.githubcopilot.com" },
  ]) {
    const home = mkdtempSync(join(tmp, "invalid-env-"));
    const result = run(home, extra);
    assert.equal(result.status, 1);
    assert.equal(existsSync(join(home, ".pi")), false);
    assert.equal(result.stdout, "");
    assert.equal(result.stderr.includes("real-token-must-not-be-written"), false);
  }
});

test("invalid auth is preserved and prevents models updates without exposing credentials", () => {
  for (const content of ['{"secret":"must-not-log",', "[]", "null"]) {
    const home = mkdtempSync(join(tmp, "invalid-auth-"));
    const dir = join(home, ".pi", "agent");
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, "auth.json"), content);
    writeFileSync(join(dir, "models.json"), '{"marker":"unchanged"}');
    const result = run(home);
    assert.equal(result.status, 1);
    assert.equal(readFileSync(join(dir, "auth.json"), "utf8"), content);
    assert.equal(readFileSync(join(dir, "models.json"), "utf8"), '{"marker":"unchanged"}');
    assert.deepEqual(readdirSync(dir).sort(), ["auth.json", "models.json"]);
    assert.equal(result.stdout, "");
    assert.equal(result.stderr.includes("must-not-log"), false);
  }
});

test("invalid models are preserved after auth is updated", () => {
  for (const content of [
    '{"secret":"must-not-log",',
    "null",
    '{"providers":[]}',
    '{"providers":{"github-copilot":"invalid"}}',
    '{"providers":{"github-copilot":{"models":{}}}}',
    '{"providers":{"github-copilot":{"models":[null]}}}',
  ]) {
    const home = mkdtempSync(join(tmp, "invalid-models-"));
    const dir = join(home, ".pi", "agent");
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, "models.json"), content);
    writeFileSync(join(dir, "auth.json"), '{"marker":"retained"}');
    const result = run(home);
    assert.equal(result.status, 1);
    assert.equal(readFileSync(join(dir, "models.json"), "utf8"), content);
    assert.deepEqual(json(join(dir, "auth.json")), {
      marker: "retained",
      "github-copilot": { type: "api_key", key: "sbx-copilot-token-proxy-managed" },
    });
    assert.deepEqual(readdirSync(dir).sort(), ["auth.json", "models.json"]);
    assert.equal(result.stdout, "");
    assert.equal(result.stderr.includes("must-not-log"), false);
  }
});

test("replaces files atomically and removes private temporary files", () => {
  const home = join(tmp, "atomic home");
  const dir = join(home, ".pi", "agent");
  mkdirSync(dir, { recursive: true });
  const path = join(dir, "auth.json");
  const original = '{"openai":{"type":"api_key","key":"retained-secret"}}';
  writeFileSync(path, original);
  const fd = openSync(path, "r");
  try {
    const result = run(home);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(readFileSync(fd, "utf8"), original);
    assert.equal(json(path)["github-copilot"].key, "sbx-copilot-token-proxy-managed");
    assert.equal(statSync(path).mode & 0o777, 0o600);
    assert.deepEqual(readdirSync(dir).sort(), ["auth.json", "models.json"]);
  } finally {
    closeSync(fd);
  }
});

test("preserves configuration symlinks and updates their targets", () => {
  const home = join(tmp, "symlink home");
  const dir = join(home, ".pi", "agent");
  const targets = join(home, "external configs");
  mkdirSync(dir, { recursive: true });
  mkdirSync(targets);
  const auth = join(targets, "auth.json");
  const models = join(targets, "models.json");
  writeFileSync(auth, '{"openai":{"type":"api_key","key":"retained-secret"}}');
  writeFileSync(models, '{"marker":"retained"}');
  symlinkSync(auth, join(dir, "auth.json"));
  symlinkSync(models, join(dir, "models.json"));
  const result = run(home);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(lstatSync(join(dir, "auth.json")).isSymbolicLink(), true);
  assert.equal(lstatSync(join(dir, "models.json")).isSymbolicLink(), true);
  assert.equal(json(auth)["github-copilot"].key, "sbx-copilot-token-proxy-managed");
  assert.equal(json(auth).openai.key, "retained-secret");
  assert.equal(json(models).marker, "retained");
  assert.deepEqual(readdirSync(targets).sort(), ["auth.json", "models.json"]);
});

test("a broken configuration symlink is not replaced", () => {
  const home = join(tmp, "broken symlink home");
  const dir = join(home, ".pi", "agent");
  mkdirSync(dir, { recursive: true });
  symlinkSync("missing.json", join(dir, "auth.json"));
  const models = join(dir, "models.json");
  writeFileSync(models, '{"marker":"unchanged"}');
  const result = run(home);
  assert.equal(result.status, 1);
  assert.equal(lstatSync(join(dir, "auth.json")).isSymbolicLink(), true);
  assert.equal(readFileSync(models, "utf8"), '{"marker":"unchanged"}');
  assert.equal(existsSync(join(dir, "missing.json")), false);
});
