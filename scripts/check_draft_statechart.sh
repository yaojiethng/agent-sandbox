#!/usr/bin/env bash
# scripts/check_draft_statechart.sh
# The draft branch statechart gate: every Mermaid edge in
# `docs/reference/draft_branch_statechart.md` carries a transition id, and
# every id has one `## Transitions` row naming its guard, invariant,
# precondition, postcondition, test and mutation.
#
# The scanner is `scripts/lint/draft_statechart.mjs`. `--doc=<path>`,
# `--catalog=<path>` and `--tests-dir=<path>` point it at a fixture; the defaults
# read the tree's model, the mutation catalog and the test suite. Value flags use
# the tree's equal-separated form.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run.

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/draft_statechart.mjs"

if ! command -v node >/dev/null 2>&1; then
  echo "Draft statechart gate: node is not on PATH; cannot read the chart." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Draft statechart gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

set +e
ARGS=("$@")
has_doc=0
for arg in "$@"; do
  case "$arg" in
    --doc | --catalog | --tests-dir)
      echo "Draft statechart gate: $arg requires a value: use $arg=PATH" >&2
      exit 1
      ;;
    --doc=*) has_doc=1 ;;
  esac
done
if (( has_doc == 0 )); then
  ARGS=(--doc="$REPO_ROOT/docs/reference/draft_branch_statechart.md" "${ARGS[@]}")
fi
node "$SCAN_SCRIPT" "${ARGS[@]}"
rc=$?
set -e

if (( rc != 0 )); then
  echo "Blocking gate: fix the findings above. Every edge needs an id and one transition row; every product transition needs a real test and catalog row."
  echo "Draft statechart gate ($SECONDS s): findings"
  exit 1
fi

echo "Clean (${SECONDS}s)"
