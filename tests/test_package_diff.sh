#!/usr/bin/env bash
# Tests for libs/package_diff.sh — simplified uncommitted-diff packaging.
#
# The script always diffs against HEAD and produces uncommitted.diff + changed-files/.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$SCRIPT_DIR/libs/git_fixtures.sh"


# -------------------------------------------------------------------
# Helper: run package_diff.sh from inside a sandbox repo.
# First arg is the sandbox dir (cd into it before running),
# remaining args forwarded as-is. package_diff.sh discovers
# the repo via git rev-parse --show-toplevel, so CWD must be
# inside the target repo.
# -------------------------------------------------------------------
run_package_diff() {
  local SANDBOX_DIR="$1"
  shift
  (cd "$SANDBOX_DIR" && bash "$REPO_ROOT/src/libs/package_diff.sh" "$@")
}

# -------------------------------------------------------------------
# Helper: find the actual output dir created by package_diff.sh.
# package_diff.sh creates <TO_ARG>/diffs/<ts>-<label>-<runid>/.
# This returns the first such subdirectory or empty string.
# -------------------------------------------------------------------
find_output_dir() {
  local base="$1"
  find "$base" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | head -1
}

# ===================================================================
# Output structure
# ===================================================================

test_produces_uncommitted_diff() {
  local DIR="$FIXTURE_DIR/pd_uncommitted"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  echo "change" > "$DIR/new.txt"

  run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_u_out" --session-summary=test >/dev/null 2>&1

  local DIFF_FILE
  DIFF_FILE=$(find "$FIXTURE_DIR/pd_u_out" -name 'uncommitted.diff' 2>/dev/null | head -1)
  if [[ -n "$DIFF_FILE" ]] && [[ -s "$DIFF_FILE" ]]; then
    pass "package_diff.sh produces uncommitted.diff in output"
  else
    fail "package_diff.sh should produce uncommitted.diff"
  fi
}

test_produces_changed_files_dir() {
  local DIR="$FIXTURE_DIR/pd_changed"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  echo "change" > "$DIR/new.txt"

  run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_c_out" --session-summary=test >/dev/null 2>&1

  local FOUND
  FOUND=$(find "$FIXTURE_DIR/pd_c_out" -type d -name 'changed-files' 2>/dev/null | head -1)
  if [[ -n "$FOUND" ]]; then
    pass "package_diff.sh produces changed-files/ directory"
  else
    fail "package_diff.sh should produce changed-files/ directory"
  fi
}

test_output_dir_format() {
  local DIR="$FIXTURE_DIR/pd_outdir"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR" "20260501-120000"

  echo "change" > "$DIR/new.txt"

  run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_o_out" --session-summary=test_label >/dev/null 2>&1

  local OUTDIR
  OUTDIR=$(find_output_dir "$FIXTURE_DIR/pd_o_out")
  if [[ "$OUTDIR" == *"test_label"* ]]; then
    pass "package_diff.sh output dir contains session summary label"
  else
    fail "package_diff.sh output dir should contain 'test_label', got: '${OUTDIR}'"
  fi
}

# ===================================================================
# Content correctness
# ===================================================================

test_diff_contains_change() {
  local DIR="$FIXTURE_DIR/pd_content"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  echo "unique-content" > "$DIR/new.txt"

  run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_cnt_out" --session-summary=test >/dev/null 2>&1

  local DIFF_FILE
  DIFF_FILE=$(find "$FIXTURE_DIR/pd_cnt_out" -name 'uncommitted.diff' -type f 2>/dev/null | head -1)
  if [[ -n "$DIFF_FILE" ]] && grep -q "unique-content" "$DIFF_FILE" 2>/dev/null; then
    pass "uncommitted.diff contains expected file content"
  else
    fail "uncommitted.diff should contain expected content"
  fi
}

test_diff_includes_untracked() {
  local DIR="$FIXTURE_DIR/pd_untracked"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  echo "untracked" > "$DIR/untracked.txt"

  run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_ut_out" --session-summary=test >/dev/null 2>&1

  local DIFF_FILE
  DIFF_FILE=$(find "$FIXTURE_DIR/pd_ut_out" -name 'uncommitted.diff' -type f 2>/dev/null | head -1)
  if [[ -n "$DIFF_FILE" ]] && grep -q "untracked.txt" "$DIFF_FILE" 2>/dev/null; then
    pass "uncommitted.diff includes untracked files"
  else
    fail "uncommitted.diff should include untracked files"
  fi
}

