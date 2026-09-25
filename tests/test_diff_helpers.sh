#!/usr/bin/env bash
# Tests for libs/diff.sh: write_uncommitted_diff, write_all_changes_diff, write_changed_files
#
# Sources libs/diff.sh directly for function access.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/diff.sh"

# ===================================================================
# write_uncommitted_diff
# ===================================================================

# Given: a tracked file modified relative to HEAD
# When:  write_uncommitted_diff runs
# Then:  a non-empty diff file
# Asserts: the basic uncommitted write.
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

# Given: a clean tree at HEAD
# When:  write_uncommitted_diff runs
# Then:  an empty file, not a missing one
# Asserts: the empty-diff contract callers test with diff_is_empty.
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

# Given: an untracked file
# When:  write_uncommitted_diff runs
# Then:  the untracked file appears in the diff
# Asserts: the temporary intent-to-add staging.
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

# Given: a text change
# When:  write_uncommitted_diff runs
# Then:  no `index` line remains
# Asserts: the cosmetic strip that lets the patch apply across differing histories.
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

# Given: no arguments
# When:  write_uncommitted_diff runs
# Then:  rc 1 with a diagnostic
# Asserts: the argument guard.
test_uncommitted_missing_args() {
  if write_uncommitted_diff "" "" 2>/dev/null; then
    fail "write_uncommitted_diff should fail with missing args"
  else
    pass "write_uncommitted_diff fails with missing args"
  fi
}

# Given: a removed line carrying trailing whitespace
# When:  write_uncommitted_diff runs
# Then:  the patch carries those bytes
# Asserts: the strip touches index lines only, not content.
test_uncommitted_preserves_content_whitespace() {
  # Regression: the export pipeline must not content-mutate the patch. The
  # removed `sed -e '/^[+]/ s/[[:space:]]*$//' -e '/^[-]/ s/[[:space:]]*$//'`
  # step stripped trailing whitespace (and even CR on CRLF lines) from +/- line
  # content, breaking git apply matching and silently corrupting content. The
  # verbatim exporter keeps stack exact source bytes; the diff must round-trip.
  local DIR="$FIXTURE_DIR/uw_ws"
  local OUT="$FIXTURE_DIR/uw_ws_out"
  mkdir -p "$OUT"
  make_sandbox_fixture "$DIR"

  # A modified file whose diff has a trailing-space removed line.
  printf 'line1\n  \nline3\n' > "$DIR/file.txt"
  git -C "$DIR" add file.txt
  git -C "$DIR" commit -m "baseline" --quiet
  printf 'line1\nline3\n' > "$DIR/file.txt"   # removes the 2-space blank line

  write_uncommitted_diff "$DIR" "$OUT/uncommitted.diff"

  # The removed line (-) must retain its 2 trailing spaces in the patch.
  if grep -q -- '-  $' "$OUT/uncommitted.diff"; then
    pass "write_uncommitted_diff preserves a removed line's trailing whitespace"
  else
    fail "write_uncommitted_diff stripped a removed line's trailing whitespace"
  fi
}

