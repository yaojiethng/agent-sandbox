#!/usr/bin/env bash
# scripts/check_skill_sources.sh
# The source store gate: the store at .agents/registry/sources/ is what a bump
# reads, and this gate holds it valid - schema, every edge's path and passage
# anchor, the uniqueness of an edge's address, and each file's canonical form.
# It asks for no record: a path with no edge is a path nobody bumps.
#
# The rule is stated in docs/development/source_tracking.md and
# docs/adr/skill_source_catalog.md. The scanner is
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
