#!/usr/bin/env bash
# scripts/check_skill_sources.sh
# The workflow skill record gate: every agent-layer skill carries a
# `MAINTENANCE.md`, a forked record names a source id from the per-source store,
# and a home-grown record says so. The gate checks no hash and no catalog.
#
# The rule is stated in docs/adr/skill_source_catalog.md and the record shape in
# the per-skill `MAINTENANCE.md` files. The scanner is
# scripts/lint/skill_sources.mjs.
#
# Test seams: SKILL_SOURCE_ROOT points the tree at a fixture, and
# SKILL_SOURCE_STORE points the source store read elsewhere.
#
# Exit codes: 0 = clean, 1 = findings or the gate could not run. The finding
# count is printed, never encoded in the exit code.

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCANNER="$REPO_ROOT/scripts/lint/skill_sources.mjs"

if ! command -v node >/dev/null 2>&1; then
  echo "Skill source gate: node is not on PATH; cannot read the records." >&2
  exit 1
fi

if [[ ! -f "$SCANNER" ]]; then
  echo "Skill source gate: $SCANNER is missing; cannot run." >&2
  exit 1
fi

cd "$REPO_ROOT" || exit 1

node "$SCANNER" "$@"
rc=$?

if (( rc == 0 )); then
  echo "Clean (${SECONDS}s)"
else
  echo "Blocking gate: fix the findings above (see docs/adr/skill_source_catalog.md)." >&2
fi
exit "$rc"
