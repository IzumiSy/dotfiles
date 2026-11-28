# Workspace Tools

Local Herdr plugin using the existing `bash/sandbox.sh` helpers. Requires Herdr
0.9.5+, Node.js, Bash, `gh`, `sbx`, and the host Pi/Copilot login used by `sbpi`.
The Herdr server's PATH must include these commands. Keep the plugin linked from
this dotfiles checkout; it resolves the shared Bash helpers relative to itself.

## Enable

After installing `herdr/config.toml` with the dotfiles setup:

```bash
herdr plugin link "$HOME/Devs/dotfiles/herdr/workspace-tools"
herdr server reload-config
```

The plugin registration persists across Herdr restarts. No server restart is
needed. Link it once per machine; ordinary dotfiles setup only installs symlinks.

## Keys

- **prefix+p**: open a terminal popup. Enter `1` (or just Enter) for an existing
  local directory, or `2` for a GitHub repository and Pi sandbox. Enter `q` to
  cancel; Ctrl+C also closes the popup.
- **prefix+n**: replaces the built-in new-tab shortcut. If a matching sandbox
  exists, open a tab and run `sbbash` there; stopped sandboxes are started by
  `sbx exec`. Otherwise create a normal shell tab using Herdr's usual cwd policy.
- **ctrl+shift+w**: remains Herdr's ordinary new-workspace shortcut.

Repository input accepts `owner/repo`, `https://github.com/owner/repo[.git]`, or
`git@github.com:owner/repo.git`. Clones go under
`~/.herdr-workspaces/<owner>/<repo-directory>`. To fit sbpi's sandbox naming
rules, punctuation other than hyphens becomes a hyphen, and the directory name
is limited to 40 characters. Existing destinations (including symlinks and
normalized-name collisions) are refused, never overwritten or deleted. A failed
clone can leave its partial checkout for manual inspection.

The GitHub workflow creates a workspace at the checkout, then runs the existing
`sbpi <workspace-id>` in its first pane. It uses the fixed `pi-sbx` kit and keeps
its host-managed credentials and private in-sandbox clone behavior. Sandbox
edits do **not** directly modify the host checkout.

Sandbox tabs match both the workspace ID and a checkout path from `sbx ls`.
A focused pane inside a checkout subdirectory still attaches at the sandbox's
checkout root. Multiple matching sandboxes or a sandbox backend error produce
an error notification instead of silently opening a host shell.

Only these keybindings are overridden: menu and CLI tab creation stay unchanged.
No creation-event hooks, image picker, sandbox cleanup, or automatic resume after
server restart are added. `pane run` acknowledges queued input; authentication
or attach failures after launch are shown in the new pane. As with manual
`sbbash`, exiting the sandbox shell returns to the host shell in that tab.

## Tests

```bash
node --test tests/herdr-workspace-tools.mjs
```

Tests use mock CLI commands: no GitHub clones, credentials, or sandboxes.
