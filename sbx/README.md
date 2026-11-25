# Sandbox shell with Pi

`sbup` initializes the Sandbox Kit in this directory, including the
GitHub/Copilot credential proxies and shared dotfiles, then calls `sbbash`.
The interactive shell uses `sbx exec -it -w "$PWD"`, just like a direct
`sbbash` call. Start Pi manually with `pi` when you need it.

`sbx/spec.yaml` uses `docker.io/sbx/shell-docker-image:latest`. The base supplies
the agent user, proxy environment, Docker, Node.js, Python, Go, and Java.
This kit adds Pi, pnpm, the agent-browser CLI, nvm v0.41.0, Neovim, git-delta,
tig, peco, fd, Starship v1.27.0, and Cymbal v0.18.0.
Node.js LTS Jod, Krypton, and Lithium are installed through nvm; Krypton is the
default and is activated when the shared nvm loader initializes a new shell.
Chromium is copied from `mcr.microsoft.com/playwright:v1.64.1-noble`, which
supports Linux ARM64 and AMD64. Only Chromium is copied; its system dependencies
are installed with the matching Playwright version. agent-browser uses it via
`AGENT_BROWSER_EXECUTABLE_PATH=/usr/local/bin/chromium`, so no
`agent-browser install` or runtime browser download is needed.

On each launch, `entrypoint.sh` clones or updates `~/dotfiles` from `master`
and installs links for Starship, Neovim, Pi settings and
AGENTS.md, Git config/ignore, and tig config. It retains sbx's other Git settings
while pointing its global ignore setting at the linked XDG ignore file.
Existing regular config files and conflicting local edits are not overwritten;
initialization failures prevent entry into Bash. `sbup` runs the entrypoint
with `bash -c :` to complete setup without opening an agent-session shell.

`bashrc.sh` loads the persistent sandbox environment and shared nvm loader.
Interactive shells also load `bash/base.sh` and `bash/tools.sh` for aliases,
history helpers, and the Starship prompt. Non-interactive Bash loads
the same environment quietly through `BASH_ENV`. Startup uses a non-login shell
to retain the initialized PATH. Tini is not used as a session wrapper because
sbx already supplies init.

The kit uses host authentication proxies, restricted GitHub SSH-agent access,
a runtime network allowlist, and Pi OSC52 clipboard support.
Reattachment updates dotfiles, but does not install or update image tools.

## Commands

| Command | Purpose |
| --- | --- |
| `sbup [id] [sbx arguments...] [-- bash arguments...]` | Initialize the sandbox, then enter it via `sbbash`. |
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

`sbup` forwards sbx flags and extra workspaces after the ID to initialization.
Arguments after `--` are passed to the final Bash shell, not Pi. Since `sbup`
always opens a shell, use `sbx` directly for `--detach` or `--rm`.

## Localhost services

A `com.docker.sandbox/lifecycle@1` startup hook runs `/opt/loopback-proxy.mjs`
independently of shell sessions. Every second it discovers loopback-only TCP
listeners and relays them on the default-route IPv4 address at the **same
port**. The application keeps its original bind address. IPv4 loopback and
IPv6 `::1` upstreams are supported; the relay's external side is IPv4.

Host publication stays explicit. Wait about a second after starting the app:

```bash
sbpmap 3000        # Allocate a free host port; read the printed mapping.
sbpmap 8080:3000   # Or use http://127.0.0.1:8080.
```

Read proxy logs from the host with:

```bash
sbx exec <sandbox-name> tail -n 50 /home/agent/loopback-proxy.log
```

Ports with other non-loopback listeners or ambiguous loopback addresses are
skipped. IPv4 wins when both IPv4 and IPv6 localhost listen on the same port.
The proxy releases listeners when their upstream disappears and prevents
duplicate daemon instances. Removing a listener preserves existing connections;
stopping the daemon closes them.

All eligible TCP services are bridged, including databases and debug/admin
interfaces. They are **not automatically published to the host**. Keep host
bindings on `127.0.0.1` and publish only services you need.

Limits: Linux with Node.js 20.8+ (abstract Unix socket support), one default-route
IPv4 ingress address, TCP only. The proxy does not change application Host/Origin
checks or advertised HMR URLs, supervise its own crashes, or keep the sandbox
alive after its last session disconnects. When switching an app from loopback to
wildcard binding, stop it and wait for the relay to disappear before restarting.

