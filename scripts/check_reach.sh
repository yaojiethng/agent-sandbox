#!/usr/bin/env bash
# scripts/check_reach.sh
# The reach gate: the roots `docs/reference/documentation_taxonomy.md` `## Reach`
# names by delivery route, and the roots `src/build/container-interface.json`
# mounts, must name the same thing.
#
# Neither artifact copies the other's list. The manifest says what the image
# delivers and where; the taxonomy says which mount points a delivery route
# covers and which folders the image does not deliver. A root added to one and
# not the other is a statement of reach that is silently wrong, so the gate
# reports the side that moved. The scanner is `scripts/lint/reach.mjs`.
#
# The folder class is derived, not declared. A folder the taxonomy names is a
# shipped subtree when an image source covers it, and must exist on disk; a
# folder under no image source is stated repository-only, and must appear in no
# manifest path.
#
# Test seam: --manifest, --taxonomy and --root point the scan at a fixture.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# docs/development/bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/reach.mjs"

if ! command -v node >/dev/null 2>&1; then
  echo "Reach gate: node is not on PATH; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Reach gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

set +e
ARGS=("$@")
# The default root is the repository, and a caller may replace it for a fixture.
# Appending the default before the caller's arguments would leave the scanner
# reading the first `--root` it finds, so the seam is added only when unset.
if [[ " $* " != *" --root "* ]]; then
  ARGS=(--root "$REPO_ROOT" "${ARGS[@]}")
fi
node "$SCAN_SCRIPT" "${ARGS[@]}"
rc=$?
set -e

if (( rc != 0 )); then
  echo "Blocking gate: fix the findings above. A change to a mount row in src/build/container-interface.json and a change to \`## Reach\` in docs/reference/documentation_taxonomy.md are one edit."
  echo "Reach gate ($SECONDS s): findings"
  exit 1
fi

echo "Clean (${SECONDS}s)"
