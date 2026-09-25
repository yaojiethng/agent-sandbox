#!/usr/bin/env bash
# tests/test_guards.sh
# Unit tests for scripts/guards.sh  --  git workflow guard functions.
#
# Covers:
#   validate_project_dir     --  existence, git repo, commits (already tested in test_session.sh)
#   draft_clear_stale_lock   --  stale lock detection and removal

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/scripts/guards.sh"

# lsof stubs: probe exit status decides whether a lock counts as held.
mkdir -p "$FIXTURE_ROOT/stub_lsof_fail" "$FIXTURE_ROOT/stub_lsof_hold" "$FIXTURE_ROOT/stub_no_lsof"
printf '#!/bin/sh\nexit 1\n' > "$FIXTURE_ROOT/stub_lsof_fail/lsof"   # no holder
printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_ROOT/stub_lsof_hold/lsof"   # holder present
chmod +x "$FIXTURE_ROOT/stub_lsof_fail/lsof" "$FIXTURE_ROOT/stub_lsof_hold/lsof"
# A PATH holding only the rm the removal branch needs: lsof is genuinely absent.
ln -sf "$(command -v rm)" "$FIXTURE_ROOT/stub_no_lsof/rm"


# =============================================================================
# draft_clear_stale_lock
# =============================================================================

# Given: a committed repository with no .git/index.lock
# When:  draft_clear_stale_lock runs
# Then:  it returns 0, prints nothing, and leaves the repository untouched
# Asserts: the no-lock path is a silent no-op, not merely a successful one.
test_clear_stale_lock_no_lock_file() {
  local DIR="$FIXTURE_DIR/stale_none"
  make_committed_repo "$DIR"

  # No lock file exists  --  should be a silent no-op
  local OUT RC=0
  OUT=$(draft_clear_stale_lock "$DIR" 2>&1) || RC=$?
  assert_rc 0 "$RC" "draft_clear_stale_lock passes when no lock file exists"
  assert_empty "$OUT" "draft_clear_stale_lock prints nothing without a lock file"
  if [[ -f "$DIR/.git/index.lock" ]]; then
    fail "draft_clear_stale_lock created a lock file on the no-lock path"
  else
    pass "draft_clear_stale_lock leaves no lock file on the no-lock path"
  fi
}

# Given: a committed repository whose .git/index.lock no process holds
# When:  draft_clear_stale_lock runs
# Then:  it returns 0 and the lock file is gone
# Asserts: a stale lock is removed.
test_clear_stale_lock_removes_stale_lock() {
  local DIR="$FIXTURE_DIR/stale_remove"
  make_committed_repo "$DIR"

  # Create a stale lock file (not held by any process)
  touch "$DIR/.git/index.lock"

  if PATH="$FIXTURE_ROOT/stub_lsof_fail:$PATH" draft_clear_stale_lock "$DIR" 2>/dev/null; then
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

# Given: (a) a stub lsof whose probe reports no holder, and (b) a PATH with
#        no lsof at all
# When:  draft_clear_stale_lock runs on a repository with a lock file
# Then:  (a) removes the lock with rc 0; (b) refuses (rc non-zero) and keeps it
# Asserts: an absent holder probe fails closed -- removing a lock that may be
#          held corrupts the index.
test_clear_stale_lock_no_lsof_skips_check() {
  local DIR="$FIXTURE_DIR/stale_nolsof"
  make_committed_repo "$DIR"

  touch "$DIR/.git/index.lock"

  # (a) lsof present but probe fails (no process holds the lock)
  if PATH="$FIXTURE_ROOT/stub_lsof_fail:$PATH" draft_clear_stale_lock "$DIR" 2>/dev/null; then
    if [[ ! -f "$DIR/.git/index.lock" ]]; then
      pass "draft_clear_stale_lock: failing lsof probe treated as not-held, lock removed"
    else
      fail "draft_clear_stale_lock did not remove lock when lsof probe found no holder"
    fi
  else
    fail "draft_clear_stale_lock should succeed when lsof reports no holder"
  fi

  # (b) lsof genuinely absent from PATH (the stub dir provides only rm, which
  # the removal branch needs  --  rm is an external binary, not a builtin).
  make_committed_repo "$DIR"
  touch "$DIR/.git/index.lock"
  local OUT RC=0
  OUT=$(PATH="$FIXTURE_ROOT/stub_no_lsof" draft_clear_stale_lock "$DIR" 2>&1) || RC=$?
  assert_ne "0" "$RC" "draft_clear_stale_lock fails closed when lsof is absent"
  assert_contains "$OUT" "lsof is not installed" "draft_clear_stale_lock names the absent probe"
  if [[ -f "$DIR/.git/index.lock" ]]; then
    pass "draft_clear_stale_lock keeps the lock when the probe is absent"
  else
    fail "draft_clear_stale_lock removed the lock without a holder probe"
  fi
}

# Given: a stub lsof whose probe reports a live holder
# When:  draft_clear_stale_lock runs on a repository with a lock file
# Then:  it returns non-zero, names the holder, and keeps the lock file
# Asserts: a held lock is refused, not removed.
test_clear_stale_lock_held_lock_fails_and_keeps_file() {
  # Lock held by a live process: stub lsof exits 0 (holder found) -> function
  # must refuse (rc!=0), explain, and NOT delete the lockfile.
  local DIR="$FIXTURE_DIR/stale_held"
  make_committed_repo "$DIR"

  touch "$DIR/.git/index.lock"

  local OUT RC=0
  OUT=$(PATH="$FIXTURE_ROOT/stub_lsof_hold:$PATH" \
    draft_clear_stale_lock "$DIR" 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"held by another process"* && -f "$DIR/.git/index.lock" ]]
  then
    pass "held lock: refuses with explanation and preserves lockfile"
  else
    fail "held lock must fail rc!=0 keeping file, got rc=$RC out='$OUT' exists=$([[ -f $DIR/.git/index.lock ]] && echo yes || echo no)"
  fi
}

