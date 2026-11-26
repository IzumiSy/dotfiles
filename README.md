# dotfiles
> There is no place like home 

![Enjoy](http://cdn.tinybuddha.com/wp-content/uploads/2015/01/Enjoy.jpg)

## Setup

```bash
./setup install
./setup uninstall

# Select links by their source paths in setup's LINKS list.
./setup install nvim pi/AGENTS.md pi/settings.json
./setup install git/config git/ignore
./setup uninstall nvim
```

`./setup` without arguments defaults to `install`. Without link arguments, all links are selected. Unknown link names fail before any changes are made.

## Sandbox

`sbup [id]` opens a Docker Sandbox Bash shell with Pi installed; run `pi`
inside it when needed. The kit in `sbx/spec.yaml` extends the standard Docker
shell base with the shared dotfiles and development tools.
See [sandbox commands and authentication](sbx/README.md).

## Tests

Install [Docker Sandboxes (`sbx`)](https://docs.docker.com/ai/sandboxes/install/)
and run `sbx login` once, then:

```bash
./test
```

This creates a fresh Linux shell sandbox, mounts the current working tree
(including uncommitted changes) read-only at `/workspace`, and denies outbound
network access. Its required writable primary workspace is an empty temporary
directory, not your working tree. No host home directory, SSH agent, or shared
skills are mounted, and no MCP servers are enabled. The sandbox and temporary
workspace are removed on exit, including when tests fail. Image downloads during
sandbox creation still require network access.

The shared runner (`tests/run`) checks Bash syntax, then runs each test with a
clean environment, a separate temporary home, and host Git configuration disabled.
Shell tests cover destructive-operation safeguards, credential handling, port
publication safety, and test isolation—not aliases, prompts, tool loading, or
ordinary command behavior. The Node.js (`.mjs`) tests cover the custom scripts.
Run `./test` locally rather than running configuration tests directly on your host.

CI uses the same runner on fresh GitHub-hosted Ubuntu and macOS VMs. It does not
use `sbx`: local sandboxes require Docker sign-in and nested virtualization, which
is unavailable on GitHub's arm64 macOS runners. CI's isolation boundary is the
throwaway VM; it does not enforce the local sandbox's read-only mount or network
deny rule. Keeping the native macOS job also checks behavior a Linux sandbox cannot.

## Notes

- `install` is effectively idempotent: it skips links that already point at this repo.
- `uninstall` is also effectively idempotent: it removes only links that point at this repo.
- Git configuration and global ignore patterns are linked to `${XDG_CONFIG_HOME:-$HOME/.config}/git/config` and `git/ignore`. `setup` leaves an existing `~/.gitconfig` untouched; its settings take precedence.
- Sandbox startup points sbx's global `core.excludesfile` at the XDG ignore file while preserving other settings and repository-specific overrides.
