#!/usr/bin/env bash
# tests/test_snapshot_host.sh
# Host-side snapshot pipeline tests.
#
# Covers:
#   snapshot_copy_worktree    --  mount-delivery worktree materialization (git-enumerated)
#   (snapshot_validate removed with the RO-mount pipeline; snapshot_archive_head
#    removed with the legacy seed transport — its guarantee lives in
#    test_seed_volume.sh now)
#
# All fixtures created under a temp dir  --  no repos created inside the harness repo.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/capability/snapshot.sh"
source "$TEST_DIR/libs/git_fixtures.sh"

# -------------------------
# Fixture builder
# -------------------------
# snapshot_copy_worktree tests
# -------------------------

test_worktree_copies_tracked_files() {
  local SRC="$FIXTURE_DIR/wt_tracked_src"
  local DST="$FIXTURE_DIR/wt_tracked_dst"
  make_committed_repo "$SRC"

  snapshot_copy_worktree "$SRC" "$DST"

  if [[ -f "$DST/file.txt" ]]; then
    pass "worktree: tracked file copied to destination"
  else
    fail "worktree: tracked file missing from destination"
  fi
}

test_worktree_excludes_gitignored_files() {
  local SRC="$FIXTURE_DIR/wt_ignore_src"
  local DST="$FIXTURE_DIR/wt_ignore_dst"
  make_repo "$SRC"

  echo "tracked" > "$SRC/tracked.txt"
  echo "secret" > "$SRC/secret.env"
  echo "secret.env" > "$SRC/.gitignore"
  git -C "$SRC" add tracked.txt .gitignore
  git -C "$SRC" commit -m "initial" --quiet

  snapshot_copy_worktree "$SRC" "$DST"

  if [[ ! -f "$DST/secret.env" ]]; then
    pass "worktree: gitignored file excluded from destination"
  else
    fail "worktree: gitignored file should not appear in destination"
  fi
}

test_worktree_includes_untracked_non_ignored_files() {
  local SRC="$FIXTURE_DIR/wt_untracked_src"
  local DST="$FIXTURE_DIR/wt_untracked_dst"
  make_committed_repo "$SRC"

  echo "new file" > "$SRC/untracked.txt"  # untracked, not gitignored

  snapshot_copy_worktree "$SRC" "$DST"

  if [[ -f "$DST/untracked.txt" ]]; then
    pass "worktree: untracked non-ignored file included in destination"
  else
    fail "worktree: untracked non-ignored file missing from destination"
  fi
}

test_worktree_copies_edited_version_of_tracked_file() {
  local SRC="$FIXTURE_DIR/wt_edited_src"
  local DST="$FIXTURE_DIR/wt_edited_dst"
  make_committed_repo "$SRC"

  echo "unstaged edit" >> "$SRC/tracked.txt"

  snapshot_copy_worktree "$SRC" "$DST"

  if grep -q "unstaged edit" "$DST/tracked.txt"; then
    pass "worktree: edited version of tracked file copied (not committed version)"
  else
    fail "worktree: edited content missing from destination"
  fi
}

test_worktree_handles_unstaged_deletion() {
  local SRC="$FIXTURE_DIR/wt_deletion_src"
  local DST="$FIXTURE_DIR/wt_deletion_dst"
  make_repo "$SRC"

  echo "to be deleted" > "$SRC/deleted.txt"
  echo "stays" > "$SRC/stays.txt"
  git -C "$SRC" add .
  git -C "$SRC" commit -m "initial" --quiet
  rm "$SRC/deleted.txt"  # unstaged deletion

  if snapshot_copy_worktree "$SRC" "$DST" 2>/dev/null; then
    if [[ ! -f "$DST/deleted.txt" ]]; then
      pass "worktree: unstaged deletion handled  --  file absent from destination"
    else
      fail "worktree: deleted file should not appear in destination"
    fi
  else
    fail "worktree: snapshot_copy_worktree should not abort on unstaged deletion"
  fi
}

test_worktree_handles_unstaged_move() {
  local SRC="$FIXTURE_DIR/wt_move_src"
  local DST="$FIXTURE_DIR/wt_move_dst"
  make_committed_repo "$SRC"

  echo "movable" > "$SRC/old-name.txt"
  git -C "$SRC" add old-name.txt
  git -C "$SRC" commit -m "add file" --quiet
  mv "$SRC/old-name.txt" "$SRC/new-name.txt"  # unstaged move

  if snapshot_copy_worktree "$SRC" "$DST" 2>/dev/null; then
    if [[ ! -f "$DST/old-name.txt" && -f "$DST/new-name.txt" ]]; then
      pass "worktree: unstaged move handled  --  old absent, new present in destination"
    else
      fail "worktree: after move, expected old absent and new present"
    fi
  else
    fail "worktree: snapshot_copy_worktree should not abort on unstaged move"
  fi
}

test_worktree_excludes_git_directory() {
  local SRC="$FIXTURE_DIR/wt_no_git_src"
  local DST="$FIXTURE_DIR/wt_no_git_dst"
  make_committed_repo "$SRC"

  snapshot_copy_worktree "$SRC" "$DST"

  if [[ ! -d "$DST/.git" ]]; then
    pass "worktree: .git directory excluded from destination"
  else
    fail "worktree: .git directory should not be copied to destination"
  fi
}

test_worktree_creates_destination_if_absent() {
  local SRC="$FIXTURE_DIR/wt_mkdir_src"
  local DST="$FIXTURE_DIR/wt_mkdir_dst_new/nested"
  make_committed_repo "$SRC"

  snapshot_copy_worktree "$SRC" "$DST"

  if [[ -d "$DST" ]]; then
    pass "worktree: destination directory created when absent"
  else
    fail "worktree: destination directory should be created automatically"
  fi
}

