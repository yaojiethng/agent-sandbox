#!/usr/bin/env bash
# scripts/lint.sh
# Umbrella static-check gate. Runs the ShellCheck gate (check_shell.sh), the
# sourced-library contract gate (check_lib_contract.sh), the Markdown gate
# (check_markdown.sh), the instruction-document gate
# (check_document_shape.sh), the handover format gate
# (check_handover_format.sh), the legacy wrap gate (check_doc_wrap_legacy.sh),
# the instruction-surface gate (check_instruction_surfaces.sh), the reach gate
# (check_reach.sh), the statechart gate (check_statechart.sh) and the launch-site
# gate (check_launch_sites.sh); the Markdown gate carries the doc-wrap and linking
# rules. BLOCKING: exits 1 when any gate reports findings or cannot run.
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

GATES=(check_shell.sh check_lib_contract.sh check_markdown.sh check_document_shape.sh check_handover_format.sh check_doc_wrap_legacy.sh check_instruction_surfaces.sh check_container_layout.sh check_reach.sh check_statechart.sh check_numbering.sh check_launch_sites.sh)

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
