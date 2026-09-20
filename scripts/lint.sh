#!/usr/bin/env bash
# scripts/lint.sh
# Umbrella static-check gate. Runs the ShellCheck gate (check_shell.sh) and the
# Markdown gate (check_markdown.sh). BLOCKING: exits 1 when either gate reports
# findings or cannot run.
#
# Both gates always run, so a failure in one never hides the other. The exit
# code is a verdict, not a count: 0 = both clean, 1 = at least one failed (see
# docs/development/bash-coding-conventions.md 3.2).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rc=0
bash "$REPO_ROOT/scripts/check_shell.sh" || rc=1
bash "$REPO_ROOT/scripts/check_markdown.sh" || rc=1
exit "$rc"
