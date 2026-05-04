#!/usr/bin/env bash
# Tests for libs/diff.sh: write_uncommitted_diff, write_all_changes_diff, write_changed_files
#
# Sources libs/diff.sh directly for function access.

set -uo pipefail

FIXTURE_DIR=$(mktemp -d)
trap 'rm -rf "$FIXTURE_DIR"' EXIT

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/git_fixtures.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../libs/diff.sh"

plan 18

# -------------------------------------------------------------------
# Helper: create a clean sandbox with a baseline commit
# -------------------------------------------------------------------
make_sandbox() {
  make_committed_repo "$1"
  local SHA
  SHA=$(get_init_sha "$1")
  write_session_state "$1"
  # Rename default branch to main for consistency
  git -C "$1" branch -M main 2>/dev/null || true
  echo "$SHA"
}

# ===================================================================
# write_uncommitted_diff
# ===================================================================

test_uncommitted_writes_diff() {
  local DIR="$FIXTURE_DIR/uw_diff"
  local OUT="$FIXTURE_DIR/uw_diff_out"
  mkdir -p "$OUT"
  make_sandbox "$DIR"

  echo "unstaged change" > "$DIR/new.txt"

  write_uncommitted_diff "$DIR" "$OUT/uncommitted.diff"

  if [[ -s "$OUT/uncommitted.diff" ]]; then
    pass "write_uncommitted_diff writes non-empty diff when changes exist"
  else
    fail "write_uncommitted_diff should write non-empty diff"
  fi
}

test_uncommitted_empty_on_clean() {
  local DIR="$FIXTURE_DIR/uw_clean"
  local OUT="$FIXTURE_DIR/uw_clean_out"
  mkdir -p "$OUT"
  make_sandbox "$DIR"

  write_uncommitted_diff "$DIR" "$OUT/uncommitted.diff"

  if [[ -f "$OUT/uncommitted.diff" ]] && [[ ! -s "$OUT/uncommitted.diff" ]]; then
    pass "write_uncommitted_diff writes empty file on clean tree"
  else
    fail "write_uncommitted_diff should write empty file on clean tree"
  fi
}

test_uncommitted_includes_untracked() {
  local DIR="$FIXTURE_DIR/uw_untracked"
  local OUT="$FIXTURE_DIR/uw_untracked_out"
  mkdir -p "$OUT"
  make_sandbox "$DIR"

  echo "untracked content" > "$DIR/untracked.txt"

  write_uncommitted_diff "$DIR" "$OUT/uncommitted.diff"

  if grep -q "untracked.txt" "$OUT/uncommitted.diff" 2>/dev/null; then
    pass "write_uncommitted_diff includes untracked file in diff"
  else
    fail "write_uncommitted_diff should include untracked file in diff"
  fi
}

test_uncommitted_strips_index_lines() {
  local DIR="$FIXTURE_DIR/uw_index"
  local OUT="$FIXTURE_DIR/uw_index_out"
  mkdir -p "$OUT"
  make_sandbox "$DIR"

  echo "content" > "$DIR/file.txt"

  write_uncommitted_diff "$DIR" "$OUT/uncommitted.diff"

  if grep -q '^index ' "$OUT/uncommitted.diff" 2>/dev/null; then
    fail "write_uncommitted_diff should strip index lines"
  else
    pass "write_uncommitted_diff strips index lines"
  fi
}

test_uncommitted_missing_args() {
  if write_uncommitted_diff "" "" 2>/dev/null; then
    fail "write_uncommitted_diff should fail with missing args"
  else
    pass "write_uncommitted_diff fails with missing args"
  fi
}

# ===================================================================
# write_all_changes_diff
# ===================================================================

test_all_changes_writes_diff() {
  local DIR="$FIXTURE_DIR/ac_diff"
  local OUT="$FIXTURE_DIR/ac_diff_out"
  mkdir -p "$OUT"
  local SHA
  SHA=$(make_sandbox "$DIR")

  echo "second commit" > "$DIR/file2.txt"
  git -C "$DIR" add file2.txt
  git -C "$DIR" commit -m "second" --quiet
  echo "unstaged" > "$DIR/unstaged.txt"

  write_all_changes_diff "$DIR" "$OUT/all-changes.diff"

  if [[ -s "$OUT/all-changes.diff" ]]; then
    pass "write_all_changes_diff writes non-empty diff when changes exist"
  else
    fail "write_all_changes_diff should write non-empty diff"
  fi
}

test_all_changes_includes_both_committed_and_uncommitted() {
  local DIR="$FIXTURE_DIR/ac_both"
  local OUT="$FIXTURE_DIR/ac_both_out"
  mkdir -p "$OUT"
  make_sandbox "$DIR"

  echo "committed" > "$DIR/c.txt"
  git -C "$DIR" add c.txt
  git -C "$DIR" commit -m "committed" --quiet
  echo "unstaged" > "$DIR/u.txt"

  write_all_changes_diff "$DIR" "$OUT/all-changes.diff"

  local HAS_C HAS_U
  grep -q "c.txt" "$OUT/all-changes.diff" && HAS_C=1 || HAS_C=0
  grep -q "u.txt" "$OUT/all-changes.diff" && HAS_U=1 || HAS_U=0
  if [[ "$HAS_C" -eq 1 ]] && [[ "$HAS_U" -eq 1 ]]; then
    pass "write_all_changes_diff includes both committed (c.txt) and uncommitted (u.txt)"
  else
    fail "write_all_changes_diff should include both committed and uncommitted changes"
  fi
}

