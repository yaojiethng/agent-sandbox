#!/usr/bin/env bash
# tests/test_snapshot_host.sh
# Host-side snapshot pipeline tests.
#
# Covers:
#   snapshot_copy_worktree   — primary rsync-based copy (Change 4 / M2.3)
#   snapshot_validate        — structural integrity check
#   snapshot_enumerate_files — deprecated index-driven enumeration (retained for reference)
#   snapshot_copy_files      — deprecated index-driven copy (retained for reference)
#
# All fixtures created under a temp dir — no repos created inside the harness repo.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/libs/snapshot.sh"

PASS=0
FAIL=0

# -------------------------
# Helpers
# -------------------------
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_test() {
  local NAME="$1"
  shift
  echo "[ $NAME ]"
  "$@" || true
}

# Create a temp dir and register cleanup on exit.
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# -------------------------
# Fixture builder
# -------------------------
make_repo() {
  local DIR="$1"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet
  git -C "$DIR" config user.email "test@sandbox"
  git -C "$DIR" config user.name "test"
}

# -------------------------
# Test: gitignored files are excluded from enumeration
# -------------------------
test_gitignore_exclusion() {
  local DIR="$FIXTURE_DIR/gitignore_test"
  make_repo "$DIR"

  echo "tracked content" > "$DIR/tracked.txt"
  echo "secret content"  > "$DIR/secret.env"
  echo "secret.env"      > "$DIR/.gitignore"

  git -C "$DIR" add tracked.txt .gitignore
  git -C "$DIR" commit -m "initial" --quiet

  local FILES
  FILES=$(snapshot_enumerate_files "$DIR" | tr '\0' '\n')

  if echo "$FILES" | grep -q "secret.env"; then
    fail "gitignored file appeared in enumeration"
  else
    pass "gitignored file excluded from enumeration"
  fi

  if echo "$FILES" | grep -q "tracked.txt"; then
    pass "tracked file included in enumeration"
  else
    fail "tracked file missing from enumeration"
  fi
}

# -------------------------
# Test: untracked non-ignored files are included
# -------------------------
test_untracked_included() {
  local DIR="$FIXTURE_DIR/untracked_test"
  make_repo "$DIR"

  echo "tracked"   > "$DIR/tracked.txt"
  echo "untracked" > "$DIR/untracked.txt"
  echo "ignored"   > "$DIR/ignored.txt"
  echo "ignored.txt" > "$DIR/.gitignore"

  git -C "$DIR" add tracked.txt .gitignore
  git -C "$DIR" commit -m "initial" --quiet

  local FILES
  FILES=$(snapshot_enumerate_files "$DIR" | tr '\0' '\n')

  if echo "$FILES" | grep -q "untracked.txt"; then
    pass "untracked non-ignored file included in enumeration"
  else
    fail "untracked non-ignored file missing from enumeration"
  fi

  if echo "$FILES" | grep -q "ignored.txt"; then
    fail "ignored file appeared in enumeration"
  else
    pass "ignored file excluded from enumeration"
  fi
}

# -------------------------
# Test: untracked-only repo (no commits)
# -------------------------
test_untracked_only_repo() {
  local DIR="$FIXTURE_DIR/no_commits_test"
  make_repo "$DIR"

  echo "content" > "$DIR/file.txt"

  local FILES
  FILES=$(snapshot_enumerate_files "$DIR" | tr '\0' '\n')

  if echo "$FILES" | grep -q "file.txt"; then
    pass "untracked-only repo: file included in enumeration"
  else
    fail "untracked-only repo: file missing from enumeration"
  fi
}

# -------------------------
# Test: dirty working tree — unstaged modifications included
# -------------------------
test_dirty_working_tree() {
  local DIR="$FIXTURE_DIR/dirty_test"
  make_repo "$DIR"

  echo "original" > "$DIR/file.txt"
  git -C "$DIR" add file.txt
  git -C "$DIR" commit -m "initial" --quiet

  echo "modified" > "$DIR/file.txt"

  local FILES
  FILES=$(snapshot_enumerate_files "$DIR" | tr '\0' '\n')

  if echo "$FILES" | grep -q "file.txt"; then
    pass "dirty working tree: modified file included in enumeration"
  else
    fail "dirty working tree: modified file missing from enumeration"
  fi
}

