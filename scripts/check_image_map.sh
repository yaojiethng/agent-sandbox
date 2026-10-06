#!/usr/bin/env bash
# scripts/check_image_map.sh
# Holds scripts/lint/image-map.json equal to the provider dockerfiles.
#
# The manifest is the container layout declared once, and the provider
# dockerfiles are the layout as built. Neither is generated from the other, so
# this gate is what stops the two from disagreeing: a manifest row no `COPY` or
# `ENV` line carries, and a line no row carries, are both findings. The parse
# and the comparison live in scripts/lint/image-map.mjs, so this script is the
# gate wrapper and nothing else.
#
# The manifest exists so a consumer reads one declaration instead of deriving
# its own: scripts/check_instruction_context.sh asks this module for the `COPY`
# destinations, and scripts/lint/record-links.mjs imports it for the pairs that
# resolve a shipped file's references.
#
# Test seam: IMAGE_MAP_SCAN_ROOT points the scan at a fixture root that mirrors
# the repository layout, so the gate's branches run without touching the real
# tree.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded (bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_MODULE="$REPO_ROOT/scripts/lint/image-map.mjs"
SCAN_ROOT="${IMAGE_MAP_SCAN_ROOT:-$REPO_ROOT}"
MANIFEST_REL="scripts/lint/image-map.json"

if ! command -v node >/dev/null 2>&1; then
  echo "Image-map gate: node is not on PATH; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$SCAN_MODULE" ]]; then
  echo "Image-map gate: $SCAN_MODULE is missing; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$SCAN_ROOT/$MANIFEST_REL" ]]; then
  echo "Image-map gate: $MANIFEST_REL is missing; the layout is undeclared." >&2
  exit 1
fi

findings="$(node "$SCAN_MODULE" check --root "$SCAN_ROOT")"
rc=$?
if (( rc == 0 )); then
  echo "Image-map gate: clean; the manifest and the provider dockerfiles agree"
  echo "Clean (${SECONDS}s)"
  exit 0
fi

count="$(printf '%s\n' "$findings" | grep -c . || true)"
printf '%s\n' "$findings" >&2
echo "Image-map gate: $count finding(s)" >&2
echo "Blocking gate: align $MANIFEST_REL with the provider dockerfiles, or the other way round." >&2
exit 1