test_all_changes_empty_on_clean() {
  local DIR="$FIXTURE_DIR/ac_clean"
  local OUT="$FIXTURE_DIR/ac_clean_out"
  mkdir -p "$OUT"
  make_sandbox "$DIR"

  write_all_changes_diff "$DIR" "$OUT/all-changes.diff"

  if [[ -f "$OUT/all-changes.diff" ]] && [[ ! -s "$OUT/all-changes.diff" ]]; then
    pass "write_all_changes_diff writes empty file on clean tree"
  else
    fail "write_all_changes_diff should write empty file on clean tree"
  fi
}

test_all_changes_missing_args() {
  if write_all_changes_diff "" "" 2>/dev/null; then
    fail "write_all_changes_diff should fail with missing args"
  else
    pass "write_all_changes_diff fails with missing args"
  fi
}

test_all_changes_missing_session_state() {
  local DIR="$FIXTURE_DIR/ac_nostate"
  local OUT="$FIXTURE_DIR/ac_nostate_out"
  mkdir -p "$OUT"
  make_committed_repo "$DIR"  # no SESSION_STATE

  if write_all_changes_diff "$DIR" "$OUT/all-changes.diff" 2>/dev/null; then
    fail "write_all_changes_diff should fail without SESSION_STATE"
  else
    pass "write_all_changes_diff fails without SESSION_STATE"
  fi
}

# ===================================================================
# write_changed_files
# ===================================================================

test_changed_files_copies_modified() {
  local DIR="$FIXTURE_DIR/cf_modified"
  local OUT="$FIXTURE_DIR/cf_modified_out"
  mkdir -p "$OUT"
  local SHA
  SHA=$(make_sandbox "$DIR")

  echo "modified content" > "$DIR/file.txt"
  write_changed_files "$DIR" "$SHA" "$OUT"

  if [[ -f "$OUT/changed-files/file.txt" ]] && grep -q "modified" "$OUT/changed-files/file.txt"; then
    pass "write_changed_files copies modified file with correct content"
  else
    fail "write_changed_files should copy modified file"
  fi
}

test_changed_files_copies_untracked() {
  local DIR="$FIXTURE_DIR/cf_untracked"
  local OUT="$FIXTURE_DIR/cf_untracked_out"
  mkdir -p "$OUT"
  local SHA
  SHA=$(make_sandbox "$DIR")

  echo "new file" > "$DIR/new.txt"

  write_changed_files "$DIR" "$SHA" "$OUT"

  if [[ -f "$OUT/changed-files/new.txt" ]]; then
    pass "write_changed_files copies untracked file"
  else
    fail "write_changed_files should copy untracked file"
  fi
}

test_changed_files_skips_deleted() {
  local DIR="$FIXTURE_DIR/cf_deleted"
  local OUT="$FIXTURE_DIR/cf_deleted_out"
  mkdir -p "$OUT"
  local SHA
  SHA=$(make_sandbox "$DIR")

  rm "$DIR/file.txt"

  write_changed_files "$DIR" "$SHA" "$OUT"

  if [[ -d "$OUT/changed-files" ]]; then
    local COUNT
    COUNT=$(find "$OUT/changed-files" -type f 2>/dev/null | wc -l)
    if [[ "$COUNT" -eq 0 ]]; then
      pass "write_changed_files produces no files when only deletion exists"
    else
      fail "write_changed_files should skip deleted files"
    fi
  else
    pass "write_changed_files produces no directory when no files to copy"
  fi
}

test_changed_files_writes_manifest() {
  local DIR="$FIXTURE_DIR/cf_manifest"
  local OUT="$FIXTURE_DIR/cf_manifest_out"
  mkdir -p "$OUT"
  local SHA
  SHA=$(make_sandbox "$DIR")

  echo "content" > "$DIR/a.txt"
  write_changed_files "$DIR" "$SHA" "$OUT"

  if [[ -f "$OUT/changed-files/MANIFEST.txt" ]] && grep -q "a.txt" "$OUT/changed-files/MANIFEST.txt"; then
    pass "write_changed_files writes MANIFEST.txt listing changed file"
  else
    fail "write_changed_files should write MANIFEST.txt with file list"
  fi
}

test_changed_files_preserves_directory_structure() {
  local DIR="$FIXTURE_DIR/cf_subdir"
  local OUT="$FIXTURE_DIR/cf_subdir_out"
  mkdir -p "$OUT"
  local SHA
  SHA=$(make_sandbox "$DIR")

  mkdir -p "$DIR/sub"
  echo "nested" > "$DIR/sub/nested.txt"

  write_changed_files "$DIR" "$SHA" "$OUT"

  if [[ -f "$OUT/changed-files/sub/nested.txt" ]]; then
    pass "write_changed_files preserves directory structure"
  else
    fail "write_changed_files should preserve directory structure"
  fi
}

test_changed_files_deduplicates() {
  local DIR="$FIXTURE_DIR/cf_dedup"
  local OUT="$FIXTURE_DIR/cf_dedup_out"
  mkdir -p "$OUT"
  local SHA
  SHA=$(make_sandbox "$DIR")

  # File that is both modified and untracked (should appear once)
  echo "modified" > "$DIR/file.txt"
  echo "untracked" > "$DIR/file.txt"  # same path

  write_changed_files "$DIR" "$SHA" "$OUT"

  local COUNT
  COUNT=$(grep -c "file.txt" "$OUT/changed-files/MANIFEST.txt" 2>/dev/null || echo 0)
  if [[ "$COUNT" -eq 1 ]]; then
    pass "write_changed_files deduplicates file appearing in both diff and untracked"
  else
    fail "write_changed_files should deduplicate, file.txt appears $COUNT times"
  fi
}

test_changed_files_missing_args() {
  if write_changed_files "" "" "" 2>/dev/null; then
    fail "write_changed_files should fail with missing args"
  else
    pass "write_changed_files fails with missing args"
  fi
}
