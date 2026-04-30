#!/usr/bin/env bash
# tests/test_package_branch.sh
# Tests for libs/package_branch.sh
#
# Covers:
#   package_branch        — dispatcher produces unified output format
#   package_commits       — produces numbered diffs, index lines stripped,
#                           missing args, no commits

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/package_branch.sh"
source "$SCRIPT_DIR/libs/git_fixtures.sh"

source "$SCRIPT_DIR/libs/test_common.sh"

FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# -------------------------
# Helpers
# -------------------------
write_session_state() {
  local DIR="$1"
  local INIT_SHA="$2"
  mkdir -p "$DIR/.git"
  echo "init_sha=$INIT_SHA" > "$DIR/.git/SESSION_STATE"
}

# -------------------------
# package_branch dispatcher — basic functionality
# -------------------------
test_package_branch_produces_numbered_diffs() {
  local DIR="$FIXTURE_DIR/pb_basic"
  local DIFFS="$FIXTURE_DIR/pb_basic_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  commit_change "$DIR" "first commit"
  commit_change "$DIR" "second commit"

  package_branch "$DIR" "$DIFFS"

  local COUNT
  COUNT=$(ls -1 "$DIFFS/patches/"*.diff 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "package_branch dispatcher produces one diff per commit in patches/ (got $COUNT)"
  else
    fail "package_branch dispatcher should produce 2 diffs in patches/, got $COUNT"
  fi
}

test_package_branch_numbering_format() {
  local DIR="$FIXTURE_DIR/pb_num"
  local DIFFS="$FIXTURE_DIR/pb_num_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  commit_change "$DIR" "first"
  commit_change "$DIR" "second"
  commit_change "$DIR" "third"

  package_branch "$DIR" "$DIFFS"

  if ls "$DIFFS/patches/0001-"*.diff >/dev/null 2>&1 && \
     ls "$DIFFS/patches/0002-"*.diff >/dev/null 2>&1 && \
     ls "$DIFFS/patches/0003-"*.diff >/dev/null 2>&1; then
    pass "package_branch dispatcher uses correct 0001-, 0002-, 0003- numbering in patches/"
  else
    fail "package_branch dispatcher should use 0001-, 0002-, 0003- prefix in patches/"
  fi
}

test_package_branch_index_lines_stripped() {
  local DIR="$FIXTURE_DIR/pb_noindex"
  local DIFFS="$FIXTURE_DIR/pb_noindex_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  commit_change "$DIR" "change"

  package_branch "$DIR" "$DIFFS"

  local DIFF_FILE
  DIFF_FILE=$(ls "$DIFFS/patches/"*.diff | head -n1)
  if ! grep -q '^index ' "$DIFF_FILE"; then
    pass "package_branch dispatcher strips index lines from diffs"
  else
    fail "package_branch dispatcher should strip index lines from diffs"
  fi
}

test_package_branch_overwrites_existing() {
  local DIR="$FIXTURE_DIR/pb_overwrite"
  local DIFFS="$FIXTURE_DIR/pb_overwrite_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  # First run
  commit_change "$DIR" "first"
  package_branch "$DIR" "$DIFFS"
  local COUNT1
  COUNT1=$(ls -1 "$DIFFS/patches/"*.diff 2>/dev/null | wc -l)

  # Second run with more commits
  commit_change "$DIR" "second"
  commit_change "$DIR" "third"
  package_branch "$DIR" "$DIFFS"
  local COUNT2
  COUNT2=$(ls -1 "$DIFFS/patches/"*.diff 2>/dev/null | wc -l)

  if [[ "$COUNT2" -eq 3 ]]; then
    pass "package_branch dispatcher overwrites existing diffs (got $COUNT2 after second run)"
  else
    fail "package_branch dispatcher should overwrite, got $COUNT2 diffs"
  fi
}

# -------------------------
# package_branch dispatcher — edge cases
# -------------------------
test_package_branch_no_commits() {
  local DIR="$FIXTURE_DIR/pb_nocommit"
  local DIFFS="$FIXTURE_DIR/pb_nocommit_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  # No commits since baseline
  package_branch "$DIR" "$DIFFS" 2>/dev/null

  local COUNT
  COUNT=$(ls -1 "$DIFFS/patches/"*.diff 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 0 ]]; then
    pass "package_branch dispatcher produces no diffs when no commits since INIT_SHA"
  else
    fail "package_branch dispatcher should produce 0 diffs, got $COUNT"
  fi
}

