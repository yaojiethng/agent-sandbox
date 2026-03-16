#!/usr/bin/env bash
# tests/test_snapshot_host.sh
# Host-side snapshot pipeline tests: snapshot_enumerate_files, snapshot_copy_files, snapshot_validate.
# All fixtures created under /tmp — no git repos created inside the harness repo.

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
# Run all tests
# -------------------------
run_test "gitignore exclusion"          test_gitignore_exclusion
run_test "untracked files included"     test_untracked_included
run_test "untracked-only repo"          test_untracked_only_repo
run_test "dirty working tree"           test_dirty_working_tree
run_test "symlink handling"             test_symlink_handling
run_test "copy preserves structure"     test_copy_preserves_structure
run_test "validate passes"              test_validate_passes
run_test "validate missing dir"         test_validate_missing_dir
run_test "validate empty dir"           test_validate_empty_dir
run_test "submodule detection"          test_submodule_detection

# -------------------------
# Summary
# -------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
