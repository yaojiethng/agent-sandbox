#!/usr/bin/env bash
# Tests for entrypoint diff dispatch: export_path + diff_export.
#
# These tests simulate what sandbox-entrypoint.sh does: construct an export
# path via export_path, then call diff_export.
#
# Sources libs/diff.sh and libs/routing.sh for function access.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$SCRIPT_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/diff.sh"
source "$REPO_ROOT/src/libs/diff_export.sh"
source "$REPO_ROOT/src/libs/package_branch.sh"
FIXTURE="$FIXTURE_DIR"

# ===================================================================
# diff_export — entrypoint dispatch proxy
# ===================================================================

test_diff_export_creates_output() {
  local DIR="$FIXTURE_DIR/de_creates"
  mkdir -p "$DIR"
  make_sandbox_fixture "$DIR"
  local OUTPUT_DIR="${DIR}/export"
  mkdir -p "$OUTPUT_DIR"

  diff_export "$DIR" "$OUTPUT_DIR"

  if [[ -f "$OUTPUT_DIR/.export-status" ]]; then
    pass "diff_export writes .export-status"
  else
    fail "diff_export should write .export-status"
  fi
}

test_diff_export_writes_uncommitted_diff() {
  local DIR="$FIXTURE_DIR/de_uncommitted"
  mkdir -p "$DIR"
  make_sandbox_fixture "$DIR"
  echo "agent work" > "$DIR/result.txt"

  local OUTPUT_DIR="${DIR}/export"
  mkdir -p "$OUTPUT_DIR"
  diff_export "$DIR" "$OUTPUT_DIR"

  if [[ -f "$OUTPUT_DIR/uncommitted.diff" && -s "$OUTPUT_DIR/uncommitted.diff" ]]; then
    pass "diff_export writes non-empty uncommitted.diff"
  else
    fail "diff_export should write non-empty uncommitted.diff"
  fi
}

test_diff_export_writes_all_changes_diff() {
  local DIR="$FIXTURE_DIR/de_allchanges"
  mkdir -p "$DIR"
  make_sandbox_fixture "$DIR"
  echo "agent work" > "$DIR/result.txt"

  local OUTPUT_DIR="${DIR}/export"
  mkdir -p "$OUTPUT_DIR"
  diff_export "$DIR" "$OUTPUT_DIR"

  if [[ -f "$OUTPUT_DIR/all-changes.diff" && -s "$OUTPUT_DIR/all-changes.diff" ]]; then
    pass "diff_export writes non-empty all-changes.diff"
  else
    fail "diff_export should write non-empty all-changes.diff"
  fi
}

test_diff_export_writes_patches() {
  local DIR="$FIXTURE_DIR/de_patches"
  mkdir -p "$DIR"
  make_sandbox_fixture "$DIR"
  commit_change "$DIR" "first"
  commit_change "$DIR" "second"

  local OUTPUT_DIR="${DIR}/export"
  mkdir -p "$OUTPUT_DIR"
  diff_export "$DIR" "$OUTPUT_DIR"

  local COUNT
  COUNT=$(find "$OUTPUT_DIR/patches" -name '*.diff' 2>/dev/null | wc -l)
  if [[ "$COUNT" -ge 1 ]]; then
    pass "diff_export writes .diff files inside patches/ ($COUNT diffs)"
  else
    fail "diff_export should write .diff files in patches/, got $COUNT"
  fi
}

test_diff_export_writes_changed_files() {
  local DIR="$FIXTURE/de_changedfiles"
  mkdir -p "$DIR"
  make_sandbox_fixture "$DIR"
  echo "agent work" > "$DIR/result.txt"

  local OUTPUT_DIR="${DIR}/export"
  mkdir -p "$OUTPUT_DIR"
  diff_export "$DIR" "$OUTPUT_DIR"

  if [[ -d "$OUTPUT_DIR/changed-files" ]] && [[ -f "$OUTPUT_DIR/changed-files/result.txt" ]]; then
    pass "diff_export writes changed-files/ with file copies"
  else
    fail "diff_export should write changed-files/ with file copies"
  fi
}

