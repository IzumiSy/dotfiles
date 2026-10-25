# Personal agent instructions

## Plan and authorization

- Treat clear requests to make a change as authorization to perform that work. This includes natural phrasing such as "I'd like to change X" and follow-up instructions such as "remove Y too"; do not require a separate "go ahead".
- For clear requests, briefly state the approach and proceed without waiting for another approval. For trivial changes, proceed directly.
- For questions, advice, or exploratory discussion, investigate read-only and propose options; do not make changes unless requested.
- Treat questions about past actions, requests for explanations, and expressions of concern or dissatisfaction as discussion, not authorization to change anything. Explain first; do not automatically fix, revert, or otherwise modify state.
- Before making a corrective change in response to such discussion, obtain explicit authorization, unless the user also clearly requests that change in the same message.
- Ask only when an unresolved ambiguity materially affects the outcome, or when the work would expand beyond the requested scope. Routine implementation choices and small follow-up adjustments do not require renewed approval.
- Destructive or irreversible operations, external publication, and account/security/privacy changes require explicit authorization for that action. A general request to fix or implement something is not sufficient. Keep all Git safety rules below.

## Visual alignment

- Proactively use diagrams when they help explain a plan or confirm alignment. Use Mermaid as the standard diagram format.
- Output diagrams in Markdown fenced code blocks with the `mermaid` language identifier.
- Choose the diagram type that fits the subject, such as a flowchart, sequence diagram, ER diagram, or state diagram.
- Clearly distinguish what will change from what will remain unchanged. Do not rely on color alone; also use labels or explanations.
- Prefer small diagrams that are readable in a terminal. Split large diagrams into an overview and focused details.
- Accompany diagrams with concise text that states assumptions, decisions, and what the user needs to confirm.
- Do not force diagrams for simple explanations. If a diagram cannot be rendered, simplify it or supplement it with text.

## Git and pull requests

### Tools

- For GitHub interactions (PR comments, review comments, issue replies, and review submission), use `gh` CLI by default.
- Do not use browser/chrome tools for GitHub write actions unless explicitly requested or `gh` is unavailable.
- Use browser/chrome tools only for troubleshooting, page inspection, and behavior or visual verification.
- Prefer non-browser workflows whenever a reliable CLI or direct tool is available.

### Safety

- Before pushing:
  - Never push directly to the default branch or any branch known to be protected without explicit user confirmation in the current conversation.
  - If the push target is unclear, or the current branch tracks the default branch or another branch known to be protected, stop and ask before pushing.

- When creating a working branch:
  - Do not set its upstream/tracking branch to the default branch or any other branch known to be protected.
  - It is fine to create a working branch from the default branch.

- After publishing a working branch:
  - Set its upstream to its corresponding remote branch instead (for example, `git push -u origin HEAD`).

- If the default branch or protection status cannot be determined confidently, stop and ask.

### Confidentiality

- Never include specific company names, customer names, or other client-identifying information in public-facing Git artifacts, including commit messages, PR titles, and descriptions; use generic terms even when the user provides real names.

### Pull requests

- Use the `create-pr` skill when creating a PR or preparing its title and description; it defines the PR workflow, Draft default, and description format.

## Copyable Text

- Prefer Markdown fenced code blocks with the `text` language identifier for copyable prose, such as suggested messages, prompts, and documentation additions.
- For source code, commands, and configuration, use the appropriate language identifier instead.
- Include only the content to be copied inside the fence; keep explanations and notes outside.
