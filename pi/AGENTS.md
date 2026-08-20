# Personal agent instructions

- For GitHub interactions (PR comments, review comments, issue replies, and review submission), use `gh` CLI by default.
- Do not use browser/chrome tools for GitHub write actions unless explicitly requested or `gh` is unavailable.
- Use browser/chrome tools only for troubleshooting, page inspection, and behavior or visual verification.
- Prefer non-browser workflows whenever a reliable CLI or direct tool is available.

## Git safety

- Before pushing:
  - Never push directly to the default branch or any branch known to be protected without explicit user confirmation in the current conversation.
  - If the push target is unclear, or the current branch tracks the default branch or another branch known to be protected, stop and ask before pushing.

- When creating a working branch:
  - Do not set its upstream/tracking branch to the default branch or any other branch known to be protected.
  - It is fine to create a working branch from the default branch.

- After publishing a working branch:
  - Set its upstream to its corresponding remote branch instead (for example, `git push -u origin HEAD`).

- If the default branch or protection status cannot be determined confidently, stop and ask.

## Confidentiality in public Git history

- Never include specific company names, customer names, or other identifying information of clients in commit messages, PR titles, or PR descriptions.
- Use generic terms (e.g. "a customer", "a client", "an external partner") instead of real names.
- This applies even when the user's conversation mentions specific names — sanitize before writing to any public-facing Git artifact.

## Pull request conventions

When you create a new GitHub PR, create it as a Draft PR by default unless the user explicitly asks for a non-draft PR.

Use this description structure by default:

```
## Motivation
<!--
Provide enough context for a reviewer with no prior knowledge to understand
why the change is needed. Include relevant background from the user
conversation or bug report. This section may be relatively detailed.
-->

## Design Decision
<!--
If the change involved a meaningful API or design choice, explain why this
solution was chosen and why other plausible options were not. Keep this
focused on decision-making rather than implementation detail.

Organize this section with appropriate `###` subheadings (for example,
chosen approach, alternatives considered, trade-offs) instead of writing it
as one uninterrupted block of prose.

Omit this section if there is no meaningful decision to document.
-->

## Summary
<!--
Describe the change in a few bullets at a meaningful chunk level. Do not
repeat details that are already obvious from the file diff.
-->

```

Do not include Testing, Notes, or other boilerplate sections unless explicitly requested.