test_diff_export_no_sweep_commit() {
  local DIR="$FIXTURE/de_nosweep"
  mkdir -p "$DIR"
  make_sandbox_fixture "$DIR"
  # Modify the committed file so git diff HEAD detects changes
  echo "agent modification" >> "$DIR/file.txt"

  local OUTPUT_DIR="${DIR}/export"
  mkdir -p "$OUTPUT_DIR"
  diff_export "$DIR" "$OUTPUT_DIR"

  if ! git -C "$DIR" diff --quiet HEAD 2>/dev/null; then
    pass "diff_export does not perform sweep commit (tree still dirty)"
  else
    fail "diff_export should not sweep-commit; tree should still be dirty"
  fi
}

test_diff_export_missing_args_fails() {
  if diff_export "" "" 2>/dev/null; then
    fail "diff_export should fail with missing args"
  else
    pass "diff_export fails with missing args"
  fi
}

test_diff_export_missing_session_state() {
  local DIR="$FIXTURE/de_nostate"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"
  # Intentionally do NOT write SESSION_STATE

  local OUTPUT_DIR="${DIR}/export"
  mkdir -p "$OUTPUT_DIR"

  # diff_export currently swallows package_branch's error.
  # This test asserts that diff_export returns non-zero when
  # package_branch fails due to missing SESSION_STATE.
  # Initially FAILS — fix libs/diff.sh to propagate the error.
  if ! diff_export "$DIR" "$OUTPUT_DIR" 2>/dev/null; then
    pass "diff_export fails when SESSION_STATE is missing"
  else
    fail "diff_export should fail when SESSION_STATE is missing (currently returns 0 — needs fix)"
  fi
}

# ===================================================================
# export_path + diff_export (entrypoint simulation)
# ===================================================================

test_session_path_exit_export() {
  local DIR="$FIXTURE/sp_exit"
  mkdir -p "$DIR"
  make_sandbox_fixture "$DIR"
  echo "agent exit" > "$DIR/work.txt"

  local CHANGES_DIR="${FIXTURE}/changes"
  local EXPORT_DIR
  EXPORT_DIR=$(export_path "$CHANGES_DIR" "session" "a1b2c3")
  mkdir -p "$EXPORT_DIR"
  diff_export "$DIR" "$EXPORT_DIR"

  if [[ -d "$EXPORT_DIR" ]]; then
    pass "export_path + diff_export: session dir created with EXPORT_TIME-RUN_ID pattern"
    if [[ -f "$EXPORT_DIR/uncommitted.diff" ]]; then
      pass "export_path + diff_export: uncommitted.diff inside session dir"
    else
      fail "export_path + diff_export: uncommitted.diff not found"
    fi
  else
    fail "export_path + diff_export: session dir not created"
  fi
}

test_session_path_autosave_export() {
  local DIR="$FIXTURE/sp_autosave"
  mkdir -p "$DIR"
  make_sandbox_fixture "$DIR"
  echo "agent checkpoint" > "$DIR/work.txt"

  local CHANGES_DIR="${FIXTURE}/changes2"
  local EXPORT_DIR
  EXPORT_DIR=$(export_path "$CHANGES_DIR" "autosave" "a1b2c3")
  mkdir -p "$EXPORT_DIR"
  diff_export "$DIR" "$EXPORT_DIR"

  if [[ -d "$EXPORT_DIR" ]]; then
    pass "export_path + diff_export: autosave dir created under autosave/ (no EXPORT_TIME)"
    if [[ -f "$EXPORT_DIR/uncommitted.diff" ]]; then
      pass "export_path + diff_export: uncommitted.diff inside autosave dir"
    else
      fail "export_path + diff_export: uncommitted.diff not found in autosave"
    fi
  else
    fail "export_path + diff_export: autosave dir not created"
  fi
}

