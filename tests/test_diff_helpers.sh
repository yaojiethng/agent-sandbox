#!/usr/bin/env bash
# Tests for libs/diff.sh: write_uncommitted_diff, write_all_changes_diff, write_changed_files
#
# Sources libs/diff.sh directly for function access.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$SCRIPT_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/diff.sh"

# ===================================================================
# write_uncommitted_diff
# ===================================================================

test_uncommitted_writes_diff() {
  local DIR="$FIXTURE_DIR/uw_diff"
  local OUT="$FIXTURE_DIR/uw_diff_out"
  mkdir -p "$OUT"
  make_sandbox_fixture "$DIR"

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
  make_sandbox_fixture "$DIR"

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
  make_sandbox_fixture "$DIR"

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
  make_sandbox_fixture "$DIR"

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
  SHA=$(make_sandbox_fixture "$DIR")

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
  make_sandbox_fixture "$DIR"

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
  make_sandbox_fixture "$DIR"

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
  SHA=$(make_sandbox_fixture "$DIR")

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
  SHA=$(make_sandbox_fixture "$DIR")

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
  SHA=$(make_sandbox_fixture "$DIR")

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
  SHA=$(make_sandbox_fixture "$DIR")

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
  SHA=$(make_sandbox_fixture "$DIR")

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
  SHA=$(make_sandbox_fixture "$DIR")

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

# ===================================================================
# strip_index_lines
# ===================================================================

test_strip_index_removes_text_index() {
  local INPUT=$'diff --git a/file.txt b/file.txt\nindex abc123..def456 100644\n--- a/file.txt\n+++ b/file.txt\n@@ -1 +1 @@\n-old\n+new'
  local OUTPUT
  OUTPUT=$(echo "$INPUT" | strip_index_lines)

  if echo "$OUTPUT" | grep -q '^index '; then
    fail "strip_index_lines should remove index lines from text diffs"
  else
    pass "strip_index_lines removes index lines from text diffs"
  fi

  # Verify diff content is preserved
  if echo "$OUTPUT" | grep -q '^@@ '; then
    pass "strip_index_lines preserves diff hunk headers"
  else
    fail "strip_index_lines should preserve diff hunk headers"
  fi
}

test_strip_index_preserves_binary_index() {
  local INPUT='diff --git a/data.bin b/data.bin
index 0eee44a..802480f 100644
GIT binary patch
literal 1500
acmezW@9+OnG

literal 0
HcmV?d00001'
  local OUTPUT
  OUTPUT=$(echo "$INPUT" | strip_index_lines)

  if echo "$OUTPUT" | grep -q '^index '; then
    pass "strip_index_lines preserves index line for binary diffs"
  else
    fail "strip_index_lines should preserve index line for binary diffs"
  fi

  if echo "$OUTPUT" | grep -q 'GIT binary patch'; then
    pass "strip_index_lines preserves GIT binary patch header"
  else
    fail "strip_index_lines should preserve GIT binary patch header"
  fi
}

test_strip_index_handles_mixed_diff() {
  # Create a diff with both text and binary changes
  local INPUT='diff --git a/file.txt b/file.txt
index abc123..def456 100644
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-old
+new
diff --git a/data.bin b/data.bin
index 0eee44a..802480f 100644
GIT binary patch
literal 1500
acmezW@9+OnG'
  local OUTPUT
  OUTPUT=$(echo "$INPUT" | strip_index_lines)

  # Count remaining index lines — should be exactly 1 (binary only)
  local COUNT
  COUNT=$(echo "$OUTPUT" | grep -c '^index ' || echo 0)

  if [[ "$COUNT" -eq 1 ]]; then
    pass "strip_index_lines: exactly 1 index line remains in mixed diff (binary only)"
  else
    fail "strip_index_lines: expected 1 index line in mixed diff, got $COUNT"
  fi

  if echo "$OUTPUT" | grep -q '^--- a/file.txt'; then
    pass "strip_index_lines preserves text diff headers"
  else
    fail "strip_index_lines should preserve text diff headers"
  fi
}

test_strip_index_passthrough_no_index() {
  local INPUT='diff --git a/file.txt b/file.txt
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-old
+new'
  local OUTPUT
  OUTPUT=$(echo "$INPUT" | strip_index_lines)

  if echo "$OUTPUT" | grep -q '^--- a/file.txt'; then
    pass "strip_index_lines passes through diff without index lines"
  else
    fail "strip_index_lines should pass through diff without index lines"
  fi
}

# =============================================================================
# Run
# =============================================================================
run_test test_uncommitted_writes_diff
run_test test_uncommitted_empty_on_clean
run_test test_uncommitted_includes_untracked
run_test test_uncommitted_strips_index_lines
run_test test_uncommitted_missing_args
run_test test_all_changes_writes_diff
run_test test_all_changes_includes_both_committed_and_uncommitted
run_test test_all_changes_empty_on_clean
run_test test_all_changes_missing_args
run_test test_all_changes_missing_session_state
run_test test_changed_files_copies_modified
run_test test_changed_files_copies_untracked
run_test test_changed_files_skips_deleted
run_test test_changed_files_writes_manifest
run_test test_changed_files_preserves_directory_structure
run_test test_changed_files_deduplicates
run_test test_changed_files_missing_args
run_test test_strip_index_removes_text_index
run_test test_strip_index_preserves_binary_index
run_test test_strip_index_handles_mixed_diff
run_test test_strip_index_passthrough_no_index

test_done