test_package_branch_missing_args() {
  if package_branch 2>/dev/null; then
    fail "package_branch dispatcher should fail with missing args"
  else
    pass "package_branch dispatcher fails with missing args"
  fi
}

test_package_branch_missing_sandbox_dir() {
  local DIFFS="$FIXTURE_DIR/pb_missing_sandbox"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"

  if package_branch "/nonexistent" "$DIFFS" 2>/dev/null; then
    fail "package_branch dispatcher should fail with nonexistent SANDBOX_DIR"
  else
    pass "package_branch dispatcher fails with nonexistent SANDBOX_DIR"
  fi
}

test_package_branch_missing_init_sha_in_session_state() {
  local DIR="$FIXTURE_DIR/pb_missing_init"
  local DIFFS="$FIXTURE_DIR/pb_missing_init_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"

  # No SESSION_STATE written — init_sha not available
  if package_branch "$DIR" "$DIFFS" 2>/dev/null; then
    fail "package_branch dispatcher should fail when init_sha missing from SESSION_STATE"
  else
    pass "package_branch dispatcher fails when init_sha missing from SESSION_STATE"
  fi
}

# -------------------------
# package_branch dispatcher — diff content verification
# -------------------------
test_package_branch_diff_is_applicable() {
  local DIR="$FIXTURE_DIR/pb_apply"
  local TARGET="$FIXTURE_DIR/pb_apply_target"
  local DIFFS="$FIXTURE_DIR/pb_apply_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  make_committed_repo "$TARGET"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  commit_change "$DIR" "agent change"
  package_branch "$DIR" "$DIFFS"

  local DIFF_FILE
  DIFF_FILE=$(ls "$DIFFS/patches/"*.diff | head -n1)

  # Apply diff to target (same baseline)
  if git -C "$TARGET" apply "$DIFF_FILE" 2>/dev/null; then
    pass "diff produced by package_branch dispatcher applies cleanly via git apply"
  else
    fail "diff produced by package_branch dispatcher does not apply via git apply"
  fi
}

test_package_branch_diff_contains_expected_content() {
  local DIR="$FIXTURE_DIR/pb_content"
  local DIFFS="$FIXTURE_DIR/pb_content_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  echo "unique content here" > "$DIR/unique.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "add unique file" --quiet

  package_branch "$DIR" "$DIFFS"

  local DIFF_FILE
  DIFF_FILE=$(ls "$DIFFS/patches/"*.diff | head -n1)

  if grep -q "unique content here" "$DIFF_FILE"; then
    pass "diff contains expected file content"
  else
    fail "diff should contain expected file content"
  fi
}

# -------------------------
# package_branch dispatcher — unified output format
# -------------------------
test_package_branch_writes_uncommitted_diff() {
  local DIR="$FIXTURE_DIR/pb_uncommitted"
  local DIFFS="$FIXTURE_DIR/pb_uncommitted_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  # Uncommitted change
  echo "uncommitted work" > "$DIR/uncommitted.txt"

  package_branch "$DIR" "$DIFFS"

  if [[ -f "$DIFFS/uncommitted.diff" ]]; then
    pass "package_branch dispatcher writes uncommitted.diff"
  else
    fail "package_branch dispatcher should write uncommitted.diff"
  fi
}

test_package_branch_writes_all_changes_diff() {
  local DIR="$FIXTURE_DIR/pb_all_changes"
  local DIFFS="$FIXTURE_DIR/pb_all_changes_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  commit_change "$DIR" "committed work"

  package_branch "$DIR" "$DIFFS"

  if [[ -f "$DIFFS/all-changes.diff" && -s "$DIFFS/all-changes.diff" ]]; then
    pass "package_branch dispatcher writes all-changes.diff"
  else
    fail "package_branch dispatcher should write all-changes.diff"
  fi
}

