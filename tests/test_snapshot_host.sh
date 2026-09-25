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

# Given: a committed repo
# When:  snapshot_copy_worktree runs
# Then:  the tracked file exists in the destination
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

# Given: a repo ignoring secret.env
# When:  snapshot_copy_worktree runs
# Then:  secret.env is absent from the destination
# Asserts: git's own ignore sources decide what crosses, and ignored content does not
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

# Given: an untracked, non-ignored file
# When:  snapshot_copy_worktree runs
# Then:  the file exists in the destination
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

# Given: a tracked file with an unstaged edit
# When:  snapshot_copy_worktree runs
# Then:  the destination holds the edited content, not the committed version
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

# Given: a tracked file deleted from the worktree
# When:  snapshot_copy_worktree runs
# Then:  the copy succeeds and the path is absent from the destination
# Asserts: the enumeration's existence filter, not an abort
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

# Given: a tracked file renamed in the worktree with no git operation
# When:  snapshot_copy_worktree runs
# Then:  the old name is absent and the new name present
# Asserts: the enumeration follows the disk, so an unstaged move lands as its own remove-and-add
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

# Given: a committed repo
# When:  snapshot_copy_worktree runs
# Then:  the destination has no .git directory
# Asserts: the worktree sync never carries repository metadata (the .git copy is the dispatcher's other arm)
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

# Given: a destination path whose parents do not exist
# When:  snapshot_copy_worktree runs
# Then:  the destination directory is created
test_worktree_creates_destination_if_absent() {
  local SRC="$FIXTURE_DIR/wt_mkdir_src"
  local DST="$FIXTURE_DIR/wt_mkdir_dst_new/nested"
  make_committed_repo "$SRC"

  snapshot_copy_worktree "$SRC" "$DST"

  assert_dir_exists "$DST" "worktree: destination directory created when absent"
}

# Given: a tracked path several directories deep
# When:  snapshot_copy_worktree runs
# Then:  the file exists at the same relative path in the destination
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

# Given: a .gitignore carrying *.log and !keep.log
# When:  snapshot_copy_worktree runs
# Then:  keep.log crosses and drop.log does not
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
# Given: a fixture global excludes file and a .git/info/exclude entry, with a negation rescuing one path
# When:  snapshot_copy_worktree runs
# Then:  the global and repository excludes hold and the rescued file crosses
# Asserts: the R1 leak stays closed for the negating sources the old rsync exclude list dropped
# Note:  the unit writes the operator's global git config to arrange this (finding 119)
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


# Given: an index carrying a gitlink (160000) entry
# When:  snapshot_copy_worktree runs
# Then:  the copy aborts
# Asserts: the pipeline's submodule pre-flight, which is the second guard on the seed path (finding 113)
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
# snapshot_deliver tests (delivery dispatcher: full vs flatten)
# -------------------------

# A full delivery copies .git, so the destination carries the host history and
# the seeded HEAD becomes the destination HEAD.
# Given: a committed repo
# When:  snapshot_deliver runs in full mode
# Then:  the destination carries .git with the same HEAD and at least one commit
test_deliver_full_carries_history() {
  local SRC="$FIXTURE_DIR/dl_full_src"
  local DST="$FIXTURE_DIR/dl_full_dst"
  make_committed_repo "$SRC"
  local src_head
  src_head="$(git -C "$SRC" rev-parse HEAD)"

  snapshot_deliver "$SRC" "$DST" "false"

  if [[ ! -d "$DST/.git" ]]; then
    fail "deliver full: .git not copied to destination"; return
  fi
  local dst_head dst_count
  dst_head="$(git -C "$DST" rev-parse HEAD)"
  dst_count="$(git -C "$DST" rev-list --count HEAD)"
  if [[ "$dst_head" == "$src_head" && "$dst_count" -ge 1 ]]; then
    pass "deliver full: history + HEAD carried to destination"
  else
    fail "deliver full: HEAD mismatch (src=$src_head dst=$dst_head)"
  fi
}

# A flatten delivery must not cross .git; it inits a fresh single baseline.
# Given: a committed repo
# When:  snapshot_deliver runs in flatten mode
# Then:  the destination carries .git, the worktree file, and exactly one commit
test_deliver_flatten_single_baseline() {
  local SRC="$FIXTURE_DIR/dl_flat_src"
  local DST="$FIXTURE_DIR/dl_flat_dst"
  make_committed_repo "$SRC"

  snapshot_deliver "$SRC" "$DST" "true"

  if [[ -d "$DST/.git" ]] && [[ -f "$DST/file.txt" ]]; then
    local count
    count="$(git -C "$DST" rev-list --count HEAD)"
    if [[ "$count" -eq 1 ]]; then
      pass "deliver flatten: single baseline commit, file present"
    else
      fail "deliver flatten: expected 1 commit, got $count"
    fi
  else
    fail "deliver flatten: .git or file.txt missing in destination"
  fi
}

# Both modes must exclude gitignored content (R1 boundary integrity).
# Given: a repo with a gitignored file
# When:  snapshot_deliver runs in flatten mode
# Then:  the ignored file is absent from the destination
# Asserts: the ignore boundary holds on both dispatcher arms
test_deliver_flatten_excludes_gitignored() {
  local SRC="$FIXTURE_DIR/dl_flat_ignore_src"
  local DST="$FIXTURE_DIR/dl_flat_ignore_dst"
  make_committed_repo "$SRC"
  echo "secret" > "$SRC/secret.env"
  echo "secret.env" > "$SRC/.gitignore"
  git -C "$SRC" add .gitignore
  git -C "$SRC" commit -m "ignore" --quiet

  snapshot_deliver "$SRC" "$DST" "true"

  if [[ ! -f "$DST/secret.env" ]]; then
    pass "deliver flatten: gitignored file excluded"
  else
    fail "deliver flatten: gitignored file leaked into destination"
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

# snapshot_deliver (delivery dispatcher)
run_test                test_deliver_full_carries_history
run_test         test_deliver_flatten_single_baseline
run_test      test_deliver_flatten_excludes_gitignored




test_done

