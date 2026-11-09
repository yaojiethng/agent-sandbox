#!/usr/bin/env bash
# scripts/check_statechart.sh
# The statechart gate: the state declarations in
# `docs/reference/workflow_statechart.md`'s Mermaid chart and the id and region
# columns of its `## States` table must name the same states in the same order.
#
# The unit is the column, not the table. The two columns are derived from the
# chart; the gloss column is authored prose and is not compared. A state edited
# into the chart alone, or a region moved in the table alone, is the drift the
# gate reports. The scanner is `scripts/lint/statechart.mjs`.
#
# `--write` rebuilds the two derived columns from the chart and keeps every
# existing gloss, so a declared state is added to the table by re-running this
# script rather than by hand.
#
# Test seam: --doc=<path> points the scan at a fixture. Value flags use the
# tree's equal-separated form.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# pattern p-14).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/statechart.mjs"

if ! command -v node >/dev/null 2>&1; then
  echo "Statechart gate: node is not on PATH; cannot read the chart." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Statechart gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

set +e
ARGS=("$@")
has_doc=0
for arg in "$@"; do
  case "$arg" in
    --doc)
      echo "Statechart gate: --doc requires a value: use --doc=PATH" >&2
      exit 1
      ;;
    --doc=*) has_doc=1 ;;
  esac
done
# The default document is the tree's chart, and a caller may replace it for a
# fixture. The seam is added only when unset, so the scanner never receives two.
if (( has_doc == 0 )); then
  ARGS=(--doc="$REPO_ROOT/docs/reference/workflow_statechart.md" "${ARGS[@]}")
fi
node "$SCAN_SCRIPT" "${ARGS[@]}"
rc=$?
set -e

if (( rc != 0 )); then
  echo "Blocking gate: fix the findings above. After editing the chart's declarations, run \`bash scripts/check_statechart.sh --write\` to rebuild the two derived columns."
  echo "Statechart gate ($SECONDS s): findings"
  exit 1
fi

echo "Clean (${SECONDS}s)"