# -------------------------
# package_branch dispatcher — changed-files
# -------------------------
test_package_branch_changed_files_manifest() {
  local DIR="$FIXTURE_DIR/pb_manifest"
  local DIFFS="$FIXTURE_DIR/pb_manifest_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  echo "file a" > "$DIR/file-a.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "add files" --quiet

  package_branch "$DIR" "$DIFFS"

  if [[ -f "$DIFFS/changed-files/MANIFEST.txt" ]]; then
    local COUNT
    COUNT=$(grep -c '^.' "$DIFFS/changed-files/MANIFEST.txt" 2>/dev/null || echo 0)
    if [[ "$COUNT" -ge 1 ]]; then
      pass "changed-files/MANIFEST.txt produced with correct entries"
    else
      fail "MANIFEST.txt empty"
    fi
  else
    fail "changed-files/MANIFEST.txt not produced"
  fi
}

test_package_branch_changed_files_copies() {
  local DIR="$FIXTURE_DIR/pb_copies"
  local DIFFS="$FIXTURE_DIR/pb_copies_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  echo "deep content" > "$DIR/deep.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "add deep" --quiet

  package_branch "$DIR" "$DIFFS"

  if [[ -f "$DIFFS/changed-files/deep.txt" ]] && \
     [[ "$(cat "$DIFFS/changed-files/deep.txt")" == "deep content" ]]; then
    pass "changed-files/ contains working tree copy with correct content"
  else
    fail "changed-files/ missing expected file copy"
  fi
}

test_package_branch_changed_files_uncommitted() {
  local DIR="$FIXTURE_DIR/pb_cf_uncommitted"
  local DIFFS="$FIXTURE_DIR/pb_cf_uncommitted_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  echo "uncommitted data" > "$DIR/new-uncommitted.txt"

  package_branch "$DIR" "$DIFFS"

  if [[ -f "$DIFFS/changed-files/new-uncommitted.txt" ]]; then
    pass "changed-files/ includes uncommitted files"
  else
    fail "changed-files/ missing uncommitted file"
  fi
}

test_package_branch_changed_files_dedup() {
  local DIR="$FIXTURE_DIR/pb_dedup"
  local DIFFS="$FIXTURE_DIR/pb_dedup_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  echo "overlap" > "$DIR/overlap.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "commit overlap" --quiet

  # Also modify uncommitted — same file appears in both committed and uncommitted
  echo "overlap modified" > "$DIR/overlap.txt"

  package_branch "$DIR" "$DIFFS"

  local COUNT
  COUNT=$(grep -c 'overlap.txt' "$DIFFS/changed-files/MANIFEST.txt" 2>/dev/null || echo 0)
  if [[ "$COUNT" -eq 1 ]]; then
    pass "changed-files/MANIFEST.txt deduplicates files appearing in multiple diff sources"
  else
    fail "expected 1 entry for overlap.txt, got $COUNT"
  fi
}

# -------------------------
# package_commits — single commit edge case
# -------------------------
test_package_commits_single_commit() {
  local DIR="$FIXTURE_DIR/pc_single"
  local PATCHES="$FIXTURE_DIR/pc_single_patches"
  rm -rf "$PATCHES" && mkdir -p "$PATCHES"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  commit_change "$DIR" "only commit"

  package_commits "$DIR" "$INIT_SHA" "$PATCHES"

  local COUNT
  COUNT=$(ls -1 "$PATCHES/"*.diff 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 1 ]]; then
    pass "package_commits handles single commit correctly"
  else
    fail "package_commits should produce 1 diff, got $COUNT"
  fi
}

# -------------------------
# Run all tests
# -------------------------
run_test test_package_branch_produces_numbered_diffs
run_test test_package_branch_numbering_format
run_test test_package_branch_index_lines_stripped
run_test test_package_branch_overwrites_existing
run_test test_package_branch_no_commits
run_test test_package_branch_missing_args
run_test test_package_branch_missing_sandbox_dir
run_test test_package_branch_missing_init_sha_in_session_state
run_test test_package_branch_diff_is_applicable
run_test test_package_branch_diff_contains_expected_content
run_test test_package_branch_writes_uncommitted_diff
run_test test_package_branch_writes_all_changes_diff
run_test test_package_branch_changed_files_manifest
run_test test_package_branch_changed_files_copies
run_test test_package_branch_changed_files_uncommitted
run_test test_package_branch_changed_files_dedup
run_test test_package_commits_single_commit

test_done
