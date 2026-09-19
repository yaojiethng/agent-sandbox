#!/usr/bin/env bash
# scripts/lint.sh
# Umbrella static-check gate. Runs the ShellCheck gate (check_shell.sh) and the
# Markdown gate (check_markdown.sh). BLOCKING: exits nonzero when either gate
# reports findings.
#
# Both gates always run, so a failure in one never hides the other. The exit
# code is the first failing gate's code (ShellCheck first), else zero.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

shell_rc=0
markdown_rc=0
bash "$REPO_ROOT/scripts/check_shell.sh" || shell_rc=$?
bash "$REPO_ROOT/scripts/check_markdown.sh" || markdown_rc=$?

if (( shell_rc != 0 )); then
  exit "$shell_rc"
fi
exit "$markdown_rc"