test_worktree_preserves_directory_structure() {
  local SRC="$FIXTURE_DIR/wt_struct_src"
  local DST="$FIXTURE_DIR/wt_struct_dst"
  make_repo "$SRC"

  mkdir -p "$SRC/src/deeply/nested"
  echo "deep" > "$SRC/src/deeply/nested/file.txt"
  git -C "$SRC" add .
  git -C "$SRC" commit -m "nested" --quiet

  snapshot_copy_worktree "$SRC" "$DST"

  if [[ -f "$DST/src/deeply/nested/file.txt" ]]; then
    pass "worktree: nested directory structure preserved in destination"
  else
    fail "worktree: nested directory structure not preserved"
  fi
}

test_worktree_honors_negation_patterns_local() {
  local SRC="$FIXTURE_DIR/wt_negation_local_src"
  local DST="$FIXTURE_DIR/wt_negation_local_dst"
  make_repo "$SRC"

  printf 'tracked\n' > "$SRC/tracked.txt"
  printf '*.log\n!keep.log\n' > "$SRC/.gitignore"
  echo "dropped" > "$SRC/drop.log"
  echo "kept" > "$SRC/keep.log"
  git -C "$SRC" add tracked.txt .gitignore
  git -C "$SRC" commit -m "initial" --quiet

  snapshot_copy_worktree "$SRC" "$DST"

  if [[ -f "$DST/keep.log" && ! -f "$DST/drop.log" ]]; then
    pass "worktree: local negation pattern honored (keep.log kept, drop.log dropped)"
  else
    fail "worktree: local negation pattern mishandled (keep.log: $([[ -f $DST/keep.log ]] && echo present || echo absent), drop.log: $([[ -f $DST/drop.log ]] && echo present || echo absent))"
  fi
}

# Negation patterns in GLOBAL excludes and .git/info/exclude: the previous
# rsync exclude-list approach silently ignored them and leaked the excluded
# content (the R1 leak, ADR sandbox_delivery_model.md mount-path entry).
test_worktree_honors_negation_patterns_global_excludes() {
  local SRC="$FIXTURE_DIR/wt_negation_global_src"
  local DST="$FIXTURE_DIR/wt_negation_global_dst"
  make_repo "$SRC"

  echo "tracked" > "$SRC/tracked.txt"
  echo "globally dropped" > "$SRC/globalonly.txt"
  echo "repo-excluded" > "$SRC/repoonly.txt"
  printf 'globalonly.txt\n!rescued.txt\n' > "$SRC/.gitignore.global"
  printf 'repoonly.txt\n' > "$SRC/.git/info/exclude"
  echo "rescued" > "$SRC/rescued.txt"
  git -C "$SRC" add tracked.txt
  git -C "$SRC" commit -m "initial" --quiet

  # Point core.excludesFile at the fixture global ignore
  local old_global
  old_global=$(git -C "$SRC" config --global core.excludesFile || true)
  git -C "$SRC" config --global core.excludesFile "$SRC/.gitignore.global"

  snapshot_copy_worktree "$SRC" "$DST"
  local rc=$?

  # Restore the operator's global excludesFile before asserting
  if [[ -n "$old_global" ]]; then
    git -C "$SRC" config --global core.excludesFile "$old_global"
  else
    git -C "$SRC" config --global --unset core.excludesFile
  fi

  if [[ $rc -ne 0 ]]; then
    fail "worktree: global-exclude negation test errored (copy failed)"
  elif [[ ! -f "$DST/globalonly.txt" && ! -f "$DST/repoonly.txt" && -f "$DST/rescued.txt" ]]; then
    pass "worktree: global/info excludes and negations honored (leak fixed)"
  else
    fail "worktree: global/info exclude leak (globalonly: $([[ -f $DST/globalonly.txt ]] && echo LEAKED || echo ok), repoonly: $([[ -f $DST/repoonly.txt ]] && echo LEAKED || echo ok), rescued: $([[ -f $DST/rescued.txt ]] && echo present || echo absent))"
  fi
}


test_worktree_submodule_detected() {
  local SRC="$FIXTURE_DIR/wt_submod_src"
  local DST="$FIXTURE_DIR/wt_submod_dst"
  make_committed_repo "$SRC"

  local FAKE_SHA="abcdef1234567890abcdef1234567890abcdef12"
  git -C "$SRC" update-index --add --cacheinfo "160000,$FAKE_SHA,sub"

  if snapshot_copy_worktree "$SRC" "$DST" 2>/dev/null; then
    fail "worktree: should abort when submodule is present"
  else
    pass "worktree: correctly aborts on submodule detection"
  fi
}


# -------------------------
# Run all tests
# -------------------------

# snapshot_copy_worktree (primary)
run_test              test_worktree_copies_tracked_files
run_test         test_worktree_excludes_gitignored_files
run_test    test_worktree_includes_untracked_non_ignored_files
run_test  test_worktree_copies_edited_version_of_tracked_file
run_test         test_worktree_handles_unstaged_deletion
run_test             test_worktree_handles_unstaged_move
run_test           test_worktree_excludes_git_directory
run_test     test_worktree_creates_destination_if_absent
run_test     test_worktree_preserves_directory_structure
run_test               test_worktree_submodule_detected
run_test       test_worktree_honors_negation_patterns_local
run_test test_worktree_honors_negation_patterns_global_excludes




test_done