`node --test tests/loopback-proxy.mjs` checks parsing, selection and TCP transport
on macOS and Linux; Linux also exercises the daemon's discovery, IPv6 upstreams,
restart, locking and shutdown. These tests are included in `bash tests/run`.

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

On every `sbup` launch, two sandbox-scoped service sources are registered with
`sbx secret set --force --command`. Their presentation is declared by
`com.docker.sandbox/credential@1` in `spec.yaml`:

| Service | Sandbox variable | Host resolver | Target hosts |
| --- | --- | --- | --- |
| `github` | `GH_TOKEN` | `gh auth token` | `api.github.com`, `github.com` |
| `pi-copilot` | `COPILOT_GITHUB_TOKEN` | `pi auth print-bearer-token --provider github-copilot --min-expiry 5m` | Copilot API host derived from the token |

`sbup` passes the detected host as `--kit-arg copilot_host=...`; the Kit uses
that exact host for both credential injection and network access. Its managed
host and endpoint flags come after forwarded arguments so they stay aligned.
GitHub resolves on demand; the Copilot source caches the token for one minute.
The Copilot resolver pins the host Pi executable, home, PATH, and config folder;
keep these paths outside writable sandbox mounts.

sbx supplies the `proxy-managed` sentinel to both variables; `sbup` does not
set credential variables itself. The proxy writes the real bearer into the
Authorization header only for the declared target hosts. Host OAuth credentials
are never copied into the sandbox.

Before Bash opens, `sbx/entrypoint.sh` runs the image's copy of
`sbx/configure-copilot.mjs`. It updates sandbox `auth.json` with the Copilot
API-key placeholder and `models.json` with the host-derived API endpoint,
preserving other providers and settings. Each file is validated and replaced
atomically using a private temporary file. If the models update fails, the auth
update remains, but Bash does not launch. Errors never print credential content.
Direct kit launches also require `--kit-arg copilot_host=...`; without
`PI_COPILOT_BASE_URL`, they skip Pi's proxy configuration.

### Credential approval and migration

On the first interactive launch, approve this local Kit's use of both services:
`github` for `api.github.com` and `github.com`, and `pi-copilot` for the selected
Copilot API host. sbx records approvals in `~/.config/sbx/credentials.yaml`;
this file contains permissions, not tokens. Approve interactively before running
unattended. Registering a source with `secret set` does not grant this approval.
sbx may start with a required credential withheld and a warning when no binding
exists; missing Copilot wiring fails configuration, and `sbup` opens its usual
debug shell rather than silently configuring an unauthenticated provider.

This migration requires a **new sandbox**, for example `sbup service-auth`.
Stopping and reattaching an old sandbox does not replace its credential
declarations or image-local configurator. Existing sandboxes and their custom
secrets are not automatically changed or removed. After moving any work you need,
explicitly remove an obsolete sandbox to delete its sandbox-scoped old secrets.

The service flow and `proxy-managed` sentinel were verified with sbx v0.54.1.

## Herdr

`sbup` sets `HERDR_AGENT=pi` on both initialization and the final shell's host
`sbx` processes so Herdr can identify Pi. It does not change the caller's
environment. Pi screen detection still depends on Herdr's built-in rules and,
on macOS, Herdr 0.9.0 or newer, including the running server.

Inside Herdr, `sbup` renames the calling workspace to the sandbox name before
launch. An explicit sandbox ID still renames the calling workspace, not the
workspace identified by that ID. Rename failures do not prevent launch or alter
its exit status.

## Limitations

- Image, Bash config, and entrypoint changes require a new sandbox. Stopping and
  reattaching does not update an existing image.

- One Pi instance per sandbox; concurrent configuration writers are unsupported.
- Placeholder authentication does not filter models against the host OAuth
  account's catalog; choose a model enabled for that account.
- Only `githubcopilot.com` endpoints are accepted; custom Enterprise domains are
  unsupported.
- Kit v3 remains experimental; service credentials avoid the `set-custom`
  command's experimental warning, not all possible Kit or approval warnings.
