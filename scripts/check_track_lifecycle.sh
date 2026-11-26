#!/usr/bin/env bash
# scripts/check_track_lifecycle.sh
# Handover track lifecycle gate: a milestone the changelog closes keeps no live
# track folder.
#
# Enforces one rule:
#
#   A milestone that devlog/changelog.md closes has no folder under
#   devlog/handovers/. A track is the records of an open milestone; once the
#   milestone closes, the changelog is the permanent record and the track is
#   archived to the commit that removed it.
#
# The changelog heading `## M3.4.2 - ...` is the closure predicate, the same
# record the summary table links to. A folder whose name is not a closed
# milestone id -- a work-unit folder such as T7, or a live milestone's -- is not
# this gate's subject. devlog/handovers/archive/ is frozen history and is never
# read.
#
# Usage: bash scripts/check_track_lifecycle.sh [--root=DIR]
# Exit:  0 = no findings, 1 = findings or the gate could not run. The finding
#        count is printed, never encoded in the exit code (see pattern p-14).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$REPO_ROOT"
for arg in "$@"; do
  case "$arg" in
  --root=*) ROOT="${arg#*=}" ;;
  *)
    echo "Track lifecycle gate: unknown option: $arg" >&2
    exit 2
    ;;
  esac
done

if [[ ! -d "$ROOT" ]]; then
  echo "Track lifecycle gate: $ROOT is not a directory; cannot run." >&2
  exit 1
fi

CHANGELOG="$ROOT/devlog/changelog.md"
TRACKS="$ROOT/devlog/handovers"

if [[ ! -f "$CHANGELOG" ]]; then
  echo "Track lifecycle gate: $CHANGELOG is missing; cannot read the closure state." >&2
  exit 1
fi

closed="$(
  sed -nE 's/^## (M[0-9]+(\.[0-9]+)*) - .*/\1/p' "$CHANGELOG"
)"

findings=0
if [[ -d "$TRACKS" ]]; then
  for dir in "$TRACKS"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ "$name" == "archive" ]] && continue
    if grep -qxF "$name" <<< "$closed"; then
      echo "$name: a live track for a milestone the changelog closes; archive the records and remove the folder"
      findings=$((findings + 1))
    fi
  done
fi

if (( findings > 0 )); then
  echo "Track lifecycle gate: ${findings} finding(s) across $(find "$TRACKS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l) folder(s)."
  exit 1
fi

echo "Clean (${SECONDS}s)"
