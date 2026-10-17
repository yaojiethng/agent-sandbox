#!/usr/bin/env bash
# scripts/check_container_layout.sh
# Holds src/build/container-interface.json equal to what implements it: the
# provider dockerfiles, the entrypoint's provisioning, the provider settings
# record and the instruction surfaces' folder sets.
#
# The manifest is the container interface declared once, and the dockerfiles,
# the entrypoint and the settings are the interface as built. Neither is
# generated from the other, so this gate is what stops the two from disagreeing:
# a manifest row no `COPY` or `ENV` line carries, a line no row carries, a
# declared instruction surface whose folder set differs from the one the image
# sends there, an `/opt` surface the provider cannot load, a destination in the
# agent tree no cell declares, and a project-tree surface the provider's
# settings record does not name are all findings. The parse, the derivation
# and the comparison live in src/build/container-interface.mjs, so this script
# is the gate wrapper and nothing else.
#
# The manifest exists so a consumer reads one declaration instead of deriving
# its own: scripts/check_instruction_surfaces.sh asks this module for the
# session rows, and scripts/lint/record-links.mjs imports it for the pairs and
# the instruction surfaces that resolve a shipped file's references.
#
# Test seam: CONTAINER_INTERFACE_SCAN_ROOT points the scan at a fixture root
# that mirrors the repository layout, so the gate's branches run without
# touching the real tree.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded (bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_MODULE="$REPO_ROOT/src/build/container-interface.mjs"
SCAN_ROOT="${CONTAINER_INTERFACE_SCAN_ROOT:-$REPO_ROOT}"
MANIFEST_REL="src/build/container-interface.json"

if ! command -v node >/dev/null 2>&1; then
  echo "Container-layout gate: node is not on PATH; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$SCAN_MODULE" ]]; then
  echo "Container-layout gate: $SCAN_MODULE is missing; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$SCAN_ROOT/$MANIFEST_REL" ]]; then
  echo "Container-layout gate: $MANIFEST_REL is missing; the interface is undeclared." >&2
  exit 1
fi

findings="$(node "$SCAN_MODULE" check --root "$SCAN_ROOT")"
rc=$?
if (( rc == 0 )); then
  echo "Container-layout gate: clean; the manifest and the images agree"
  echo "Clean (${SECONDS}s)"
  exit 0
fi

count="$(printf '%s\n' "$findings" | grep -c . || true)"
printf '%s\n' "$findings" >&2
echo "Container-layout gate: $count finding(s)" >&2
echo "Blocking gate: align $MANIFEST_REL with the provider dockerfiles, the entrypoint and the settings record, or the other way round." >&2
exit 1
