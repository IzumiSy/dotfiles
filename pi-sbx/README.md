# Pi sandbox

Pi runs in an `sbx` sandbox with host-managed GitHub and Copilot credentials.

## Commands

| Command | Purpose |
| --- | --- |
| `sbpi [id] [sbx arguments...]` | Start Pi or reattach to its sandbox. |
| `sbbash [id] [bash arguments...]` | Open a shell in the same sandbox. |
| `sbstatus [id] [sbx arguments...]` | Show sandbox state and details via `sbx inspect`. |
| `sbstop [id] [sbx arguments...]` | Stop the sandbox without removing it. |

All commands select the sandbox using the current directory and ID. The ID
falls back to `HERDR_WORKSPACE_ID`; outside Herdr, provide it explicitly.
Arguments after the ID are forwarded to the underlying command. For example:

```bash
sbpi manual -- --continue
sbstatus manual --json
```

## Interactive Bash tools

The image includes starship v1.27.0 and peco. `sbbash` loads the shared
`bash/tools.sh` and `_starship.toml`, enabling the Starship prompt, `pco` for
branch selection, and `hist` for selecting and rerunning a history entry.

Recreate existing sandboxes to receive the new tools and updated `.bashrc`.

## Node.js version management

The image installs nvm v0.41.0 in `~/.nvm`. Interactive Bash loads the shared
`bash/nvm.sh`, so `sbbash` can run `nvm install` and `nvm use` immediately.
The base image's Node.js remains unchanged until you select another version.

Non-interactive Bash does not load `.bashrc`; source the shared loader explicitly:

```bash
source "$HOME/dotfiles/bash/nvm.sh"
nvm install --lts
```

Recreate existing sandboxes to receive nvm and the updated `.bashrc`.

## Host authentication setup

Authenticate on the host before launching:

```bash
gh auth login
pi auth login github-copilot
```

`PI_CODING_AGENT_DIR`, when set, selects the host's Pi authentication folder.
Token resolution or secret registration failures prevent launch.

## Credential isolation and refresh

On every launch, `sbpi` registers two sandbox-scoped custom secrets:

| Sandbox variable | Host resolver | Target hosts |
| --- | --- | --- |
| `GH_TOKEN` | `gh auth token` | `api.github.com`, `github.com` |
| `COPILOT_GITHUB_TOKEN` | `pi auth print-bearer-token --provider github-copilot --min-expiry 5m` | Copilot API host derived from the token |

Only placeholders enter the sandbox, including on reattachment. The proxy
replaces them in request headers to the corresponding hosts; host OAuth
credentials are never copied into the sandbox.

Pi handles Copilot token refresh and persistence using its own locking. The
proxy caches that token for one minute, shorter than its five-minute minimum
validity. The derived endpoint allows Business accounts to use their own API
host rather than the default Individual endpoint.

The Copilot resolver pins the host Pi executable, home, PATH, and config folder.
Keep those paths outside writable sandbox mounts.

## Sandbox configuration

Before Pi starts, `configure-copilot.mjs` updates these files in order:

1. **`auth.json`**: replace only the Copilot credential with an API-key placeholder.
   This supersedes any previous sandbox-local Copilot login.
2. **`models.json`**: set the Copilot provider and any explicit model endpoints
   to the host-derived API URL.

Each file is validated before writing and replaced atomically using a private
temporary file. If the models update fails, the auth update remains, but Pi does
not launch. The script uses Node's standard file operations, not Pi internals or
file locking.

Other providers and settings are preserved. Configuration, package, and session
directories remain unchanged.

## Limitations and upgrades

- **Concurrency:** one Pi instance per sandbox; concurrent configuration writers
  are not supported.
- **Models:** placeholder authentication does not filter models using the host
  OAuth account's catalog. Choose a model enabled for that account.
- **Domains:** Copilot endpoints must be under `githubcopilot.com`; custom GitHub
  Enterprise domains are not supported.
- **Compatibility:** `sbx secret set-custom` is experimental.
- **Existing sandboxes:** recreate them to receive the updated entrypoint and
  helper. `sbstop` alone is not sufficient. Nothing is automatically removed.

## Herdr integration

`sbpi` sets `HERDR_AGENT=pi` on the host's `sbx run` process so Herdr can identify
it and use its built-in screen detection. On macOS this requires Herdr 0.9.0 or
newer, including the running server. Detection accuracy depends on Herdr's Pi
rules, especially for approval prompts. No custom relay or Pi extension is used.

Inside Herdr, `sbpi` reports the sandbox name
(`pi-sbx-<directory>-<id>`) as the agent's display name before `sbx run`, then
clears it when the command returns. Metadata failures do not prevent launch or
change the sandbox command's exit status. Workspace/tab names and agent state
are unchanged. This host-only change does not require recreating sandboxes;
reload `bash/sandbox.sh` in the host shell before the next `sbpi` launch.
