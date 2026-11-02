#!/usr/bin/env bash
# scripts/check_skill_packages.sh
# The package-manifest gate: `.agents/registry/packages.json` parses, names at
# least one package, and every entry carries a source, a scope and a reason.
#
# The manifest records the packages a project expects a session to have, in the
# form the operator pinned them; `node scripts/skill_packages.mjs` reports the
# difference against what is configured. That difference is a runtime report
# because the installed state exists only in a container.
#
# Test seam: SKILL_PACKAGES_SCAN_ROOT points the scan at a fixture root.
#
# Exit codes: 0 = no finding, 1 = findings or the gate could not run. The
# finding count is printed, never encoded in the exit code (see pattern p-14).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/skill_packages.mjs"
SCAN_ROOT="${SKILL_PACKAGES_SCAN_ROOT:-$REPO_ROOT}"

if ! command -v node >/dev/null 2>&1; then
  echo "Skill package gate: node is not on PATH; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Skill package gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

cd "$REPO_ROOT" || exit 1

SKILL_PACKAGES_SCAN_ROOT="$SCAN_ROOT" node "$SCAN_SCRIPT"
rc=$?

if (( rc == 0 )); then
  echo "Clean (${SECONDS}s)"
else
  echo "Blocking gate: fix the findings above (see scripts/skill_packages.mjs)." >&2
fi
exit "$rc"
