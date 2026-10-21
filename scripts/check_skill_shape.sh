#!/usr/bin/env bash
# scripts/check_skill_shape.sh
# The principle-shape gate: every skill whose name carries `principle-` carries
# the same six parts, in the same order, with a sentence-case title and no `##`
# heading below it.
#
# Enforces docs/development/prompt-authoring-conventions.md `## The principle
# shape` and the decision in docs/adr/principle_skill_shape.md. The scanner is
# scripts/lint/skill-shape.mjs.
#
# Scope: the skill roots a manifest cell declares, plus the project's own
# `.agents/skills` tree, filtered by the `principle-` segment of the directory
# name. The list is derived, so a new principle enters the check with its
# directory and no second edit.
#
# Test seam: SKILL_SHAPE_SCAN_ROOT points the scan at a fixture root that mirrors
# the repository layout.
#
# Options: `--map` prints the corpus grouped by claim, which is the derived family
# view. Any other argument reaches the scanner unchanged.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# docs/development/bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/skill-shape.mjs"
SCAN_ROOT="${SKILL_SHAPE_SCAN_ROOT:-$REPO_ROOT}"

if ! command -v node >/dev/null 2>&1; then
  echo "Skill shape gate: node is not on PATH; cannot scan." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Skill shape gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

cd "$REPO_ROOT" || exit 1

SKILL_SHAPE_SCAN_ROOT="$SCAN_ROOT" node "$SCAN_SCRIPT" "$@"
rc=$?

if (( rc == 0 )); then
  echo "Clean (${SECONDS}s)"
fi
exit "$rc"
