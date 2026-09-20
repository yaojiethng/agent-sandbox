#!/usr/bin/env bash
# scripts/check_test_smoke.sh
# Non-gating rot detection for tests excluded from `make test`:
# syntax-checks every script under tests/knowledge/, tests/integration/
# and tests/eval/ with `bash -n`.
#
# Rationale: exclusion from the unit suite is policy (non-deterministic or
# diagnostic seams), but excluded scripts have rotted silently before
# (see AGENT_FEEDBACK "Knowledge/diagnostic tests outside make test rot
# silently" and handover 20260823-06). Syntax checking catches structural
# rot without asserting on their non-deterministic behaviour.
#
# Exit 0 when every script parses; exit 1 otherwise.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FAILED=0
COUNT=0

for DIR in knowledge integration eval; do
  TARGET="$REPO_ROOT/tests/$DIR"
  [[ -d "$TARGET" ]] || continue
  for F in "$TARGET"/*.sh; do
    [[ -e "$F" ]] || continue
    COUNT=$((COUNT + 1))
    if ! bash -n "$F" 2>/tmp/smoke_err.txt; then
      echo "SYNTAX FAIL: ${F#$REPO_ROOT/}" >&2
      cat /tmp/smoke_err.txt >&2
      FAILED=$((FAILED + 1))
    fi
  done
done

rm -f /tmp/smoke_err.txt

echo "$COUNT excluded test scripts checked, $FAILED syntax failures"
if (( FAILED > 0 )); then
  exit 1
fi
