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
# _test_draft_run  --  backward-compat wrapper for old draft_run callers
#
# Replicates the old draft_run contract (create branch + apply patches +
# apply uncommitted) using the new decomposed functions.
# Signature matches old draft_run: PROJECT_DIR SOURCE_DIR BUNDLE_NAME
# BRANCH_FROM DIFFS BRANCH_SUMMARY
# =============================================================================
_test_draft_run() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" BUNDLE_NAME="$3"
  local BRANCH_FROM="$4" DIFFS="$5" BRANCH_SUMMARY="$6"

  local PATCHES_DIR="$SOURCE_DIR/patches"
  local PATCH_LIST
  PATCH_LIST=$(draft_collect_patches "$PATCHES_DIR" "$DIFFS" || true)
  local DIFF_COUNT
  DIFF_COUNT=$(echo "$PATCH_LIST" | grep -c . || true)
  if [[ "$DIFF_COUNT" -eq 0 ]]; then
    echo "Error: no .diff files found in $PATCHES_DIR" >&2
    return 1
  fi

  local AUTHOR
  AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"

  draft_run "$PROJECT_DIR" "$SOURCE_DIR" "$BUNDLE_NAME" \
    "$BRANCH_FROM" "$BRANCH_SUMMARY" "$DIFF_COUNT" "$AUTHOR" || return 1

  echo "$PATCH_LIST" | draft_apply_patches "$PROJECT_DIR" "$AUTHOR" false || return 1
  draft_apply_uncommitted "$PROJECT_DIR" "$SOURCE_DIR" "$AUTHOR" false || return 1
}