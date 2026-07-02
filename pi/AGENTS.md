# Personal agent instructions

- For GitHub interactions (PR comments, review comments, issue replies, and review submission), use `gh` CLI by default.
- Do not use browser/chrome tools for GitHub write actions unless explicitly requested or `gh` is unavailable.
- Use browser/chrome tools only for troubleshooting, page inspection, and behavior or visual verification.
- Prefer non-browser workflows whenever a reliable CLI or direct tool is available.

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
