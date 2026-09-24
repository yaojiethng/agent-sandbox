#!/usr/bin/env bash
# scripts/lint.sh
# Umbrella static-check gate. Runs the ShellCheck gate (check_shell.sh), the
# sourced-library contract gate (check_lib_contract.sh), and the Markdown gate
# (check_markdown.sh). BLOCKING: exits 1 when any gate reports findings or
# cannot run.
#
# All gates always run, so a failure in one never hides the others. The gates
# run concurrently (background jobs), which cuts the wall time; each gate's
# output is captured to a temp file and printed on completion, so the report is
# deterministic despite the concurrency. The exit code is a verdict, not a
# count: 0 = all clean, 1 = at least one failed (see
# docs/development/bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GATES=(check_shell.sh check_lib_contract.sh check_markdown.sh)

OUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/lint.XXXXXX") || exit 1
trap 'rm -rf "$OUT_DIR"' EXIT

pids=()
idx=0
for gate in "${GATES[@]}"; do
  bash "$REPO_ROOT/scripts/$gate" > "$OUT_DIR/g.$idx" 2>&1 &
  pids+=("$!")
  idx=$((idx + 1))
done

rc=0
for (( j = 0; j < ${#pids[@]}; j++ )); do
  if ! wait "${pids[$j]}"; then
    rc=1
  fi
  cat "$OUT_DIR/g.$j"
done

# Each gate reports its own wall time in a bracket; the umbrella adds a total
# so a whole-lint run shows one number alongside the per-gate numbers.
if (( rc == 0 )); then
  echo "Lint: clean in ${SECONDS}s across ${#GATES[@]} gates"
else
  echo "Lint: one or more gates failed after ${SECONDS}s." >&2
fi
exit "$rc"
