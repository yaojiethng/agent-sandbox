#!/usr/bin/env bash
# scripts/check_change_pipeline.sh
# The change pipeline gate: every Mermaid edge in
# `docs/reference/change_pipeline.md` carries a transition id, every id has one
# `## The transitions` row naming its lane, actor, mechanism, manual flag,
# subject, invariant, test and mutation, and the row's endpoints match the chart.
#
# The scanner is `scripts/lint/change_pipeline.mjs`. `--doc=<path>`,
# `--catalog=<path>` and `--tests-dir=<path>` point it at a fixture; the defaults
# read the tree's model, the mutation catalog and the test suite. Value flags use
# the tree's equal-separated form.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run.

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/change_pipeline.mjs"

if ! command -v node >/dev/null 2>&1; then
  echo "Change pipeline gate: node is not on PATH; cannot read the chart." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Change pipeline gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

set +e
ARGS=("$@")
has_doc=0
has_model=0
for arg in "$@"; do
  case "$arg" in
    --doc | --model-dir | --catalog | --tests-dir)
      echo "Change pipeline gate: $arg requires a value: use $arg=PATH" >&2
      exit 1
      ;;
    --doc=*) has_doc=1 ;;
    --model-dir=*) has_model=1 ;;
  esac
done
# The default document renders the tree's model home. A fixture may replace
# either; a doc-only fixture keeps reading its own chart and table, so the
# legacy seam still works.
if (( has_doc == 0 && has_model == 0 )); then
  ARGS=(--doc="$REPO_ROOT/docs/reference/change_pipeline.md" --model-dir="$REPO_ROOT/tests/model/change_pipeline" "${ARGS[@]}")
elif (( has_doc == 0 )); then
  ARGS=(--doc="$REPO_ROOT/docs/reference/change_pipeline.md" "${ARGS[@]}")
fi
node "$SCAN_SCRIPT" "${ARGS[@]}"
rc=$?
set -e

if (( rc != 0 )); then
  echo "Blocking gate: fix the findings above. Every edge needs an id and one transition row; every row needs a lane, actor, manual flag, invariant, test and mutation."
  echo "Change pipeline gate ($SECONDS s): findings"
  exit 1
fi

echo "Clean (${SECONDS}s)"
