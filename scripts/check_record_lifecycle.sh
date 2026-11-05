#!/usr/bin/env bash
# scripts/check_record_lifecycle.sh
# Exploration-record lifecycle gate over the live discussions folder and the
# roadmap rows that own its records.
#
# Enforces two rules the work-log convention states:
#
#   A closed roadmap row names no discussion record, because the row is what
#   owns the record and a closed row owns nothing.
#
#   A record whose state is `concluded` or `rejected` and that no open row names
#   is a deletion that has not run.
#
# The scanner is scripts/lint/record-lifecycle.mjs. It reads tenancy from
# devlog/roadmap.md and the state from the record's name, and the two together
# are the whole input, so it needs no map of which row produced which record.
#
# Scope: the scan reads devlog/discussions/ and does not walk its archive. A
# record dated before the cutover is exempt from both rules, the same exemption
# the name gate applies; the T5 cleanup row in devlog/roadmap.md ends the
# exemption by bringing the corpus to conformance.
#
# Test seam: RECORD_LIFECYCLE_SCAN_ROOT points the scan at a fixture root, and
# RECORD_CUTOVER moves the cutover the scan applies.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded in the exit code (see pattern p-14).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/record-lifecycle.mjs"
SCAN_ROOT="${RECORD_LIFECYCLE_SCAN_ROOT:-$REPO_ROOT}"
CUTOVER="${RECORD_CUTOVER:-}"

if ! command -v node >/dev/null 2>&1; then
  echo "Record lifecycle gate: node is not on PATH; cannot scan." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Record lifecycle gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

cd "$REPO_ROOT" || exit 1

node "$SCAN_SCRIPT" --root="$SCAN_ROOT" ${CUTOVER:+--cutover="$CUTOVER"}
rc=$?

if (( rc == 0 )); then
  echo "Clean (${SECONDS}s)"
fi
exit "$rc"
