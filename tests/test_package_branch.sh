#!/usr/bin/env bash
# tests/test_package_branch.sh
# Tests for libs/package_branch.sh
#
# Covers:
#   package_branch        — produces numbered diffs, index lines stripped,
#                           missing args, no commits
#
# Note: package_branch writes directly to OUTPUT_DIR/*.diff — it does not
# create a subdirectory based on SESSION_SUMMARY. SESSION_SUMMARY is for
# logging only.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/package_branch.sh"

PASS=0
FAIL=0
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_test() {
  echo "[ $1 ]"
  $1 || true
}

# -------------------------
# Helpers
# -------------------------
make_sandbox() {
  local DIR="$1"
  rm -rf "$DIR"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet
  git -C "$DIR" config user.email "test@test.com"
  git -C "$DIR" config user.name "Test"
  echo "baseline" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "baseline" --quiet
}

get_init_sha() {
  git -C "$1" rev-list --max-parents=0 HEAD
}

commit_change() {
  local DIR="$1"
  local MSG="${2:-agent commit}"
  echo "$MSG" > "$DIR/change-${RANDOM}.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "$MSG" --quiet
}

# -------------------------
# package_branch — basic functionality
# -------------------------
test_package_branch_produces_numbered_diffs() {
  local DIR="$FIXTURE_DIR/pb_basic"
  local DIFFS="$FIXTURE_DIR/pb_basic_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  commit_change "$DIR" "first commit"
  commit_change "$DIR" "second commit"

  package_branch "$DIR" "$INIT_SHA" "$DIFFS" "main"

  local COUNT
  COUNT=$(ls -1 "$DIFFS/"*.diff 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "package_branch produces one diff per commit (got $COUNT)"
  else
    fail "package_branch should produce 2 diffs, got $COUNT"
  fi
}

test_package_branch_numbering_format() {
  local DIR="$FIXTURE_DIR/pb_num"
  local DIFFS="$FIXTURE_DIR/pb_num_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  commit_change "$DIR" "first"
  commit_change "$DIR" "second"
  commit_change "$DIR" "third"

  package_branch "$DIR" "$INIT_SHA" "$DIFFS" "main"

  if ls "$DIFFS/0001-"*.diff >/dev/null 2>&1 && \
     ls "$DIFFS/0002-"*.diff >/dev/null 2>&1 && \
     ls "$DIFFS/0003-"*.diff >/dev/null 2>&1; then
    pass "package_branch uses correct 0001-, 0002-, 0003- numbering"
  else
    fail "package_branch should use 0001-, 0002-, 0003- prefix"
  fi
}

test_package_branch_index_lines_stripped() {
  local DIR="$FIXTURE_DIR/pb_noindex"
  local DIFFS="$FIXTURE_DIR/pb_noindex_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  commit_change "$DIR" "change"

  package_branch "$DIR" "$INIT_SHA" "$DIFFS" "main"

  local DIFF_FILE
  DIFF_FILE=$(ls "$DIFFS/"*.diff | head -n1)
  if ! grep -q '^index ' "$DIFF_FILE"; then
    pass "package_branch strips index lines from diffs"
  else
    fail "package_branch should strip index lines from diffs"
  fi
}

test_package_branch_overwrites_existing() {
  local DIR="$FIXTURE_DIR/pb_overwrite"
  local DIFFS="$FIXTURE_DIR/pb_overwrite_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  # First run
  commit_change "$DIR" "first"
  package_branch "$DIR" "$INIT_SHA" "$DIFFS" "main"
  local COUNT1
  COUNT1=$(ls -1 "$DIFFS/"*.diff 2>/dev/null | wc -l)

  # Second run with more commits
  commit_change "$DIR" "second"
  commit_change "$DIR" "third"
  package_branch "$DIR" "$INIT_SHA" "$DIFFS" "main"
  local COUNT2
  COUNT2=$(ls -1 "$DIFFS/"*.diff 2>/dev/null | wc -l)

  if [[ "$COUNT2" -eq 3 ]]; then
    pass "package_branch overwrites existing diffs (got $COUNT2 after second run)"
  else
    fail "package_branch should overwrite, got $COUNT2 diffs"
  fi
}

# -------------------------
# package_branch — edge cases
# -------------------------
test_package_branch_no_commits() {
  local DIR="$FIXTURE_DIR/pb_nocommit"
  local DIFFS="$FIXTURE_DIR/pb_nocommit_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  # No commits since baseline
  package_branch "$DIR" "$INIT_SHA" "$DIFFS" "main" 2>/dev/null

  local COUNT
  COUNT=$(ls -1 "$DIFFS/"*.diff 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 0 ]]; then
    pass "package_branch produces no diffs when no commits since INIT_SHA"
  else
    fail "package_branch should produce 0 diffs, got $COUNT"
  fi
}

