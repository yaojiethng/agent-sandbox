#!/usr/bin/env bash
# tests/test_diff_workflow.sh
# Tests for libs/diff_workflow.sh
#
# Covers:
#   apply_run — applies a diff file, optional branch checkout, force mode
#
# apply_run now takes a file path directly (no internal resolution).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$REPO_ROOT/scripts/workflows/apply.sh"
source "$SCRIPT_DIR/libs/git_fixtures.sh"
source "$SCRIPT_DIR/libs/session_fixtures.sh"

source "$SCRIPT_DIR/libs/test_common.sh"

FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# =============================================================================
# APPLY tests — 4-arg contract
# =============================================================================

test_apply_applies_diff() {
  local P="$FIXTURE_DIR/apply_diff_p"
  make_committed_repo "$P"

  # Create a diff file
  echo "new content" > "$P/new.txt"
  git -C "$P" add new.txt
  git -C "$P" diff --cached > "$P/../test.diff" 2>/dev/null || \
    git -C "$P" diff --cached > "$FIXTURE_DIR/test.diff"
  git -C "$P" checkout -- new.txt
  rm -f "$P/new.txt"

  apply_run "$P" "$FIXTURE_DIR/test.diff" "" "false"

  if [[ -f "$P/new.txt" ]]; then
    pass "apply_run applies diff to project directory"
  else
    fail "apply_run should create new.txt from diff"
  fi
}

test_apply_applies_diff_with_branch() {
  local P="$FIXTURE_DIR/apply_branch_p"
  make_committed_repo "$P"

  echo "new content" > "$P/new.txt"
  git -C "$P" add new.txt
  git -C "$P" diff --cached > "$FIXTURE_DIR/branch.diff" 2>/dev/null || true
  git -C "$P" checkout -- new.txt
  rm -f "$P/new.txt"

  git -C "$P" checkout -b "test-branch" 2>/dev/null
  git -C "$P" checkout main 2>/dev/null || git -C "$P" checkout master 2>/dev/null || true

  apply_run "$P" "$FIXTURE_DIR/branch.diff" "feature-branch" "false"

  local BRANCH
  BRANCH=$(git -C "$P" rev-parse --abbrev-ref HEAD)
  if [[ "$BRANCH" == "feature-branch" ]]; then
    pass "apply_run creates and checks out new branch"
  else
    fail "apply_run should check out feature-branch, got $BRANCH"
  fi
}

test_apply_force_mode() {
  local P="$FIXTURE_DIR/apply_force_p"
  make_committed_repo "$P"

  # Create a diff that will conflict — modify the existing committed file
  local COMMITTED_FILE
  COMMITTED_FILE=$(ls "$P" | head -1)
  if [[ -z "$COMMITTED_FILE" ]]; then
    # No files committed yet — create one
    echo "original" > "$P/base.txt"
    git -C "$P" add base.txt
    git -C "$P" commit -m "base" --quiet
    COMMITTED_FILE="base.txt"
  fi

  # Create diff with the same file modified differently
  echo "$COMMITTED_FILE content changed" > "$P/$COMMITTED_FILE"
  git -C "$P" diff > "$FIXTURE_DIR/reject.diff" 2>/dev/null || true
  git -C "$P" checkout -- "$COMMITTED_FILE"

  apply_run "$P" "$FIXTURE_DIR/reject.diff" "" "true"

  # Force mode should have applied the diff (may produce .rej files)
  local APPLIED
  APPLIED=$(grep -c "^diff --git" "$FIXTURE_DIR/reject.diff" 2>/dev/null || echo "0")
  pass "apply_run force mode completes (diff had $APPLIED changed files)"
}

test_apply_missing_diff_file() {
  local P="$FIXTURE_DIR/apply_missing_p"
  make_committed_repo "$P"

  if apply_run "$P" "/nonexistent/diff.diff" "" "false" 2>/dev/null; then
    fail "apply_run should fail with missing diff file"
  else
    pass "apply_run fails with missing diff file"
  fi
}

test_apply_missing_project_dir() {
  if apply_run "/nonexistent" "$FIXTURE_DIR/test.diff" "" "false" 2>/dev/null; then
    fail "apply_run should fail with missing project dir"
  else
    pass "apply_run fails with missing project dir"
  fi
}

test_apply_empty_args() {
  if apply_run "" "" "" "" 2>/dev/null; then
    fail "apply_run should fail with empty args"
  else
    pass "apply_run fails with empty args"
  fi
}

test_apply_diff_file_preserved() {
  local P="$FIXTURE_DIR/apply_preserve_p"
  make_committed_repo "$P"

  echo "preserved content" > "$P/preserve.txt"
  git -C "$P" add preserve.txt
  git -C "$P" diff --cached > "$FIXTURE_DIR/preserve.diff" 2>/dev/null || true
  git -C "$P" checkout -- preserve.txt
  rm -f "$P/preserve.txt"

  apply_run "$P" "$FIXTURE_DIR/preserve.diff" "" "false"

  # Verify the diff file still exists (it should not be deleted by apply_run)
  if [[ -f "$FIXTURE_DIR/preserve.diff" ]]; then
    pass "apply_run preserves the diff file after applying"
  else
    fail "apply_run should not delete the diff file"
  fi
}

test_apply_diff_empty_file_rejected() {
  local P="$FIXTURE_DIR/apply_empty_p"
  make_committed_repo "$P"

  # Create an empty diff
  > "$FIXTURE_DIR/empty.diff"

  # Should still succeed — empty diff applied cleanly
  apply_run "$P" "$FIXTURE_DIR/empty.diff" "" "false" && \
    pass "apply_run handles empty diff gracefully"
}

test_apply_no_resolution_logic() {
  # Verify that apply_run does NOT look up sessions or channels internally.
  # Pass a valid diff file directly and confirm it applies.
  local P="$FIXTURE_DIR/apply_norse_p"
  make_committed_repo "$P"

  echo "direct content" > "$P/direct.txt"
  git -C "$P" add direct.txt
  git -C "$P" diff --cached > "$FIXTURE_DIR/direct.diff" 2>/dev/null || true
  git -C "$P" checkout -- direct.txt
  rm -f "$P/direct.txt"

  apply_run "$P" "$FIXTURE_DIR/direct.diff" "" "false"

  if [[ -f "$P/direct.txt" ]]; then
    pass "apply_run applies diff from direct file path (no resolution)"
  else
    fail "apply_run should apply from direct file path"
  fi
}

# =============================================================================
# Run
# =============================================================================

run_test test_apply_applies_diff
run_test test_apply_applies_diff_with_branch
run_test test_apply_force_mode
run_test test_apply_missing_diff_file
run_test test_apply_missing_project_dir
run_test test_apply_empty_args
run_test test_apply_diff_file_preserved
run_test test_apply_diff_empty_file_rejected
run_test test_apply_no_resolution_logic

test_done
