# Personal agent instructions

- For GitHub interactions (PR comments, review comments, issue replies, and review submission), use `gh` CLI by default.
- Do not use browser/chrome tools for GitHub write actions unless explicitly requested or `gh` is unavailable.
- Use browser/chrome tools only for troubleshooting, page inspection, and behavior or visual verification.
- Prefer non-browser workflows whenever a reliable CLI or direct tool is available.

## Pull request description conventions

When you create a new Github PR, use this structure by default:

```
## Motivation
<!-- Provide enough context for a reviewer with no prior knowledge to understand why the change is needed. Include relevant background from the user conversation or bug report. This section may be relatively detailed. -->

## Summary
<!-- Describe the change in a few bullets at a meaningful chunk level. Do not repeat details that are already obvious from the file diff. -->

```

Do not include Testing, Notes, or other boilerplate sections unless explicitly requested.
