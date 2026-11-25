# Sandbox shell with Pi

`sbup` launches the Sandbox Kit in this directory, configures the existing
GitHub/Copilot credential proxies, restores the shared dotfiles, and opens Bash. Start Pi
manually with `pi` when you need it.

`sbx/spec.yaml` uses `docker.io/sbx/shell-docker-image:latest` rather than the
Pi base image. The base supplies the agent user, proxy environment, Docker,
Node.js, Python, Go, and Java. This kit adds Pi, pnpm, nvm v0.41.0, Neovim,
git-delta, tig, peco, fd, Starship v1.27.0, and Cymbal v0.18.0, preserving the
previous development tools without rebuilding the base environment itself.

On each launch, `entrypoint.sh` clones or updates `~/dotfiles` from `master`
and installs the previous sandbox links: Starship, Neovim, Pi settings and
AGENTS.md, Git config/ignore, and tig config. It retains sbx's other Git settings
while pointing its global ignore setting at the linked XDG ignore file.
Existing regular config files and conflicting local edits are not overwritten;
initialization failures prevent entry into Bash.

`bashrc.sh` loads the persistent sandbox environment and shared nvm loader.
Interactive shells also load `bash/base.sh` and `bash/tools.sh`, restoring
aliases, history helpers, and the Starship prompt. Non-interactive Bash loads
the same environment quietly through `BASH_ENV`. Startup uses a non-login shell
to retain the initialized PATH. Tini is not used as a session wrapper because
sbx already supplies init.

Host authentication proxies, restricted GitHub SSH-agent access, the runtime
network allowlist, and Pi OSC52 clipboard behavior remain unchanged.
Reattachment updates dotfiles, but does not install or update image tools.

## Commands

| Command | Purpose |
| --- | --- |
| `sbup [id] [sbx arguments...]` | Create or reattach to the sandbox, then enter Bash. |
| `sbbash [id] [bash arguments...]` | Open another shell in the same sandbox. |
| `sbstatus [id] [sbx arguments...]` | Show sandbox state via `sbx inspect`. |
| `sbdown [id] [sbx arguments...]` | Stop the sandbox without removing it. |
| `sbpmap [--id ID] [HOST_PORT:SANDBOX_PORT \| SANDBOX_PORT]` | Publish a listener on host loopback; without a port, select one. |

Sandbox names are `sbx-<directory>-<id>`. The ID falls back to
`HERDR_WORKSPACE_ID`; outside Herdr, provide it explicitly. `sbup` keeps
`--clone`, so the project uses a private sandbox clone.

```bash
sbup manual
# Inside the sandbox:
pi
exit

# From the host:
sbup manual --publish 3000:3000
sbup manual -- -c 'node --version'
sbbash manual -lc 'node --version'
sbstatus manual --format json
```

`sbup` forwards sbx flags and extra workspaces after the ID. Arguments after
`--` are passed to Bash, not Pi.

## Host authentication

Authenticate on the host before launching:

```bash
gh auth login
pi auth login github-copilot
```

`PI_CODING_AGENT_DIR`, when set, selects the host's Pi authentication folder.
Token resolution or secret registration failures prevent launch. Host Pi is
still required to resolve and refresh Copilot tokens; the sandbox installs its
own Pi separately.

On every `sbup` launch, two sandbox-scoped custom secrets are registered:

| Sandbox variable | Host resolver | Target hosts |
| --- | --- | --- |
| `GH_TOKEN` | `gh auth token` | `api.github.com`, `github.com` |
| `COPILOT_GITHUB_TOKEN` | `pi auth print-bearer-token --provider github-copilot --min-expiry 5m` | Copilot API host derived from the token |

Only placeholders enter the sandbox. The proxy replaces them in request headers
for the corresponding hosts; host OAuth credentials are never copied into the
sandbox. The Copilot proxy caches the token for one minute. Its resolver pins
the host Pi executable, home, PATH, and config folder; keep these paths outside
writable sandbox mounts.

Before Bash opens, `sbx/entrypoint.sh` runs the image's copy of
`sbx/configure-copilot.mjs`. It updates sandbox `auth.json` with the Copilot
API-key placeholder and `models.json` with the host-derived API endpoint,
preserving other providers and settings. Each file is validated and replaced
atomically using a private temporary file. If the models update fails, the auth
update remains, but Bash does not launch. Errors never print credential content.
Direct kit launches without `PI_COPILOT_BASE_URL` skip proxy configuration.

## Herdr

`sbup` preserves `HERDR_AGENT=pi` on the host's `sbx run` process so Herdr can
identify Pi even though startup now opens Bash. It does not change the caller's
environment. Pi screen detection still depends on Herdr's built-in rules and,
on macOS, Herdr 0.9.0 or newer, including the running server.

Inside Herdr, `sbup` renames the calling workspace to the sandbox name before
launch. An explicit sandbox ID still renames the calling workspace, not the
workspace identified by that ID. Rename failures do not prevent launch or alter
its exit status.

## Migration and limitations

Reload the host shortcuts:

```bash
source "$HOME/Devs/dotfiles/bash/sandbox.sh"
```

`sbpi` is removed, and `sbstop` has been renamed to `sbdown`. New `sbx-...` names avoid reusing the old `pi-sbx-...`
sandboxes and their custom entrypoint. Existing sandboxes are not stopped or
removed automatically. The shortcuts, including `sbpmap`, now target only the
new names; use `sbx` directly to manage old sandboxes. If you already created an
`sbx-...` sandbox before this dotfiles restoration, use a new ID or explicitly
recreate that sandbox to pick up this kit's image, Bash config, and entrypoint.
Stopping and reattaching does not update an existing image.

- One Pi instance per sandbox; concurrent configuration writers are unsupported.
- Placeholder authentication does not filter models against the host OAuth
  account's catalog; choose a model enabled for that account.
- Only `githubcopilot.com` endpoints are accepted; custom Enterprise domains are
  unsupported.
- `sbx secret set-custom` is experimental.
