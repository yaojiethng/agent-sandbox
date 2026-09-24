#!/usr/bin/env bash
# pre-commit -- Markdown + ShellCheck lint gate over the staged change set.
#
# The capability entrypoint installs this hook into the session volume's
# .git/hooks/ for copy delivery only. Copy delivery's .git lives inside the
# session volume, so the hook can never execute on the host. Mount delivery
# installs no hook: its .git is a host directory. See docs/adr/git_hooks.md.
#
# The hook checks the staged Markdown and shell files and blocks the commit on
# a finding. Bypass a check deliberately with: git commit --no-verify
#
# markdownlint reads the working-tree file, not the index copy, so a partially
# staged Markdown file is checked as it exists on disk. ShellCheck reads the
# same way; the staged list (git diff --cached --name-only) only carries files
# present in the working tree, so the check never runs on a staged deletion.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT" || exit 0

HAD_FINDINGS=0

# ---------------------------------------------------------------------------
# Markdown gate
# ---------------------------------------------------------------------------

STAGED_MD=()
while IFS= read -r -d '' FILE; do
  STAGED_MD+=("$FILE")
done < <(git diff --cached --name-only --diff-filter=ACMR -z -- '*.md')

if ((${#STAGED_MD[@]} > 0)); then
  if command -v markdownlint-cli2 >/dev/null 2>&1; then
    MDL="markdownlint-cli2"
  elif [[ -x "$HOME/.local/bin/markdownlint-cli2" ]]; then
    MDL="$HOME/.local/bin/markdownlint-cli2"
  else
    echo "pre-commit: markdownlint-cli2 not found; skipping the Markdown check." >&2
    MDL=""
  fi

  if [[ -n "${MDL:-}" ]] && ! "$MDL" --no-globs "${STAGED_MD[@]}"; then
    echo "pre-commit: Markdown lint findings in the staged files above." >&2
    HAD_FINDINGS=1
  fi
fi

# ---------------------------------------------------------------------------
# ShellCheck gate
# ---------------------------------------------------------------------------

STAGED_SH=()
while IFS= read -r -d '' FILE; do
  STAGED_SH+=("$FILE")
done < <(git diff --cached --name-only --diff-filter=ACMR -z -- '*.sh')

if ((${#STAGED_SH[@]} > 0)); then
  if command -v shellcheck >/dev/null 2>&1; then
    if ! SH_OUTPUT=$(shellcheck -S warning "${STAGED_SH[@]}" 2>&1); then
      printf '%s\n' "$SH_OUTPUT"
      if grep -q "Couldn't parse this shellcheck directive" <<<"$SH_OUTPUT"; then
        echo "pre-commit: a comment starting with the word 'shellcheck' is parsed as a directive." >&2
        echo "  Reword the line so the tool name is not the first token after '#'." >&2
      else
        echo "pre-commit: ShellCheck findings in the staged files above." >&2
      fi
      HAD_FINDINGS=1
    fi
  else
    echo "pre-commit: shellcheck not found; skipping the ShellCheck check." >&2
  fi
fi

if (( HAD_FINDINGS )); then
  echo "" >&2
  echo "pre-commit: fix the findings, or commit with: git commit --no-verify" >&2
  exit 1
fi

exit 0