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
# Scope: the default scan reads devlog/discussions/. Every live record is held
# to the shape: no date exempts one. A file
# named on the command line is the on-demand audit mode, and `--staged`
# enforces the records staged for commit.
#
# Test seam: RECORD_NAME_SCAN_ROOT points the scan at a fixture root.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# pattern p-14).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/record-name.mjs"
SCAN_ROOT="${RECORD_NAME_SCAN_ROOT:-$REPO_ROOT}"

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
      done < <(git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACMR -z -- 'devlog/discussions/*.md')
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
    node "$SCAN_SCRIPT" --root="$SCAN_ROOT" "${FILES[@]}"
  else
    node "$SCAN_SCRIPT" --root="$SCAN_ROOT" "${FILES[@]}"
  fi
  rc=$?
else
  node "$SCAN_SCRIPT" --root="$SCAN_ROOT"
  rc=$?
fi

if (( rc == 0 )); then
  echo "Clean (${SECONDS}s)"
fi
exit "$rc"
