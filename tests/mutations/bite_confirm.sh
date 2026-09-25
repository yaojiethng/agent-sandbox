#!/usr/bin/env bash
# Bite sweep for scripts/workflows/confirm.sh. Each mutation runs the full suite.
set -uo pipefail
REPO=/home/agentuser/sandbox
F="$REPO/scripts/workflows/confirm.sh"
ORIG=/tmp/confirm.orig
cp "$F" "$ORIG"

bite() {
  local name="$1" old="$2" new="$3"
  cp "$ORIG" "$F"
  OLD="$old" NEW="$new" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$F"
  if cmp -s "$F" "$ORIG"; then echo "NO-OP    $name"; return; fi
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

bite C1-project-validation 'validate_project_dir "$PROJECT_DIR" || return 1' ': # project validation removed'
bite C2-stale-lock-clear 'draft_clear_stale_lock "$PROJECT_DIR" || return 1' ': # stale-lock clear removed'
bite C3-validation-verdict 'DRAFT_VALIDATION=$(draft_validate_branch "$PROJECT_DIR") || return 1' 'DRAFT_VALIDATION=$(draft_validate_branch "$PROJECT_DIR")'
bite C4-eval-of-state 'eval "$DRAFT_VALIDATION"' ': # state not loaded'
bite C5-new-requires-target 'if [[ -z "$TARGET_BRANCH" ]]; then' 'if false; then'
bite C6-new-rejects-existing 'if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then' 'if false; then'
bite C7-target-exists-check 'if ! git -C "$PROJECT_DIR" rev-parse --verify "$MERGE_TARGET" >/dev/null 2>&1; then' 'if false; then'
bite C8-merge-target-default 'MERGE_TARGET="${TARGET_BRANCH:-$source_branch}"' 'MERGE_TARGET="$TARGET_BRANCH"'
bite C9-savepoint-capture 'SAVEPOINT_COMMIT=$(git -C "$PROJECT_DIR" rev-parse HEAD)' 'SAVEPOINT_COMMIT=""'
bite C10-drop-state-commit 'if ! git -C "$PROJECT_DIR" rebase --onto "${DRAFT_STATE_COMMIT}^" "$DRAFT_STATE_COMMIT" "$CURRENT_BRANCH"; then' 'if false; then'
bite C11-drop-failure-rollback '      git -C "$PROJECT_DIR" rebase --abort 2>/dev/null || true
      git -C "$PROJECT_DIR" reset --hard "$SAVEPOINT_COMMIT"
      echo "Error: failed to drop .draft-state commit" >&2' '      git -C "$PROJECT_DIR" rebase --abort 2>/dev/null || true
      echo "Error: failed to drop .draft-state commit" >&2'
bite C12-new-mode-dispatch 'if [[ "$NEW_MODE" == true ]]; then
    _confirm_into_new_branch' 'if false; then
    _confirm_into_new_branch'
bite C13-new-mode-verdict '      "$source_branch" "$SAVEPOINT_COMMIT"
    return $?' '      "$source_branch" "$SAVEPOINT_COMMIT"
    return 0'
bite C14-new-branch-failure-rollback '    git -C "$PROJECT_DIR" reset --hard "$SAVEPOINT_COMMIT"
    echo "Error: failed to create branch $NEW_BRANCH" >&2' '    echo "Error: failed to create branch $NEW_BRANCH" >&2'
bite C15-draft-delete-masked 'git -C "$PROJECT_DIR" branch -D "$DRAFT_BRANCH" >/dev/null 2>&1 || true' 'git -C "$PROJECT_DIR" branch -D "$DRAFT_BRANCH"'
bite C16-rebase-step 'if ! git -C "$PROJECT_DIR" rebase "$MERGE_TARGET" "$CURRENT_BRANCH"; then' 'if false; then'
bite C17-conflict-abort 'git -C "$PROJECT_DIR" rebase --abort 2>/dev/null || true' 'git -C "$PROJECT_DIR" rebase --abort'
bite C18-conflict-hint-text 'echo "Resolve the divergence on the draft branch, then run '"'"'make confirm'"'"' again." >&2' 'echo "detail removed" >&2'
bite C19-switch-to-target 'git -C "$PROJECT_DIR" switch "$MERGE_TARGET"' ': # no switch'
bite C20-ff-only 'git -C "$PROJECT_DIR" merge --ff-only "$CURRENT_BRANCH"' 'git -C "$PROJECT_DIR" merge "$CURRENT_BRANCH"'
bite C21-final-delete 'git -C "$PROJECT_DIR" branch -D "$CURRENT_BRANCH"' 'git -C "$PROJECT_DIR" branch -D "$CURRENT_BRANCH" || true'
bite C22-new-mode-default 'local NEW_MODE="${4:-false}"' 'local NEW_MODE="${4:?}"'
bite C23-main-guard 'if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then' 'if false; then'
bite C24-help-handler '  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1
' '  local rc=0
'
bite C25-merged-message 'echo "Done. Changes merged into $MERGE_TARGET."' 'echo "Done."'

cp "$ORIG" "$F"
cmp -s "$F" "$ORIG" && echo && echo "restored byte-identical to $ORIG"