# -------------------------
# Test: symlinks are copied into snapshot
# -------------------------
test_symlink_handling() {
  local DIR="$FIXTURE_DIR/symlink_test"
  local DEST="$FIXTURE_DIR/symlink_snapshot"
  make_repo "$DIR"

  echo "target content" > "$DIR/target.txt"
  ln -s target.txt "$DIR/link.txt"
  git -C "$DIR" add target.txt link.txt
  git -C "$DIR" commit -m "initial" --quiet

  (cd "$DIR" && snapshot_enumerate_files "$DIR") \
    | (cd "$DIR" && snapshot_copy_files "$DIR" "$DEST")

  if [[ -e "$DEST/link.txt" ]]; then
    pass "symlink present in snapshot"
  else
    fail "symlink missing from snapshot"
  fi

  if [[ -e "$DEST/target.txt" ]]; then
    pass "symlink target present in snapshot"
  else
    fail "symlink target missing from snapshot"
  fi
}

# -------------------------
# Test: snapshot_copy_files preserves directory structure
# -------------------------
test_copy_preserves_structure() {
  local DIR="$FIXTURE_DIR/structure_test"
  local DEST="$FIXTURE_DIR/structure_snapshot"
  make_repo "$DIR"

  mkdir -p "$DIR/src/nested"
  echo "content" > "$DIR/src/nested/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "initial" --quiet

  (cd "$DIR" && snapshot_enumerate_files "$DIR") \
    | (cd "$DIR" && snapshot_copy_files "$DIR" "$DEST")

  if [[ -f "$DEST/src/nested/file.txt" ]]; then
    pass "directory structure preserved in snapshot"
  else
    fail "directory structure not preserved in snapshot"
  fi
}

# -------------------------
# Test: snapshot_validate passes on valid snapshot
# -------------------------
test_validate_passes() {
  local DIR="$FIXTURE_DIR/validate_pass"
  mkdir -p "$DIR"
  echo "content" > "$DIR/file.txt"

  if snapshot_validate "$DIR" 2>/dev/null; then
    pass "validate passes on non-empty snapshot"
  else
    fail "validate failed on non-empty snapshot"
  fi
}

# -------------------------
# Test: snapshot_validate fails on missing directory
# -------------------------
test_validate_missing_dir() {
  if snapshot_validate "$FIXTURE_DIR/nonexistent" 2>/dev/null; then
    fail "validate should fail on missing directory"
  else
    pass "validate correctly fails on missing directory"
  fi
}

# -------------------------
# Test: snapshot_validate fails on empty directory
# -------------------------
test_validate_empty_dir() {
  local DIR="$FIXTURE_DIR/empty_dir"
  mkdir -p "$DIR"

  if snapshot_validate "$DIR" 2>/dev/null; then
    fail "validate should fail on empty directory"
  else
    pass "validate correctly fails on empty directory"
  fi
}

# -------------------------
# Test: submodule presence causes abort
# -------------------------
test_submodule_detection() {
  local DIR="$FIXTURE_DIR/submodule_test"
  make_repo "$DIR"

  echo "content" > "$DIR/file.txt"
  git -C "$DIR" add file.txt
  git -C "$DIR" commit -m "initial" --quiet

  # Plant a gitlink entry (mode 160000) directly in the index.
  # This is what a submodule looks like to git ls-files --stage.
  # Using a synthetic SHA — the detection only checks the mode, not object validity.
  local FAKE_SHA="abcdef1234567890abcdef1234567890abcdef12"
  git -C "$DIR" update-index --add --cacheinfo "160000,$FAKE_SHA,sub"

  if snapshot_enumerate_files "$DIR" 2>/dev/null; then
    fail "enumerate should abort when submodule is present"
  else
    pass "enumerate correctly aborts on submodule detection"
  fi
}

# -------------------------
# snapshot_copy_worktree tests
# -------------------------

# Helper: make a committed repo with an optional .gitignore
make_worktree_repo() {
  local DIR="$1"
  make_repo "$DIR"
  echo "tracked content" > "$DIR/tracked.txt"
  git -C "$DIR" add tracked.txt
  git -C "$DIR" commit -m "initial" --quiet
}

test_worktree_copies_tracked_files() {
  local SRC="$FIXTURE_DIR/wt_tracked_src"
  local DST="$FIXTURE_DIR/wt_tracked_dst"
  make_worktree_repo "$SRC"

  snapshot_copy_worktree "$SRC" "$DST"

  if [[ -f "$DST/tracked.txt" ]]; then
    pass "worktree: tracked file copied to destination"
  else
    fail "worktree: tracked file missing from destination"
  fi
}

