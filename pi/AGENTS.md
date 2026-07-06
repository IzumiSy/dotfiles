# Personal agent instructions

- For GitHub interactions (PR comments, review comments, issue replies, and review submission), use `gh` CLI by default.
- Do not use browser/chrome tools for GitHub write actions unless explicitly requested or `gh` is unavailable.
- Use browser/chrome tools only for troubleshooting, page inspection, and behavior or visual verification.
- Prefer non-browser workflows whenever a reliable CLI or direct tool is available.

## Sandbox / package installs

- In this environment, `pnpm install` can fail under `pi-sandbox` because the sandbox hard-blocks writes to `.idea/` and `.vscode/`, and some published packages include those directories in their tarballs.
- When a task requires `pnpm install`, ask the user to run it outside the sandbox instead of running it yourself by default.
- Only run `pnpm install` yourself when the user explicitly asks you to reproduce or diagnose the sandbox failure, and then report the exact blocked path/package.

## Git safety

- Never push directly to `main` or any default/protected branch without explicit user confirmation in the current conversation.
- If the push target is unclear or the current branch tracks `origin/main`, stop and ask before pushing.

## Pull request description conventions

When you create a new Github PR, use this structure by default:

```
## Motivation
<!-- Provide enough context for a reviewer with no prior knowledge to understand why the change is needed. Include relevant background from the user conversation or bug report. This section may be relatively detailed. -->

## Design Decision
<!-- If the change involved a meaningful API or design choice, explain why this solution was chosen and why other plausible options were not. Keep this focused on decision-making rather than implementation detail. Omit this section if there is no meaningful decision to document. -->

## Summary
<!-- Describe the change in a few bullets at a meaningful chunk level. Do not repeat details that are already obvious from the file diff. -->

```

Do not include Testing, Notes, or other boilerplate sections unless explicitly requested.
