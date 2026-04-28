#!/usr/bin/env bash
# tests/test_snapshot_host.sh
# Host-side snapshot pipeline tests.
#
# Covers:
#   snapshot_copy_worktree   — primary rsync-based copy
#   snapshot_archive_head    — produces baseline.tar from HEAD
#   snapshot_validate        — structural integrity check (including baseline.tar)
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

FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
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

make_committed_repo() {
  local DIR="$1"
  make_repo "$DIR"
  echo "tracked content" > "$DIR/tracked.txt"
  git -C "$DIR" add tracked.txt
  git -C "$DIR" commit -m "initial" --quiet
}

# -------------------------
# snapshot_copy_worktree tests
# -------------------------

test_worktree_copies_tracked_files() {
  local SRC="$FIXTURE_DIR/wt_tracked_src"
  local DST="$FIXTURE_DIR/wt_tracked_dst"
  make_committed_repo "$SRC"

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
  make_committed_repo "$SRC"

  echo "movable" > "$SRC/old-name.txt"
  git -C "$SRC" add old-name.txt
  git -C "$SRC" commit -m "add file" --quiet
  mv "$SRC/old-name.txt" "$SRC/new-name.txt"  # unstaged move

  if snapshot_copy_worktree "$SRC" "$DST" 2>/dev/null; then
    if [[ ! -f "$DST/old-name.txt" && -f "$DST/new-name.txt" ]]; then
      pass "worktree: unstaged move handled — old absent, new present in destination"
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
# snapshot_archive_head tests
# -------------------------

test_archive_head_produces_tar() {
  local SRC="$FIXTURE_DIR/arch_src"
  local DST="$FIXTURE_DIR/arch_dst"
  make_committed_repo "$SRC"

  snapshot_archive_head "$SRC" "$DST"

  if [[ -f "$DST/baseline.tar" ]]; then
    pass "archive_head: baseline.tar produced"
  else
    fail "archive_head: baseline.tar not found"
  fi
}

test_archive_head_tar_contains_committed_files() {
  local SRC="$FIXTURE_DIR/arch_content_src"
  local DST="$FIXTURE_DIR/arch_content_dst"
  make_committed_repo "$SRC"

  snapshot_archive_head "$SRC" "$DST"

  local CONTENTS
  CONTENTS=$(tar -tf "$DST/baseline.tar")
  if echo "$CONTENTS" | grep -q "tracked.txt"; then
    pass "archive_head: committed file present in tar"
  else
    fail "archive_head: committed file missing from tar"
  fi
}

test_archive_head_tar_excludes_untracked_files() {
  local SRC="$FIXTURE_DIR/arch_untracked_src"
  local DST="$FIXTURE_DIR/arch_untracked_dst"
  make_committed_repo "$SRC"

  echo "not committed" > "$SRC/untracked.txt"

  snapshot_archive_head "$SRC" "$DST"

  local CONTENTS
  CONTENTS=$(tar -tf "$DST/baseline.tar")
  if ! echo "$CONTENTS" | grep -q "untracked.txt"; then
    pass "archive_head: untracked file excluded from tar"
  else
    fail "archive_head: untracked file should not appear in tar"
  fi
}

test_archive_head_tar_excludes_unstaged_edits() {
  local SRC="$FIXTURE_DIR/arch_edited_src"
  local DST="$FIXTURE_DIR/arch_edited_dst"
  make_committed_repo "$SRC"

  echo "unstaged edit" >> "$SRC/tracked.txt"

  snapshot_archive_head "$SRC" "$DST"

  local UNPACK="$FIXTURE_DIR/arch_edited_unpack"
  mkdir -p "$UNPACK"
  tar -x -C "$UNPACK" < "$DST/baseline.tar"

  if ! grep -q "unstaged edit" "$UNPACK/tracked.txt"; then
    pass "archive_head: unstaged edits excluded from tar (committed version present)"
  else
    fail "archive_head: tar contains unstaged edits — should contain HEAD version only"
  fi
}

test_archive_head_fails_with_no_commits() {
  local SRC="$FIXTURE_DIR/arch_nocommit_src"
  local DST="$FIXTURE_DIR/arch_nocommit_dst"
  make_repo "$SRC"  # no commit

  if snapshot_archive_head "$SRC" "$DST" 2>/dev/null; then
    fail "archive_head: should fail when repo has no commits"
  else
    pass "archive_head: correctly fails when repo has no commits"
  fi
}

test_archive_head_creates_dest_if_absent() {
  local SRC="$FIXTURE_DIR/arch_mkdir_src"
  local DST="$FIXTURE_DIR/arch_mkdir_dst_new/nested"
  make_committed_repo "$SRC"

  snapshot_archive_head "$SRC" "$DST"

  if [[ -f "$DST/baseline.tar" ]]; then
    pass "archive_head: destination directory created when absent"
  else
    fail "archive_head: destination directory should be created automatically"
  fi
}

# -------------------------
# snapshot_validate tests
# -------------------------

test_validate_passes() {
  local DIR="$FIXTURE_DIR/validate_pass"
  mkdir -p "$DIR"
  echo "content" > "$DIR/file.txt"
  touch "$DIR/baseline.tar"

  if snapshot_validate "$DIR" 2>/dev/null; then
    pass "validate passes on non-empty snapshot with baseline.tar"
  else
    fail "validate failed on valid snapshot"
  fi
}

test_validate_missing_dir() {
  if snapshot_validate "$FIXTURE_DIR/nonexistent" 2>/dev/null; then
    fail "validate should fail on missing directory"
  else
    pass "validate correctly fails on missing directory"
  fi
}

test_validate_empty_dir() {
  local DIR="$FIXTURE_DIR/empty_dir"
  mkdir -p "$DIR"

  if snapshot_validate "$DIR" 2>/dev/null; then
    fail "validate should fail on empty directory"
  else
    pass "validate correctly fails on empty directory"
  fi
}

test_validate_missing_baseline_tar() {
  local DIR="$FIXTURE_DIR/validate_no_tar"
  mkdir -p "$DIR"
  echo "content" > "$DIR/file.txt"
  # baseline.tar intentionally absent

  if snapshot_validate "$DIR" 2>/dev/null; then
    fail "validate should fail when baseline.tar is absent"
  else
    pass "validate correctly fails when baseline.tar is absent"
  fi
}

# -------------------------
# Run all tests
# -------------------------

# snapshot_copy_worktree (primary)
run_test "worktree: copies tracked files"              test_worktree_copies_tracked_files
run_test "worktree: excludes gitignored files"         test_worktree_excludes_gitignored_files
run_test "worktree: includes untracked non-ignored"    test_worktree_includes_untracked_non_ignored_files
run_test "worktree: copies edited version of tracked"  test_worktree_copies_edited_version_of_tracked_file
run_test "worktree: handles unstaged deletion"         test_worktree_handles_unstaged_deletion
run_test "worktree: handles unstaged move"             test_worktree_handles_unstaged_move
run_test "worktree: excludes .git directory"           test_worktree_excludes_git_directory
run_test "worktree: creates destination if absent"     test_worktree_creates_destination_if_absent
run_test "worktree: preserves directory structure"     test_worktree_preserves_directory_structure
run_test "worktree: submodule detection"               test_worktree_submodule_detected

# snapshot_archive_head
run_test "archive_head: produces baseline.tar"             test_archive_head_produces_tar
run_test "archive_head: tar contains committed files"      test_archive_head_tar_contains_committed_files
run_test "archive_head: tar excludes untracked files"      test_archive_head_tar_excludes_untracked_files
run_test "archive_head: tar excludes unstaged edits"       test_archive_head_tar_excludes_unstaged_edits
run_test "archive_head: fails with no commits"             test_archive_head_fails_with_no_commits
run_test "archive_head: creates destination if absent"     test_archive_head_creates_dest_if_absent

# snapshot_validate
run_test "validate passes"                  test_validate_passes
run_test "validate missing dir"             test_validate_missing_dir
run_test "validate empty dir"               test_validate_empty_dir
run_test "validate missing baseline.tar"    test_validate_missing_baseline_tar

# -------------------------
# Summary
# -------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]