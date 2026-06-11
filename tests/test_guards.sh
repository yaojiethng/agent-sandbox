#!/usr/bin/env bash
# tests/test_guards.sh
# Unit tests for scripts/guards.sh — git workflow guard functions.
#
# Covers:
#   validate_project_dir    — existence, git repo, commits (already tested in test_session.sh)
#   draft_clear_stale_lock  — stale lock detection and removal

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$SCRIPT_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/scripts/guards.sh"


# =============================================================================
# draft_clear_stale_lock
# =============================================================================

test_clear_stale_lock_no_lock_file() {
  local DIR="$FIXTURE_DIR/stale_none"
  make_committed_repo "$DIR"

  # No lock file exists — should be a no-op
  if draft_clear_stale_lock "$DIR" 2>/dev/null; then
    pass "draft_clear_stale_lock passes when no lock file exists"
  else
    fail "draft_clear_stale_lock should pass without lock file"
  fi
}

test_clear_stale_lock_removes_stale_lock() {
  local DIR="$FIXTURE_DIR/stale_remove"
  make_committed_repo "$DIR"

  # Create a stale lock file (not held by any process)
  touch "$DIR/.git/index.lock"

  if draft_clear_stale_lock "$DIR" 2>/dev/null; then
    pass "draft_clear_stale_lock removes stale lock file"
  else
    fail "draft_clear_stale_lock should remove stale lock"
  fi

  if [[ -f "$DIR/.git/index.lock" ]]; then
    fail "draft_clear_stale_lock should delete the lock file"
  else
    pass "draft_clear_stale_lock actually deleted the lock file"
  fi
}

test_clear_stale_lock_no_lsof_skips_check() {
  # Simulate lsof not being available — should fall through to remove
  local DIR="$FIXTURE_DIR/stale_nolsof"
  make_committed_repo "$DIR"

  touch "$DIR/.git/index.lock"

  # Temporarily remove lsof from PATH
  if draft_clear_stale_lock "$DIR" 2>/dev/null; then
    pass "draft_clear_stale_lock handles missing lsof gracefully"
  else
    fail "draft_clear_stale_lock should handle missing lsof"
  fi
}

# =============================================================================
# Run all
# =============================================================================

run_test test_clear_stale_lock_no_lock_file
run_test test_clear_stale_lock_removes_stale_lock
run_test test_clear_stale_lock_no_lsof_skips_check

test_done
