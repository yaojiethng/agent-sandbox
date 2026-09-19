#!/usr/bin/env bash
# pre-commit -- Markdown lint gate over the staged change set.
#
# The capability entrypoint installs this hook into the session volume's
# .git/hooks/ for copy delivery only. Copy delivery's .git lives inside the
# session volume, so the hook can never execute on the host. Mount delivery
# installs no hook: its .git is a host directory. See docs/adr/git_hooks.md.
#
# The hook checks the staged Markdown files and blocks the commit on a finding.
# Bypass a check deliberately with: git commit --no-verify
#
# markdownlint reads the working-tree file, not the index copy, so a partially
# staged Markdown file is checked as it exists on disk.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT" || exit 0

STAGED=()
while IFS= read -r -d '' FILE; do
  STAGED+=("$FILE")
done < <(git diff --cached --name-only --diff-filter=ACMR -z -- '*.md')

((${#STAGED[@]} > 0)) || exit 0

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  MDL="markdownlint-cli2"
elif [[ -x "$HOME/.local/bin/markdownlint-cli2" ]]; then
  MDL="$HOME/.local/bin/markdownlint-cli2"
else
  echo "pre-commit: markdownlint-cli2 not found; skipping the Markdown check." >&2
  exit 0
fi

if ! "$MDL" --no-globs "${STAGED[@]}"; then
  echo "" >&2
  echo "pre-commit: Markdown lint findings in the staged files above." >&2
  echo "Fix them, or commit with: git commit --no-verify" >&2
  exit 1
fi

exit 0
