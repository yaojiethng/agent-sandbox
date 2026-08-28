#!/usr/bin/env bash
# scripts/check_lib_liveness.sh
# Asserts every src/libs/*.sh is referenced by at least one non-test file.
#
# Rationale: nothing failed when src/libs/buildkit_progress.sh lost its last
# source-er (20260821-01); it sat orphaned for weeks with a header still
# claiming active sourcing, and a test suite was even written for it. This
# check makes orphaning loud the day it happens.
#
# A lib is considered live when its basename appears in a non-test,
# non-devlog file under src/, scripts/, test/ or Makefile  --  i.e. anything
# that could source or invoke it in production. Test-only references do not
# count: coverage of dead code is still dead code.
#
# Exit 0 when all libs are live; exit 1 listing orphans.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ORPHANS=0
COUNT=0

for LIB in "$REPO_ROOT"/src/libs/*.sh; do
  [[ -e "$LIB" ]] || continue
  NAME="$(basename "$LIB")"
  COUNT=$((COUNT + 1))

  # Reference = basename appearing outside tests/, excluding the lib itself
  # and this checker. grep -F: the names are fixed strings; word-ish match
  # via the path/space/quote characters that surround a sourced name.
  REFS=$(grep -rFl "$NAME" \
    "$REPO_ROOT/src" "$REPO_ROOT/scripts" "$REPO_ROOT/test" "$REPO_ROOT/Makefile" \
    --include='*.sh' --include='Makefile' --include='*.template' 2>/dev/null \
    | grep -v "/$NAME$" \
    | grep -v "^$REPO_ROOT/tests/" \
    | wc -l)

  if (( REFS == 0 )); then
    echo "ORPHANED: src/libs/$NAME  --  no non-test reference found" >&2
    ORPHANS=$((ORPHANS + 1))
  fi
done

echo "$COUNT libs checked, $ORPHANS orphaned"
if (( ORPHANS > 0 )); then
  exit 1
fi