test_strips_index_lines() {
  local DIR="$FIXTURE_DIR/pd_index"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  echo "content" > "$DIR/file.txt"

  run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_idx_out" --session-summary=test >/dev/null 2>&1

  local DIFF_FILE
  DIFF_FILE=$(find "$FIXTURE_DIR/pd_idx_out" -name 'uncommitted.diff' -type f 2>/dev/null | head -1)
  if [[ -n "$DIFF_FILE" ]] && ! grep -q '^index ' "$DIFF_FILE" 2>/dev/null; then
    pass "package_diff.sh strips index lines from text diffs"
  else
    fail "package_diff.sh should strip index lines"
  fi
}

test_no_changes_no_output() {
  local DIR="$FIXTURE_DIR/pd_none"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_no_out" --session-summary=test >/dev/null 2>&1

  # Should produce no diff artefacts (script exits early for clean trees)
  local DIFF_COUNT
  DIFF_COUNT=$(find "$FIXTURE_DIR/pd_no_out" -name '*.diff' -type f 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$DIFF_COUNT" -eq 0 ]]; then
    pass "package_diff.sh produces no diff files when no changes"
  else
    fail "package_diff.sh should produce no diff files on clean tree, found $DIFF_COUNT"
  fi
}

# ===================================================================
# Changed-files content
# ===================================================================

test_changed_files_has_copies() {
  local DIR="$FIXTURE_DIR/pd_copies"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  echo "modified" > "$DIR/file.txt"

  run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_cp_out" --session-summary=test >/dev/null 2>&1

  local OUTDIR
  OUTDIR=$(find_output_dir "$FIXTURE_DIR/pd_cp_out")
  local CF_DIR="$OUTDIR/changed-files"
  if [[ -d "$CF_DIR" ]] && [[ -f "$CF_DIR/file.txt" ]] && grep -q "modified" "$CF_DIR/file.txt" 2>/dev/null; then
    pass "package_diff.sh copies changed files with correct content"
  else
    fail "package_diff.sh should copy changed files into changed-files/"
  fi
}

test_changed_files_has_manifest() {
  local DIR="$FIXTURE_DIR/pd_manifest"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  echo "content" > "$DIR/a.txt"

  run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_mf_out" --session-summary=test >/dev/null 2>&1

  local OUTDIR
  OUTDIR=$(find_output_dir "$FIXTURE_DIR/pd_mf_out")
  local CF_DIR="$OUTDIR/changed-files"
  if [[ -f "$CF_DIR/MANIFEST.txt" ]] && grep -q "a.txt" "$CF_DIR/MANIFEST.txt" 2>/dev/null; then
    pass "package_diff.sh writes MANIFEST.txt in changed-files/"
  else
    fail "package_diff.sh should write MANIFEST.txt in changed-files/"
  fi
}

# ===================================================================
# Modes and fallbacks
# ===================================================================

test_falls_back_to_snapshot_summary() {
  local DIR="$FIXTURE_DIR/pd_snapshot"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  echo "change" > "$DIR/new.txt"

  run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_snap_out" >/dev/null 2>&1  # no --session-summary

  local OUTDIR
  OUTDIR=$(find_output_dir "$FIXTURE_DIR/pd_snap_out")
  if [[ "$OUTDIR" == *"snapshot"* ]]; then
    pass "package_diff.sh falls back to 'snapshot' as default summary"
  else
    fail "package_diff.sh should use 'snapshot' as default summary, got: '${OUTDIR}'"
  fi
}

test_usage_with_no_args() {
  # --help must be the only arg, no sandbox dir
  bash "$REPO_ROOT/src/libs/package_diff.sh" --help 2>&1 | grep -qi "package_diff\|package-diff" && {
    pass "package_diff.sh shows usage with --help"
  } || {
    fail "package_diff.sh should show usage with --help"
  }
}

test_diff_file_printed_in_output() {
  local DIR="$FIXTURE_DIR/pd_printed"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  echo "change" > "$DIR/new.txt"

  local OUTPUT
  OUTPUT=$(run_package_diff "$DIR" --to="$FIXTURE_DIR/pd_pr_out" --session-summary=test 2>&1)

  if echo "$OUTPUT" | grep -q "uncommitted.diff"; then
    pass "package_diff.sh output mentions uncommitted.diff"
  else
    fail "package_diff.sh output should mention uncommitted.diff"
  fi
}

# ===================================================================
# Run all tests
# ===================================================================

run_test test_produces_uncommitted_diff
run_test test_produces_changed_files_dir
run_test test_output_dir_format
run_test test_diff_contains_change
run_test test_diff_includes_untracked
run_test test_strips_index_lines
run_test test_no_changes_no_output
run_test test_changed_files_has_copies
run_test test_changed_files_has_manifest
run_test test_falls_back_to_snapshot_summary
run_test test_usage_with_no_args
run_test test_diff_file_printed_in_output

test_done
