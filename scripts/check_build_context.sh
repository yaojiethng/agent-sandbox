#!/usr/bin/env bash
# scripts/check_build_context.sh
# Holds the build context equal to the inputs the build declares: every
# manifest source and every Dockerfile COPY source survives `.dockerignore`,
# and every included path is one of those, a dockerfile, or the ignore file
# itself. The walk and the comparison live in src/build/build-context.mjs; this
# script is the gate wrapper.
#
# Test seam: BUILD_CONTEXT_SCAN_ROOT points the scan at a fixture root.
#
# Exit codes: 0 = clean, 1 = findings or the gate could not run.

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_MODULE="$REPO_ROOT/src/build/build-context.mjs"
SCAN_ROOT="${BUILD_CONTEXT_SCAN_ROOT:-$REPO_ROOT}"

if ! command -v node >/dev/null 2>&1; then
  echo "Build-context gate: node is not on PATH; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$SCAN_MODULE" ]]; then
  echo "Build-context gate: $SCAN_MODULE is missing; cannot read the manifest." >&2
  exit 1
fi

out="$(node "$SCAN_MODULE" check --root "$SCAN_ROOT")"
rc=$?
printf '%s\n' "$out"
if (( rc == 0 )); then
  echo "Build-context gate: clean; the context is the declared inputs"
  echo "Clean (${SECONDS}s)"
else
  echo "Build-context gate: the context and the declared inputs disagree"
  echo "Findings (${SECONDS}s)"
fi
exit "$rc"