test_worktree_excludes_gitignored_files() {
  local SRC="$FIXTURE_DIR/wt_ignore_src"
  local DST="$FIXTURE_DIR/wt_ignore_dst"
  make_worktree_repo "$SRC"

  echo "secret" > "$SRC/secret.env"
  echo "secret.env" > "$SRC/.gitignore"
  git -C "$SRC" add .gitignore
  git -C "$SRC" commit -m "add gitignore" --quiet

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
  make_worktree_repo "$SRC"

  echo "new file" > "$SRC/untracked.txt"  # untracked, not ignored

  snapshot_copy_worktree "$SRC" "$DST"

  if [[ -f "$DST/untracked.txt" ]]; then
    pass "worktree: untracked non-ignored file included in destination"
  else
    fail "worktree: untracked non-ignored file missing from destination"
  fi
}

test_worktree_handles_unstaged_deletion() {
  local SRC="$FIXTURE_DIR/wt_deletion_src"
  local DST="$FIXTURE_DIR/wt_deletion_dst"
  make_worktree_repo "$SRC"

  # Add and commit a second file, then delete it without staging the deletion
  echo "to be deleted" > "$SRC/deleted.txt"
  git -C "$SRC" add deleted.txt
  git -C "$SRC" commit -m "add file" --quiet
  rm "$SRC/deleted.txt"  # unstaged deletion — index still has the file

  # Should succeed (not abort), and deleted file should NOT be in destination
  if snapshot_copy_worktree "$SRC" "$DST" 2>/dev/null; then
    if [[ ! -f "$DST/deleted.txt" ]]; then
      pass "worktree: unstaged deletion handled — file absent from destination"
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
  make_worktree_repo "$SRC"

  echo "movable" > "$SRC/old-name.txt"
  git -C "$SRC" add old-name.txt
  git -C "$SRC" commit -m "add file" --quiet
  mv "$SRC/old-name.txt" "$SRC/new-name.txt"  # unstaged move

  if snapshot_copy_worktree "$SRC" "$DST" 2>/dev/null; then
    if [[ ! -f "$DST/old-name.txt" && -f "$DST/new-name.txt" ]]; then
      pass "worktree: unstaged move handled — old absent, new present in destination"
    else
      fail "worktree: after move, old-name.txt=${}, new-name.txt present=${$(test -f "$DST/new-name.txt" && echo y || echo n)}"
    fi
  else
    fail "worktree: snapshot_copy_worktree should not abort on unstaged move"
  fi
}

test_worktree_excludes_git_directory() {
  local SRC="$FIXTURE_DIR/wt_no_git_src"
  local DST="$FIXTURE_DIR/wt_no_git_dst"
  make_worktree_repo "$SRC"

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
  make_worktree_repo "$SRC"

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

test_worktree_submodule_detected() {
  local SRC="$FIXTURE_DIR/wt_submod_src"
  local DST="$FIXTURE_DIR/wt_submod_dst"
  make_repo "$SRC"

  echo "content" > "$SRC/file.txt"
  git -C "$SRC" add file.txt
  git -C "$SRC" commit -m "initial" --quiet

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
run_test "worktree: copies tracked files"              test_worktree_copies_tracked_files
run_test "worktree: excludes gitignored files"         test_worktree_excludes_gitignored_files
run_test "worktree: includes untracked non-ignored"    test_worktree_includes_untracked_non_ignored_files
run_test "worktree: handles unstaged deletion"         test_worktree_handles_unstaged_deletion
run_test "worktree: handles unstaged move"             test_worktree_handles_unstaged_move
run_test "worktree: excludes .git directory"           test_worktree_excludes_git_directory
run_test "worktree: creates destination if absent"     test_worktree_creates_destination_if_absent
run_test "worktree: preserves directory structure"     test_worktree_preserves_directory_structure
run_test "worktree: submodule detection"               test_worktree_submodule_detected

# snapshot_validate
run_test "validate passes"              test_validate_passes
run_test "validate missing dir"         test_validate_missing_dir
run_test "validate empty dir"           test_validate_empty_dir

# snapshot_enumerate_files / snapshot_copy_files (deprecated — retained for reference)
run_test "gitignore exclusion"          test_gitignore_exclusion
run_test "untracked files included"     test_untracked_included
run_test "untracked-only repo"          test_untracked_only_repo
run_test "dirty working tree"           test_dirty_working_tree
run_test "symlink handling"             test_symlink_handling
run_test "copy preserves structure"     test_copy_preserves_structure
run_test "submodule detection"          test_submodule_detection

# -------------------------
# Summary
# -------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