# Given: whitespace-funny and CRLF content, uncommitted
# When:  write_uncommitted_diff runs and the patch is applied to a clean baseline
# Then:  the target reproduces the source bytes exactly
# Asserts: the verbatim round-trip the export path depends on.
test_uncommitted_roundtrip_verbatim() {
  # The verbatim patch must apply to a clean baseline and reproduce the source
  # bytes exactly (including trailing-space blank/added lines and a CRLF line).
  local SRC="$FIXTURE_DIR/uw_rt_src"
  local OUT="$FIXTURE_DIR/uw_rt_out"
  local TGT="$FIXTURE_DIR/uw_rt_tgt"
  mkdir -p "$OUT" "$TGT"
  make_sandbox_fixture "$SRC" > /dev/null

  # Commit the pre-state, then make the whitespace/CRLF change UNCOMMITTED so
  # write_uncommitted_diff produces a diff against HEAD.
  local PRE='line1\n  \nline3\r\n'
  local POST='line1\n  \nADDED  \nline3\r\n'
  printf '%b' "$PRE" > "$SRC/file.txt"
  git -C "$SRC" add file.txt
  git -C "$SRC" commit -m "pre-state" --quiet
  printf '%b' "$POST" > "$SRC/file.txt"

  write_uncommitted_diff "$SRC" "$OUT/uncommitted.diff"

  # Target repo seeded with the pre-state (before the whitespace/crlf change).
  git -C "$TGT" init --quiet
  git -C "$TGT" config user.email "t@t"
  git -C "$TGT" config user.name "t"
  printf '%b' "$PRE" > "$TGT/file.txt"
  git -C "$TGT" add file.txt
  git -C "$TGT" commit -m "baseline" --quiet

  if ! git -C "$TGT" apply "$OUT/uncommitted.diff" 2>/dev/null; then
    fail "verbatim uncommitted.diff should apply cleanly"
    return
  fi

  local GOT; GOT=$(cat "$TGT/file.txt")
  if [[ "$GOT" == "$(printf '%b' "$POST")" ]]; then
    pass "verbatim uncommitted.diff round-trips whitespace+CRLF content exactly"
  else
    fail "verbatim uncommitted.diff corrupted content (got: $(printf %q "$GOT"))"
  fi
}

# Given: eight funny-whitespace and CRLF classes, one per round
# When:  the verbatim pipeline runs end to end for each
# Then:  each round-trips byte-exactly
# Asserts: the matrix behind the verbatim claim.
test_roundtrip_whitespace_matrix() {
  # The verbatim exporter must round-trip every "funny-line" class byte-exactly
  # through the real pipeline: trailing-space add/remove, space-only lines,
  # blank lines at EOF, CRLF add/remove, and no-newline-at-EOF. The removed
  # content-strip sed corrupted several of these (esp. CRLF, where POSIX
  # [[:space:]] ate the trailing \r). These are the classes git itself handles
  # correctly given a verbatim diff.
  local MATRIX=(
    'trailspace_add|a\nb\nc\n|a\nb\nc\nD  \n'
    'trailspace_blank|a\n  \nc\n|a\n  \nD\nc\n'
    'removed_trailws|a\nb  \nc\n|a\nb\nc\n'
    'space_only_line|a\nb\n  \nc\n|a\nb\nc\n'
    'blank_at_eof|a\nb\nc\n|a\nb\nc\n\n\n'
    'crlf_add|l1\r\nl2\r\n|l1\r\nl2\r\nl3\r\n'
    'crlf_remove|l1\r\nl2  \r\nl3\r\n|l1\r\nl3\r\n'
    'no_eof_newline|aaa\nbbb|aaa\nbbb\nccc'
  )

  local ALL_OK=true
  local entry pre post name d out tgt got
  for entry in "${MATRIX[@]}"; do
    name="${entry%%|*}"; local rest="${entry#*|}"; pre="${rest%%|*}"; post="${rest#*|}"
    d="$FIXTURE_DIR/mx_${name}_src"; out="$FIXTURE_DIR/mx_${name}_out"; tgt="$FIXTURE_DIR/mx_${name}_tgt"
    mkdir -p "$out" "$tgt"
    make_sandbox_fixture "$d" > /dev/null

    printf '%b' "$pre" > "$d/file.txt"
    git -C "$d" add file.txt
    git -C "$d" commit -m "pre" --quiet
    printf '%b' "$post" > "$d/file.txt"
    write_uncommitted_diff "$d" "$out/uncommitted.diff"

    git -C "$tgt" init --quiet
    git -C "$tgt" config user.email "t@t"
    git -C "$tgt" config user.name "t"
    printf '%b' "$pre" > "$tgt/file.txt"
    git -C "$tgt" add file.txt
    git -C "$tgt" commit -m "baseline" --quiet

    if ! git -C "$tgt" apply "$out/uncommitted.diff" 2>/dev/null; then
      ALL_OK=false; echo "  (matrix '$name' did not apply)" >&2; continue
    fi
    got=$(cat "$tgt/file.txt")
    if [[ "$got" != "$(printf '%b' "$post")" ]]; then
      ALL_OK=false; echo "  (matrix '$name' byte mismatch)" >&2
    fi
  done

  if [[ "$ALL_OK" == true ]]; then
    pass "verbatim pipeline round-trips all 8 funny-whitespace/CRLF classes byte-exactly"
  else
    fail "verbatim pipeline failed one or more funny-whitespace/CRLF round-trips (see stderr)"
  fi
}

