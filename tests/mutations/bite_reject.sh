#!/usr/bin/env bash
# Bite sweep for scripts/workflows/reject.sh  --  each mutation runs the FULL suite.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
SRC=scripts/workflows/reject.sh
BAK=/tmp/reject.orig
cp "$SRC" "$BAK"

run_one() {  # NAME OLD NEW
  local name="$1" old="$2" new="$3"
  OLD="$old" NEW="$new" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$SRC"
  if cmp -s "$SRC" "$BAK"; then
    echo "RESULT|$name|NO-OP|mutation did not apply"
    cp "$BAK" "$SRC"; return
  fi
  local out; out="$(timeout 600 bash scripts/run_tests.sh 2>&1)"
  local verdict detail=""
  if grep -q "0 failed" <<<"$out"; then
    verdict="survived"
  else
    verdict="PROVEN"
    local one; one="$(timeout 300 bash tests/test_reject_workflow.sh 2>&1 || true)"
    detail="$(grep -E "^  (FAIL|not ok):" <<<"$one" | head -3 | tr '\n' ';')"
    if [[ -z "$detail" ]]; then
      detail="$(grep -E "^(FAIL|.*FAIL:)" <<<"$one" | head -3 | tr '\n' ';')"
    fi
    [[ -z "$detail" ]] && detail="no reject-unit failure named (suite failed elsewhere): $(grep -oE '[0-9]+ failed' <<<"$out" | head -1)"
  fi
  echo "RESULT|$name|$verdict|$detail"
  cp "$BAK" "$SRC"
  cmp -s "$SRC" "$BAK" || echo "RESULT|$name|RESTORE-FAIL|"
}

run_one R1_validate_project_dir_verdict 'validate_project_dir "$PROJECT_DIR" || return 1' 'validate_project_dir "$PROJECT_DIR" || true'
run_one R2_stale_lock_verdict 'draft_clear_stale_lock "$PROJECT_DIR" || return 1' 'draft_clear_stale_lock "$PROJECT_DIR" || true'
run_one R3_validate_branch_verdict 'DRAFT_VALIDATION=$(draft_validate_branch "$PROJECT_DIR") || return 1' 'DRAFT_VALIDATION=$(draft_validate_branch "$PROJECT_DIR")'
run_one R4_eval_removed 'eval "$DRAFT_VALIDATION"' ': "$DRAFT_VALIDATION"'
run_one R5_rejecting_message 'echo "Rejecting draft. Returning to $source_branch..."' 'echo "returning..."'
run_one R6_force_checkout_dropped 'git -C "$PROJECT_DIR" checkout -f "$source_branch"' 'true'
run_one R7_clean_fd_dropped 'git -C "$PROJECT_DIR" clean -fd' 'true'
run_one R8_delete_guard_false 'if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$CURRENT_BRANCH" 2>/dev/null; then' 'if false; then'
run_one R9_safe_delete 'git -C "$PROJECT_DIR" branch -D "$CURRENT_BRANCH"' 'git -C "$PROJECT_DIR" branch -d "$CURRENT_BRANCH"'
run_one R10_deleted_message 'echo "Deleted draft branch: $CURRENT_BRANCH"' 'echo "deleted"'
run_one R11_restored_message 'echo "Draft rejected. PROJECT_DIR restored to $source_branch."' 'echo "done"'
run_one R12_help_rc2_exit1 'if [[ $rc -eq 2 ]]; then exit 0; fi' 'if [[ $rc -eq 2 ]]; then exit 1; fi'
run_one R13_sandbox_required_dropped '[[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]' '[[ -z "$PROJECT_DIR" ]]'
run_one R14_checkout_stderr_suppressed 'if ! git -C "$PROJECT_DIR" checkout "$source_branch" 2>/dev/null; then' 'if ! git -C "$PROJECT_DIR" checkout "$source_branch"; then'
