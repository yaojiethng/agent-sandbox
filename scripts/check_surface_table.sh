#!/usr/bin/env bash
# scripts/check_surface_table.sh
# Holds the reference documents to the instruction surface's declaration:
# src/build/container-interface.json.
#
# The manifest declares where each source lands in the container. A reference
# document that states that mapping itself is a copy, and a copy drifts. So one
# generated block carries the table, its body must equal what the manifest
# renders, and outside the block a reference document may not restate a
# declared source-and-destination pair in a table row, nor name a repository
# file path the tree does not hold.
#
# The render, the block parse and the comparison live in
# src/build/surface_table.mjs, so this script is the gate wrapper and nothing
# else.
#
# Test seam: SURFACE_TABLE_SCAN_ROOT points the scan at a fixture root that
# mirrors the repository layout.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded (pattern p-14).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_MODULE="$REPO_ROOT/src/build/surface_table.mjs"
SCAN_ROOT="${SURFACE_TABLE_SCAN_ROOT:-$REPO_ROOT}"

if ! command -v node >/dev/null 2>&1; then
  echo "Surface-table gate: node is not on PATH; cannot render the table." >&2
  exit 1
fi

if [[ ! -f "$SCAN_MODULE" ]]; then
  echo "Surface-table gate: $SCAN_MODULE is missing; cannot render the table." >&2
  exit 1
fi

findings="$(node "$SCAN_MODULE" check --root "$SCAN_ROOT")"
rc=$?
if (( rc == 0 )); then
  echo "Surface-table gate: clean; the reference documents cite the manifest's table"
  echo "Clean (${SECONDS}s)"
  exit 0
fi

count="$(printf '%s\n' "$findings" | grep -c . || true)"
printf '%s\n' "$findings" >&2
echo "Surface-table gate: $count finding(s)" >&2
echo "Blocking gate: cite the generated block, or run node src/build/surface_table.mjs write, rather than restating the mapping." >&2
exit 1