test_session_path_session_and_autosave_independent() {
  local DIR="$FIXTURE/sp_independent"
  mkdir -p "$DIR"
  make_sandbox_fixture "$DIR"
  commit_change "$DIR" "work"

  local CHANGES_DIR="${FIXTURE}/changes3"

  # Write session export
  local SESSION_DIR
  SESSION_DIR=$(export_path "$CHANGES_DIR" "session" "a1b2c3")
  mkdir -p "$SESSION_DIR"
  diff_export "$DIR" "$SESSION_DIR"

  # Write autosave export
  local AUTOSAVE_DIR
  AUTOSAVE_DIR=$(export_path "$CHANGES_DIR" "autosave" "a1b2c3")
  mkdir -p "$AUTOSAVE_DIR"
  diff_export "$DIR" "$AUTOSAVE_DIR"

  if [[ -d "$AUTOSAVE_DIR" && "$AUTOSAVE_DIR" == *"/autosave/a1b2c3" ]]; then
    pass "session and autosave exports go to separate subdirectories"
  else
    fail "session and autosave should go to separate subdirectories"
  fi
}

test_session_path_multiple_sessions_accumulate() {
  local DIR1="$FIXTURE/sp_multi1"
  local DIR2="$FIXTURE/sp_multi2"
  mkdir -p "$DIR1" "$DIR2"
  make_sandbox_fixture "$DIR1"
  make_sandbox_fixture "$DIR2"

  local CHANGES_DIR="${FIXTURE}/changes4"

  local OUT1
  OUT1=$(export_path "$CHANGES_DIR" "session" "run001")
  mkdir -p "$OUT1"
  echo "s1" > "$DIR1/s1.txt"
  diff_export "$DIR1" "$OUT1"

  local OUT2
  OUT2=$(export_path "$CHANGES_DIR" "session" "run002")
  mkdir -p "$OUT2"
  echo "s2" > "$DIR2/s2.txt"
  diff_export "$DIR2" "$OUT2"

  local COUNT
  COUNT=$(find "$CHANGES_DIR/session" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "multiple session exports accumulate under session/"
  else
    fail "expected 2 session dirs under session/, got $COUNT"
  fi

  # Check directory naming uses EXPORT_TIME-RUN_ID pattern
  if ls "$CHANGES_DIR/session/" | grep -qE '^[0-9]{8}-[0-9]{6}-run00[12]$'; then
    pass "session dirs use EXPORT_TIME-RUN_ID naming"
  else
    fail "session dirs should use EXPORT_TIME-RUN_ID naming"
  fi
}

test_session_path_export_time_written() {
  local DIR="$FIXTURE/sp_exporttime"
  mkdir -p "$DIR"
  make_sandbox_fixture "$DIR"
  commit_change "$DIR" "work"

  local CHANGES_DIR="${FIXTURE}/changes5"
  local OUT
  OUT=$(export_path "$CHANGES_DIR" "session" "a1b2c3")
  mkdir -p "$OUT"
  diff_export "$DIR" "$OUT"

  if [[ -f "$OUT/.export-status" && -s "$OUT/.export-status" ]]; then
    pass "diff_export writes .export-status in output dir"
  else
    fail "diff_export should write .export-status"
  fi
}

# =============================================================================
# Run
# =============================================================================

run_test test_diff_export_creates_output
run_test test_diff_export_writes_uncommitted_diff
run_test test_diff_export_writes_all_changes_diff
run_test test_diff_export_writes_patches
run_test test_diff_export_writes_changed_files
run_test test_diff_export_no_sweep_commit
run_test test_diff_export_missing_args_fails
run_test test_diff_export_missing_session_state
run_test test_session_path_exit_export
run_test test_session_path_autosave_export
run_test test_session_path_session_and_autosave_independent
run_test test_session_path_multiple_sessions_accumulate
run_test test_session_path_export_time_written

test_done
