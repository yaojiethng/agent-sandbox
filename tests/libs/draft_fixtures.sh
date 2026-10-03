#!/usr/bin/env bash
# tests/libs/draft_fixtures.sh
# Shared fixtures for the draft/confirm/reject workflow test families.
#
# These helpers are used by two or more of:
#   tests/test_draft_workflow.sh
#   tests/test_confirm_workflow.sh
#   tests/test_reject_workflow.sh
# and are therefore filed here per testing_policy.md "Shared Fixtures"
# (a helper belongs in tests/libs/ if and only if it is used by two or more
# test files).
#
# A caller must source the workflow script it exercises (draft.sh/confirm.sh/
# reject.sh) before these helpers run: several call draft.sh's functions.

# draft_branch DIR  --  the working draft branch in DIR, or empty.
draft_branch() {
  git -C "$1" branch --list 'draft/*' | tr -d ' *' | head -1
}

# _current_branch DIR
_current_branch() {
  git -C "$1" rev-parse --abbrev-ref HEAD
}

# _branch_exists DIR NAME
_branch_exists() {
  git -C "$1" show-ref --verify --quiet "refs/heads/$2" 2>/dev/null
}

# =============================================================================
# _test_draft_run  --  draft orchestration prologue for the workflow suites
#
# Delegates to production's _run_draft_workflow with force off, so the units
# exercise the real orchestration (savepoint, apply loop, rollback, and the
# uncommitted-only path). The signature keeps the historical argument order
# the callers use: PROJECT_DIR SOURCE_DIR BUNDLE_NAME BRANCH_FROM DIFFS
# BRANCH_SUMMARY.
# =============================================================================
_test_draft_run() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" BUNDLE_NAME="$3"
  local BRANCH_FROM="$4" DIFFS="$5" BRANCH_SUMMARY="$6"

  _run_draft_workflow "$PROJECT_DIR" "$SOURCE_DIR" "$BUNDLE_NAME" \
    "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY" false
}