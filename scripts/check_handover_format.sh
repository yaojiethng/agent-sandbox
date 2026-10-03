#!/usr/bin/env bash
# scripts/check_handover_format.sh
# Handover format gate over the handovers dated on or after the cutover, and
# over any file named on the command line.
#
# Enforces docs/operations/handover_policy.md `## Format`: the frontmatter
# fields and the section set. The scanner is scripts/lint/handover-format.mjs.
#
# Scope: the default scan reads the live handover folder, which the archive
# keeps free of every record written before the frontmatter rule. A live record
# that lacks the block is a finding. A file named on the command line is
# enforced regardless of date, which is the on-demand audit mode
# handover-maintenance.md uses. `--staged` enforces the handovers staged for
# commit but keeps the cutover, so a commit correcting an old record is not
# blocked.
#
# Test seam: HANDOVER_FORMAT_SCAN_ROOT points the scan at a fixture root, and
# HANDOVER_FORMAT_CUTOVER moves the cutover the default scan applies.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# docs/development/bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/handover-format.mjs"
SCAN_ROOT="${HANDOVER_FORMAT_SCAN_ROOT:-$REPO_ROOT}"
CUTOVER="${HANDOVER_FORMAT_CUTOVER:-20261001}"

if ! command -v node >/dev/null 2>&1; then
  echo "Handover format gate: node is not on PATH; cannot parse frontmatter." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Handover format gate: $SCAN_SCRIPT is missing; cannot run." >&2
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
      done < <(git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACMR -z -- 'devlog/handovers/*.md')
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
    # The cutover still applies: a corrected old record stays exempt.
    node "$SCAN_SCRIPT" --root="$SCAN_ROOT" "${FILES[@]}"
  else
    # A named file is the on-demand audit: enforce it whatever its date.
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