test_package_branch_missing_args() {
  if package_branch 2>/dev/null; then
    fail "package_branch should fail with missing args"
  else
    pass "package_branch fails with missing args"
  fi
}

test_package_branch_missing_sandbox_dir() {
  local DIFFS="$FIXTURE_DIR/pb_missing_sandbox"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"

  if package_branch "/nonexistent" "abc123" "$DIFFS" "main" 2>/dev/null; then
    fail "package_branch should fail with nonexistent SANDBOX_DIR"
  else
    pass "package_branch fails with nonexistent SANDBOX_DIR"
  fi
}

test_package_branch_missing_init_sha() {
  local DIR="$FIXTURE_DIR/pb_missing_init"
  local DIFFS="$FIXTURE_DIR/pb_missing_init_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_sandbox "$DIR"

  # Invalid INIT_SHA
  if package_branch "$DIR" "invalidsha" "$DIFFS" "main" 2>/dev/null; then
    fail "package_branch should fail with invalid INIT_SHA"
  else
    pass "package_branch fails with invalid INIT_SHA"
  fi
}

# -------------------------
# package_branch — diff content verification
# -------------------------
test_package_branch_diff_is_applicable() {
  local DIR="$FIXTURE_DIR/pb_apply"
  local TARGET="$FIXTURE_DIR/pb_apply_target"
  local DIFFS="$FIXTURE_DIR/pb_apply_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_sandbox "$DIR"
  make_sandbox "$TARGET"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  commit_change "$DIR" "agent change"
  package_branch "$DIR" "$INIT_SHA" "$DIFFS" "main"

  local DIFF_FILE
  DIFF_FILE=$(ls "$DIFFS/"*.diff | head -n1)

  # Apply diff to target (same baseline)
  if git -C "$TARGET" apply "$DIFF_FILE" 2>/dev/null; then
    pass "diff produced by package_branch applies cleanly via git apply"
  else
    fail "diff produced by package_branch does not apply via git apply"
  fi
}

test_package_branch_diff_contains_expected_content() {
  local DIR="$FIXTURE_DIR/pb_content"
  local DIFFS="$FIXTURE_DIR/pb_content_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  echo "unique content here" > "$DIR/unique.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "add unique file" --quiet

  package_branch "$DIR" "$INIT_SHA" "$DIFFS" "main"

  local DIFF_FILE
  DIFF_FILE=$(ls "$DIFFS/"*.diff | head -n1)

  if grep -q "unique content here" "$DIFF_FILE"; then
    pass "diff contains expected file content"
  else
    fail "diff should contain expected file content"
  fi
}

# -------------------------
# package_branch — single commit edge case
# -------------------------
test_package_branch_single_commit() {
  local DIR="$FIXTURE_DIR/pb_single"
  local DIFFS="$FIXTURE_DIR/pb_single_out"
  rm -rf "$DIFFS" && mkdir -p "$DIFFS"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  commit_change "$DIR" "only commit"

  package_branch "$DIR" "$INIT_SHA" "$DIFFS" "main"

  local COUNT
  COUNT=$(ls -1 "$DIFFS/"*.diff 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 1 ]]; then
    pass "package_branch handles single commit correctly"
  else
    fail "package_branch should produce 1 diff, got $COUNT"
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
run_test test_package_branch_missing_init_sha
run_test test_package_branch_diff_is_applicable
run_test test_package_branch_diff_contains_expected_content
run_test test_package_branch_single_commit

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]