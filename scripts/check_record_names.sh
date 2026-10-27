#!/usr/bin/env bash
# scripts/check_record_names.sh
# Exploration-record name gate over the live discussions folder, and over any
# file named on the command line.
#
# Enforces the work-log convention's name for an exploration record:
# YYYYMMDD-{type}-{status}-{description}.md. The handover record carries a
# per-day index and this one does not, and a discussion record that copies the
# index starts a second sequence under one date. The scanner is
# scripts/lint/record-name.mjs.
#
# Scope: the default scan reads devlog/discussions/, and does not walk its
# archive. A record dated before the cutover keeps an old-format name until it
# is substantively edited. A file named on the command line is enforced
# regardless of date, which is the on-demand audit mode and the mode a
# substantial edit should use. `--staged` enforces the records staged for
# commit and keeps the cutover, so correcting an old record is not blocked.
#
# Test seam: RECORD_NAME_SCAN_ROOT points the scan at a fixture root, and
# RECORD_NAME_CUTOVER moves the cutover the default scan applies.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# pattern p-14).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/record-name.mjs"
SCAN_ROOT="${RECORD_NAME_SCAN_ROOT:-$REPO_ROOT}"
CUTOVER="${RECORD_NAME_CUTOVER:-20261026}"

if ! command -v node >/dev/null 2>&1; then
  echo "Record name gate: node is not on PATH; cannot scan names." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Record name gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

FILES=()
STAGED=0
while (( $# > 0 )); do
  case "$1" in
    --staged)
      STAGED=1
      while IFS= read -r -d '' file; do
        FILES+=("$file")
      done < <(git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACMR -z -- 'devlog/discussions/*.md' ':(exclude)devlog/discussions/archive/**')
      shift
      ;;
    *)
      FILES+=("$1")
      shift
      ;;
  esac
done

cd "$REPO_ROOT" || exit 1

if (( ${#FILES[@]} > 0 )); then
  if (( STAGED )); then
    node "$SCAN_SCRIPT" --root="$SCAN_ROOT" --cutover="$CUTOVER" "${FILES[@]}"
  else
    node "$SCAN_SCRIPT" --root="$SCAN_ROOT" --force "${FILES[@]}"
  fi
  rc=$?
else
  node "$SCAN_SCRIPT" --root="$SCAN_ROOT" --cutover="$CUTOVER"
  rc=$?
fi

if (( rc == 0 )); then
  echo "Clean (${SECONDS}s)"
fi
exit "$rc"
