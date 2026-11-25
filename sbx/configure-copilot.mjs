import { lstatSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

function assertJsonObject(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new TypeError("Expected a JSON object");
  }
  return value;
}

function readConfig(path) {
  let content = "{}";
  if (lstatSync(path, { throwIfNoEntry: false })) {
    path = realpathSync(path);
    content = readFileSync(path, "utf8");
  }
  return { path, data: assertJsonObject(JSON.parse((content || "{}").replace(/^\uFEFF/, ""))) };
}

function updateFileSync(path, update) {
  const config = readConfig(path);
  path = config.path;
  const data = assertJsonObject(update(config.data));
  mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  const tmp = mkdtempSync(join(dirname(path), ".copilot-config-"));
  try {
    const file = join(tmp, "config.json");
    writeFileSync(file, JSON.stringify(data, null, 2) + "\n", { mode: 0o600, flag: "wx" });
    renameSync(file, path);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

try {
  const placeholder = process.env.COPILOT_GITHUB_TOKEN;
  const baseUrl = process.env.PI_COPILOT_BASE_URL;
  if (placeholder !== "proxy-managed" ||
      !/^https:\/\/api\.([a-z0-9-]+\.)?githubcopilot\.com$/.test(baseUrl || "")) {
    throw new Error("Invalid proxy configuration");
  }
  const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");

  // shortcut: one Pi instance per sandbox; add locking if concurrent writers are supported.
  updateFileSync(join(agentDir, "auth.json"), (content) => {
    content["github-copilot"] = { type: "api_key", key: placeholder };
    return content;
  });

  updateFileSync(join(agentDir, "models.json"), (content) => {
    const providers = assertJsonObject(content.providers ?? {});
    const copilot = assertJsonObject(providers["github-copilot"] ?? {});
    if (copilot.models !== undefined) {
      if (!Array.isArray(copilot.models)) throw new Error("Expected a models array");
      for (const model of copilot.models) {
        assertJsonObject(model);
        if (Object.hasOwn(model, "baseUrl")) model.baseUrl = baseUrl;
      }
    }
    providers["github-copilot"] = { ...copilot, baseUrl };
    content.providers = providers;
    return content;
  });
} catch {
  // Parse errors may include credential text; never print the underlying error.
  console.error("Cannot configure sandbox Copilot proxy; check proxy settings and auth.json/models.json.");
  process.exitCode = 1;
}
