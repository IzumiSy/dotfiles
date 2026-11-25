import { spawnSync } from "node:child_process";
import { lstatSync, mkdirSync, realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, relative, resolve } from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";

const herdr = process.env.HERDR_BIN_PATH || "herdr";
const context = JSON.parse(process.env.HERDR_PLUGIN_CONTEXT_JSON || "{}");
const shortcuts = resolve(dirname(fileURLToPath(import.meta.url)), "../../bash/sandbox.sh");
const quote = (value) => `'${value.replaceAll("'", "'\\''")}'`;

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${command} failed: ${result.stderr?.trim() || result.signal || result.status}`);
  }
  return result.stdout;
}

function api(args) {
  const response = JSON.parse(run(herdr, args));
  if (response.error) throw new Error(response.error.message);
  return response.result;
}

function shellCommand(pane, command, id, cwd) {
  const script = `cd -- ${quote(cwd)} && source ${quote(shortcuts)} && ${command} ${quote(id)}`;
  api(["pane", "run", pane, `bash -lc ${quote(script)}`]);
}

async function picker() {
  const lines = createInterface({ input: process.stdin, terminal: false });
  const input = lines[Symbol.asyncIterator]();
  const ask = async (prompt) => {
    process.stdout.write(prompt);
    const line = await input.next();
    return line.done ? null : line.value.trim();
  };
  try {
    console.log("Open a local directory or clone a GitHub repository into a Pi sandbox.\n\n  1) Local directory (default)\n  2) GitHub repository + Pi sandbox\n  q) Cancel\n");
    const mode = await ask("Select [1]: ");
    if (mode === null || mode === "q") return;
    let cwd;
    let label;
    if (mode === "" || mode === "1") {
      const fallback = context.focused_pane_cwd || context.workspace_cwd || homedir();
      const path = await ask(`Directory [${fallback}]: `);
      if (path === null) return;
      const selected = path || fallback;
      cwd = realpathSync(resolve(fallback, selected === "~" ? homedir() : selected.replace(/^~\//, `${homedir()}/`)));
      if (!statSync(cwd).isDirectory()) throw new Error("Select an existing directory.");
      label = basename(cwd) || cwd;
    } else if (mode === "2") {
      const value = await ask("GitHub repository (owner/repo or GitHub URL): ");
      if (value === null) return;
      const repo = value.replace(/^(https:\/\/github\.com\/|git@github\.com:)/, "").replace(/\/$/, "").replace(/\.git$/, "");
      if (!/^[A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9_.-]+$/.test(repo) || [".", ".."].includes(repo.split("/")[1])) {
        throw new Error("Use owner/repo or a github.com HTTPS/SSH URL.");
      }
      const [owner, name] = repo.split("/");
      // Keep the checkout basename compatible with sbpi's sandbox name and length limit.
      const directory = name.replace(/[^A-Za-z0-9-]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40).replace(/-+$/, "");
      if (!directory) throw new Error("Repository name needs a letter or number.");
      cwd = join(homedir(), ".herdr-workspaces", owner, directory);
      try {
        lstatSync(cwd);
        throw new Error(`Clone destination already exists; nothing overwritten: ${cwd}`);
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
      }
      mkdirSync(dirname(cwd), { recursive: true });
      run("gh", ["repo", "clone", repo, cwd], { stdio: ["ignore", "inherit", "inherit"] });
      label = repo;
    } else {
      throw new Error("Select 1, 2, or q.");
    }
    const created = api(["workspace", "create", "--cwd", cwd, "--label", label, "--focus"]);
    if (mode === "2") shellCommand(created.root_pane.pane_id, "sbpi", created.workspace.workspace_id, cwd);
  } finally {
    lines.close();
  }
}

function newTab() {
  const id = context.workspace_id || process.env.HERDR_WORKSPACE_ID;
  const cwd = context.workspace_cwd || context.focused_pane_cwd;
  if (!id || !cwd) throw new Error("Select a workspace before opening a tab.");
  const sandboxes = JSON.parse(run("sbx", ["ls", "--json"]));
  // Herdr's workspace_cwd follows its focused pane, so also match checkout ancestors.
  const matches = sandboxes.flatMap((sandbox) => (sandbox.workspaces || []).filter((root) => {
    const path = relative(root, cwd);
    return sandbox.name === `pi-sbx-${basename(root)}-${id}` &&
      (path === "" || (path !== ".." && !path.startsWith("../")));
  }));
  if (matches.length > 1) throw new Error("Multiple sandboxes match this workspace; attach with sbbash explicitly.");
  if (matches.length === 1) {
    const root = matches[0];
    const created = api(["tab", "create", "--workspace", id, "--cwd", root, "--focus"]);
    shellCommand(created.root_pane.pane_id, "sbbash", id, root);
  } else {
    // Let Herdr apply its normal follow-cwd policy for non-sandbox tabs.
    api(["tab", "create", "--workspace", id, "--focus"]);
  }
}

try {
  switch (process.argv[2]) {
    case "new-workspace":
      api(["plugin", "pane", "open", "--plugin", process.env.HERDR_PLUGIN_ID, "--entrypoint", "picker"]);
      break;
    case "picker":
      await picker();
      break;
    case "new-tab":
      newTab();
      break;
    default:
      throw new Error("Expected new-workspace, picker, or new-tab.");
  }
} catch (error) {
  console.error(error.message);
  try {
    api(["notification", "show", "Workspace tools failed", "--body", error.message]);
  } catch {
    // The original failure remains in the plugin log if Herdr is unavailable.
  }
  process.exitCode = 1;
}