# ===================================================================
# write_all_changes_diff
# ===================================================================

# Given: committed and uncommitted change since the baseline
# When:  write_all_changes_diff runs with an explicit SHA
# Then:  a non-empty diff file
# Asserts: the explicit-baseline write.
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

# Given: a committed file and an uncommitted file since the baseline
# When:  write_all_changes_diff runs
# Then:  both appear
# Asserts: `git diff <baseline>` rather than range syntax, so both classes are included.
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

# Given: a clean tree at the baseline
# When:  write_all_changes_diff runs
# Then:  an empty file
# Asserts: the empty-diff contract for the all-changes form.
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

# Given: no arguments
# When:  write_all_changes_diff runs
# Then:  rc 1 with a diagnostic
# Asserts: the argument guard.
test_all_changes_missing_args() {
  if write_all_changes_diff "" "" 2>/dev/null; then
    fail "write_all_changes_diff should fail with missing args"
  else
    pass "write_all_changes_diff fails with missing args"
  fi
}

# Given: no SESSION_STATE record and no explicit baseline
# When:  write_all_changes_diff runs
# Then:  rc 1 rather than an empty write
# Asserts: a missing baseline is an error, not a silent empty diff.
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

# Given: a modified tracked file since the baseline
# When:  write_changed_files runs
# Then:  the copy carries the same content, at the same relative path
# Asserts: the working-tree copy.
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

# Given: an untracked file
# When:  write_changed_files runs
# Then:  it is copied
# Asserts: untracked files are part of the bundle.
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

# Given: a change that is only a deletion
# When:  write_changed_files runs
# Then:  no file is copied and no directory is left behind
# Asserts: deleted paths have no working-tree copy; the manifest is not inspected (finding 59).
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

# Given: one changed file
# When:  write_changed_files runs
# Then:  MANIFEST.txt lists it
# Asserts: the manifest exists and names the file.
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

# Given: a change in a subdirectory
# When:  write_changed_files runs
# Then:  the copy keeps its directory structure
# Asserts: relative-path preservation.
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

# Given: a path that is both modified and untracked-listed
# When:  write_changed_files runs
# Then:  the manifest names it once
# Asserts: `sort -u` deduplication of the two sources.
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
  assert_eq_num "$COUNT" "1" "write_changed_files deduplicates file appearing in both diff and untracked"
}

# Given: no arguments
# When:  write_changed_files runs
# Then:  rc 1 with a diagnostic
# Asserts: the argument guard.
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

# Given: a text diff with index lines
# When:  strip_index_lines runs
# Then:  the index lines are gone and the hunk headers remain
# Asserts: the text half of the filter.
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

# Given: a binary diff with an index line and a GIT binary patch header
# When:  strip_index_lines runs
# Then:  the index line and the header survive
# Asserts: the binary half of the filter, without which git apply rejects the patch.
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

# Given: a diff holding text and binary changes
# When:  strip_index_lines runs
# Then:  exactly one index line remains, the binary one, and the text headers remain
# Asserts: the per-hunk decision in one pass.
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

  # Count remaining index lines  --  should be exactly 1 (binary only)
  local COUNT
  COUNT=$(echo "$OUTPUT" | grep -c '^index ' || echo 0)

  assert_eq_num "$COUNT" "1" "strip_index_lines: exactly 1 index line remains in mixed diff (binary only)"

  if echo "$OUTPUT" | grep -q '^--- a/file.txt'; then
    pass "strip_index_lines preserves text diff headers"
  else
    fail "strip_index_lines should preserve text diff headers"
  fi
}

# Given: a diff with no index lines
# When:  strip_index_lines runs
# Then:  the input passes through unchanged
# Asserts: the filter is a no-op on already-stripped patches.
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
run_test test_uncommitted_preserves_content_whitespace
run_test test_uncommitted_roundtrip_verbatim
run_test test_roundtrip_whitespace_matrix
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

