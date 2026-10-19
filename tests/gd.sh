#!/usr/bin/env bash
set -euo pipefail

eval "$(awk '/^function gd\(\) \{/,/^}/' "$(dirname "$0")/../_bashrc")"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gd.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_PAGER=cat

read() {
  printf 'prompt\n' >> "$tmp/prompts"
  builtin read "$@"
}

git init -q "$tmp/repo"
cd "$tmp/repo"
printf 'original\n' > tracked
printf 'ignored\n' > .gitignore
git add tracked .gitignore
git -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false commit -qm initial

# Clean and ignored files do not produce a diff.
[[ -z $(gd --name-only </dev/null) ]]
touch ignored
[[ -z $(gd --name-only </dev/null) ]]
[[ ! -e $tmp/prompts ]]

# Declining, the default answer, and EOF leave untracked files alone.
printf 'new\n' > untracked
for answer in n ''; do
  : > "$tmp/prompts"
  [[ -z $(gd --name-only <<< "$answer") ]]
  [[ -s $tmp/prompts ]]
  [[ $(git ls-files --others --exclude-standard) == untracked ]]
done
[[ -z $(gd --name-only </dev/null) ]]
[[ $(git ls-files --others --exclude-standard) == untracked ]]

# Approval includes untracked content without staging it for commit.
[[ $(gd --name-only <<< y) == untracked ]]
[[ -z $(git ls-files --others --exclude-standard) ]]
git diff --cached --quiet
[[ $(git diff --name-only) == untracked ]]

# HEAD diff includes both staged and unstaged changes; arguments are forwarded.
printf 'staged\n' > tracked
git add tracked untracked
: > "$tmp/prompts"
[[ $(gd --name-only -- tracked </dev/null) == tracked ]]
[[ ! -s $tmp/prompts ]]
printf 'unstaged\n' >> tracked
: > "$tmp/prompts"
output=$(gd -- tracked <<< n)
[[ -s $tmp/prompts ]]
[[ $output == *'-original'* ]]
[[ $output == *'+staged'* ]]
[[ $output == *'+unstaged'* ]]
[[ $output != *'diff --git a/untracked'* ]]

# Uppercase "yes" also approves add -N.
printf 'another\n' > another
[[ $(gd --name-only -- another <<< YES) == another ]]
[[ $(git ls-files --error-unmatch another) == another ]]

# Outside a repository, fail without attempting a diff or an add.
mkdir "$tmp/outside"
cd "$tmp/outside"
if GIT_CEILING_DIRECTORIES="$tmp" gd </dev/null >/dev/null 2>&1; then
  echo 'gd unexpectedly succeeded outside a repository' >&2
  exit 1
fi

printf 'gd checks passed\n'