# =============================================================================
# require_clean_working_tree
# =============================================================================

# Given: a clean tree, a dirty tree, and a directory git cannot read
# When:  require_clean_working_tree runs on each
# Then:  the verdicts are 0, 1, and 2, and stderr stays empty
# Asserts: the caller owns the message; the function is silent on every verdict.
test_require_clean_working_tree_is_silent() {
  local DIR="$FIXTURE_DIR/clean_tree_silent"
  make_committed_repo "$DIR"
  local OUT RC=0

  OUT=$(require_clean_working_tree "$DIR" 2>&1) || RC=$?
  assert_rc 0 "$RC" "clean tree: verdict 0"
  assert_empty "$OUT" "clean tree: prints nothing"

  touch "$DIR/untracked.txt"
  RC=0
  OUT=$(require_clean_working_tree "$DIR" 2>&1) || RC=$?
  assert_rc 1 "$RC" "dirty tree: verdict 1"
  assert_empty "$OUT" "dirty tree: prints nothing"

  RC=0
  OUT=$(require_clean_working_tree "$FIXTURE_DIR/no_such_repo" 2>&1) || RC=$?
  assert_rc 2 "$RC" "unreadable tree: verdict 2"
  assert_empty "$OUT" "unreadable tree: prints nothing"
}

# =============================================================================
# validate_project_dir
# =============================================================================

# Given: a nonexistent path, a non-repository directory, and a repo with no commits
# When:  validate_project_dir runs on each
# Then:  each is refused with the message of the check that refused it
# Asserts: the three refusals are individually observable.
test_validate_project_dir_refusal_messages() {
  local OUT RC=0

  OUT=$(validate_project_dir "$FIXTURE_DIR/does_not_exist" 2>&1) || RC=$?
  assert_ne "0" "$RC" "validate: a nonexistent dir is refused"
  assert_contains "$OUT" "PROJECT_DIR does not exist" "validate: nonexistent dir names the existence check"

  local NOTREPO="$FIXTURE_DIR/not_a_repo"
  mkdir -p "$NOTREPO"
  RC=0
  OUT=$(validate_project_dir "$NOTREPO" 2>&1) || RC=$?
  assert_ne "0" "$RC" "validate: a non-repository dir is refused"
  assert_contains "$OUT" "is not a git repository" "validate: non-repo names the git-dir check"

  local EMPTY="$FIXTURE_DIR/empty_repo"
  make_repo "$EMPTY"
  RC=0
  OUT=$(validate_project_dir "$EMPTY" 2>&1) || RC=$?
  assert_ne "0" "$RC" "validate: a repo with no commits is refused"
  assert_contains "$OUT" "has no commits" "validate: no-commits names the HEAD check"
}

# =============================================================================
# clean_tree_hint / clean_tree_hint_unreadable
# =============================================================================

# Given: the two hint functions
# When:  each runs
# Then:  its full two-line remedy is printed
# Asserts: the operator-facing wording is pinned in full.
test_clean_tree_hint_text() {
  local OUT
  OUT=$(clean_tree_hint 2>&1)
  local EXPECTED=$'  Uncommitted or untracked changes are present.\n  Stash them (git stash) or commit them first.'
  assert_eq "$OUT" "$EXPECTED" "clean_tree_hint prints both remedy lines"

  OUT=$(clean_tree_hint_unreadable 2>&1)
  EXPECTED=$'  The repository state could not be read (corrupt or locked index).\n  Check \'git status\' in the project directory, then retry.'
  assert_eq "$OUT" "$EXPECTED" "clean_tree_hint_unreadable prints both remedy lines"
}

# =============================================================================
# Run all
# =============================================================================

run_test test_clear_stale_lock_no_lock_file
run_test test_clear_stale_lock_removes_stale_lock
run_test test_clear_stale_lock_no_lsof_skips_check
run_test test_clear_stale_lock_held_lock_fails_and_keeps_file
run_test test_require_clean_working_tree_is_silent
run_test test_validate_project_dir_refusal_messages
run_test test_clean_tree_hint_text

test_done
