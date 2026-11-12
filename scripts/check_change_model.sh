#!/usr/bin/env bash
# scripts/check_change_model.sh
# The change model gate: every Mermaid edge in
# `docs/reference/change_model.md` carries a transition id, every id has one
# `## The transitions` row naming its lane, actor, mechanism, manual flag,
# subject, invariant, test and mutation, and the row's endpoints match the chart.
#
# The scanner is `scripts/lint/change_model.mjs`. `--doc=<path>`,
# `--catalog=<path>` and `--tests-dir=<path>` point it at a fixture; the defaults
# read the tree's model, the mutation catalog and the test suite. Value flags use
# the tree's equal-separated form.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run.

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/change_model.mjs"

if ! command -v node >/dev/null 2>&1; then
  echo "Change model gate: node is not on PATH; cannot read the chart." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Change model gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

set +e
ARGS=("$@")
has_doc=0
for arg in "$@"; do
  case "$arg" in
    --doc | --catalog | --tests-dir)
      echo "Change model gate: $arg requires a value: use $arg=PATH" >&2
      exit 1
      ;;
    --doc=*) has_doc=1 ;;
  esac
done
if (( has_doc == 0 )); then
  ARGS=(--doc="$REPO_ROOT/docs/reference/change_model.md" "${ARGS[@]}")
fi
node "$SCAN_SCRIPT" "${ARGS[@]}"
rc=$?
set -e

if (( rc != 0 )); then
  echo "Blocking gate: fix the findings above. Every edge needs an id and one transition row; every row needs a lane, actor, manual flag, invariant, test and mutation."
  echo "Change model gate ($SECONDS s): findings"
  exit 1
fi

echo "Clean (${SECONDS}s)"
