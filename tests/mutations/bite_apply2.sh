#!/usr/bin/env bash
set -uo pipefail
REPO=/home/agentuser/sandbox
F="$REPO/scripts/workflows/apply.sh"
ORIG=/tmp/apply.orig
cp "$F" "$ORIG"
bite() {
  local name="$1" old="$2" new="$3"
  cp "$ORIG" "$F"
  OLD="$old" NEW="$new" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$F"
  cmp -s "$F" "$ORIG" && { echo "NO-OP    $name"; return; }
  local out rc=0
  out=$(cd "$REPO" && timeout 900 bash scripts/run_tests.sh 2>&1) || rc=$?
  if [[ $rc -ne 0 ]]; then echo "PROVEN   $name"; printf '%s\n' "$out" | grep -E "^  FAIL: " | head -3 | sed 's/^/           /';
  else echo "SURVIVED $name"; fi
  cp "$ORIG" "$F"
}
bite A23-count-no-or-true 'FILES_CHANGED=$(grep -c "^diff --git" "$DIFF_FILE" || true)' 'FILES_CHANGED=$(grep -c "^diff --git" "$DIFF_FILE")'
bite A25-stale-lock-clear 'draft_clear_stale_lock "$PROJECT_DIR" || return 1' ': # stale-lock clear removed'
bite A26-validate-project-dir 'validate_project_dir "$PROJECT_DIR" || return 1' ': # project validation removed'
cp "$ORIG" "$F"; cmp -s "$F" "$ORIG" && echo "restored byte-identical"
