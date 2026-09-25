#!/usr/bin/env bash
# Bite sweep for scripts/workflows/apply.sh. Each mutation runs the full suite.
# Literal old/new text is passed through the environment so perl cannot
# interpolate the shell variables that the source itself contains.
set -uo pipefail
REPO=/home/agentuser/sandbox
F="$REPO/scripts/workflows/apply.sh"
ORIG=/tmp/apply.orig
cp "$F" "$ORIG"

bite() {
  local name="$1" old="$2" new="$3"
  cp "$ORIG" "$F"
  OLD="$old" NEW="$new" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$F"
  if cmp -s "$F" "$ORIG"; then
    echo "NO-OP    $name   (mutation left the file unchanged)"
    return
  fi
  local out rc=0
  out=$(cd "$REPO" && timeout 900 bash scripts/run_tests.sh 2>&1) || rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "PROVEN   $name"
    printf '%s\n' "$out" | grep -E "^  FAIL: " | head -3 | sed 's/^/           /'
  else
    echo "SURVIVED $name"
  fi
  cp "$ORIG" "$F"
}

bite A1-required-args-guard 'if [[ -z "$PROJECT_DIR" || -z "$DIFF_FILE" ]]; then' 'if false; then'
bite A2-diff-not-found-guard 'if [[ ! -f "$DIFF_FILE" ]]; then' 'if false; then'
bite A3-unreadable-tree-arm 'if [[ "$_tree_rc" -eq 2 ]]; then' 'if false; then'
bite A4-dirty-tree-arm 'if [[ "$_tree_rc" -eq 1 ]]; then' 'if false; then'
bite A5-forceless-refusal 'if [[ "$FORCE" != true ]]; then' 'if false; then'
bite A6-force-warning-block '    echo "Warning: make apply --force tolerates a dirty working tree." >&2
    echo "  Uncommitted or untracked changes are present; some hunks may fail to apply cleanly." >&2
    echo "  Review .rej files and the full tree state before proceeding." >&2' '    : # warning removed'
bite A7-existing-branch-arm 'if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$APPLY_BRANCH"; then' 'if false; then'
bite A8-always-patch 'if diff_is_empty "$DIFF_FILE"; then' 'if false; then'
bite A9-count-double-emit 'FILES_CHANGED=$(grep -c "^diff --git" "$DIFF_FILE" || true)' 'FILES_CHANGED=$(grep -c "^diff --git" "$DIFF_FILE" || echo 0)'
bite A10-count-default 'FILES_CHANGED=${FILES_CHANGED:-0}' ': # default removed'
bite A11-preview-path-strip '      file=${file#a/}
' '      : # strip removed
'
bite A12-preview-empty-arm 'if [[ "$has_changes" == false ]]; then' 'if false; then'
bite A13-unused-sandbox-guard 'if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then' 'if [[ -z "$PROJECT_DIR" ]]; then'
bite A14-requires-diff-guard 'if [[ -z "$DIFF_FILE" ]]; then' 'if false; then'
bite A15-help-handler '  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1
' '  local rc=0
'
bite A16-parse-verdict 'if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1' ': # verdict removed'
bite A17-interactive-abort 'interactive_confirm_or_abort "Apply:" "$DIFF_FILE" || exit 1' 'interactive_confirm_or_abort "Apply:" "$DIFF_FILE" || true'
bite A18-interactive-exit-status '    apply_run "$PROJECT_DIR" "$DIFF_FILE" "$APPLY_BRANCH" "$FORCE"
    exit $?' '    apply_run "$PROJECT_DIR" "$DIFF_FILE" "$APPLY_BRANCH" "$FORCE"
    exit 0'
bite A19-interactive-branch 'if [[ "$INTERACTIVE" == true ]]; then' 'if false; then'
bite A20-branch-forwarding '  apply_run "$PROJECT_DIR" "$DIFF_FILE" "$APPLY_BRANCH" "$FORCE"
}' '  apply_run "$PROJECT_DIR" "$DIFF_FILE" "" "$FORCE"
}'
bite A21-force-tail-text '  if [[ "$FORCE" == true ]]; then
    echo "Force mode: check for .rej files and resolve any failed hunks."' '  if false; then
    echo "Force mode: check for .rej files and resolve any failed hunks."'
bite A22-usage-to-stderr '    usage >&2
    exit 1' '    usage
    exit 1'

cp "$ORIG" "$F"
cmp -s "$F" "$ORIG" && echo && echo "restored byte-identical to $ORIG"
