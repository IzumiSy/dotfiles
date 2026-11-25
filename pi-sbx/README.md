# Pi sandbox

Run `sbpi [id] [sbx arguments...]`. The ID defaults to `HERDR_WORKSPACE_ID`;
outside Herdr, provide it explicitly. `sbbash` opens a shell in the same sandbox
and `sbstop` stops it.

`sbpi` sets `HERDR_AGENT=pi` on the host's `sbx run` process so Herdr can identify
it and use its built-in screen detection. On macOS this requires Herdr 0.9.0 or
newer, including the running server. Detection accuracy depends on Herdr's Pi
rules, especially for approval prompts. No custom relay or Pi extension is used.
