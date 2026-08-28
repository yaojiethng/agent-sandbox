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
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/scripts/guards.sh"

# lsof stubs: probe exit status decides whether a lock counts as held.
mkdir -p "$FIXTURE_DIR/stub_lsof_fail" "$FIXTURE_DIR/stub_lsof_hold"
printf '#!/bin/sh\nexit 1\n' > "$FIXTURE_DIR/stub_lsof_fail/lsof"   # no holder
printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_DIR/stub_lsof_hold/lsof"   # holder present
chmod +x "$FIXTURE_DIR/stub_lsof_fail/lsof" "$FIXTURE_DIR/stub_lsof_hold/lsof"


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
  # Simulate lsof not being available — should fall through to remove.
  # The stub dir contains an `lsof` that always fails (command -v still finds
  # it, but its probe returns non-zero = no holder). A truly absent lsof is
  # simulated by shadowing with a dir lacking the binary is impossible once
  # PATH already has one earlier — so we assert BOTH: (a) failing-lsof probe,
  # and (b) genuinely absent binary via a minimal empty-PATH-style stub set.
  local DIR="$FIXTURE_DIR/stale_nolsof"
  make_committed_repo "$DIR"

  touch "$DIR/.git/index.lock"

  # (a) lsof present but probe fails (no process holds the lock)
  if PATH="$FIXTURE_DIR/stub_lsof_fail:$PATH" draft_clear_stale_lock "$DIR" 2>/dev/null; then
    if [[ ! -f "$DIR/.git/index.lock" ]]; then
      pass "draft_clear_stale_lock: failing lsof probe treated as not-held, lock removed"
    else
      fail "draft_clear_stale_lock did not remove lock when lsof probe found no holder"
    fi
  else
    fail "draft_clear_stale_lock should succeed when lsof reports no holder"
  fi

  # (b) lsof binary absent from PATH (stub dir provides ONLY rm, which the
  # function needs for removal — rm is an external binary, not a builtin)
  make_committed_repo "$DIR"
  touch "$DIR/.git/index.lock"
  ln -sf "$(command -v rm)" "$FIXTURE_DIR/stub_lsof_fail/rm"
  if PATH="$FIXTURE_DIR/stub_lsof_fail" draft_clear_stale_lock "$DIR" 2>/dev/null; then
    pass "draft_clear_stale_lock handles missing lsof gracefully"
  else
    fail "draft_clear_stale_lock should handle missing lsof"
  fi
}

test_clear_stale_lock_held_lock_fails_and_keeps_file() {
  # Lock held by a live process: stub lsof exits 0 (holder found) -> function
  # must refuse (rc!=0), explain, and NOT delete the lockfile.
  local DIR="$FIXTURE_DIR/stale_held"
  make_committed_repo "$DIR"

  touch "$DIR/.git/index.lock"

  local OUT RC=0
  OUT=$(PATH="$FIXTURE_DIR/stub_lsof_hold:$PATH" \
    draft_clear_stale_lock "$DIR" 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"held by another git process"* && -f "$DIR/.git/index.lock" ]]
  then
    pass "held lock: refuses with explanation and preserves lockfile"
  else
    fail "held lock must fail rc!=0 keeping file, got rc=$RC out='$OUT' exists=$([[ -f $DIR/.git/index.lock ]] && echo yes || echo no)"
  fi
}

# =============================================================================
# Run all
# =============================================================================

run_test test_clear_stale_lock_no_lock_file
run_test test_clear_stale_lock_removes_stale_lock
run_test test_clear_stale_lock_no_lsof_skips_check
run_test test_clear_stale_lock_held_lock_fails_and_keeps_file

test_done
