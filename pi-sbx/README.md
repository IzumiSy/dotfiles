# Pi sandbox

Run `sbpi [id] [sbx arguments...]`. The ID defaults to `HERDR_WORKSPACE_ID`;
outside Herdr, provide it explicitly. `sbbash` opens a shell in the same sandbox,
`sbstop` stops it, and `sbstatus [id] [sbx arguments...]` shows its state and
details via `sbx inspect`. All shortcuts use the current directory and the same
workspace ID; for example, `sbstatus manual --json` inspects an explicit ID.

On every launch, `sbpi` registers `gh auth token` as the host-side dynamic source
for a sandbox-scoped custom secret. Authenticate with `gh auth login` on the host
first; token resolution or secret registration failures prevent launch.
`GH_TOKEN` is passed as a placeholder, including when reattaching to an existing
sandbox. The proxy replaces only that placeholder in request headers to
`api.github.com` and `github.com`; the real token stays on the host and Pi's
sandbox-local Copilot authentication headers remain untouched.
This uses the experimental `sbx secret set-custom` command.

`sbpi` sets `HERDR_AGENT=pi` on the host's `sbx run` process so Herdr can identify
it and use its built-in screen detection. On macOS this requires Herdr 0.9.0 or
newer, including the running server. Detection accuracy depends on Herdr's Pi
rules, especially for approval prompts. No custom relay or Pi extension is used.
