#!/usr/bin/env bash
# Tests for libs/diff.sh: diff_on_exit and diff_on_autosave (thin dispatchers).
#
# Sources libs/diff.sh directly for function access.
# The functions are thin wrappers that: (1) validate args, (2) create subfolder
# and write EXPORT-TIME.txt, (3) call package_branch.

set -uo pipefail

FIXTURE_DIR=$(mktemp -d)
trap 'rm -rf "$FIXTURE_DIR"' EXIT

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/git_fixtures.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../libs/diff.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../libs/package_branch.sh"

plan 22

# -------------------------------------------------------------------
# Helper: create a clean sandbox with a baseline commit and SESSION_STATE
# -------------------------------------------------------------------
make_sandbox() {
  make_committed_repo "$1"
  local SHA
  SHA=$(get_init_sha "$1")
  write_session_state "$1"
  git -C "$1" branch -M main 2>/dev/null || true
  echo "$SHA"
}

# -------------------------------------------------------------------
# Helper: find a session directory by SESSION_TS and branch name
# -------------------------------------------------------------------
find_session_dir() {
  local BASE_DIR="$1"
  local SESSION_TS="$2"
  local BRANCH="$3"
  echo "$BASE_DIR/${SESSION_TS}-${BRANCH}"
}

# -------------------------------------------------------------------
# Helper: commit a change to the sandbox
# -------------------------------------------------------------------
commit_change() {
  local DIR="$1"
  local MSG="${2:-agent commit}"
  echo "$MSG" > "$DIR/change-${RANDOM}.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "$MSG" --quiet
}

# ===================================================================
# diff_on_exit
# ===================================================================

test_on_exit_creates_session_dir() {
  local DIR="$FIXTURE_DIR/oe_creates"
  local CHANGES="$FIXTURE_DIR/oe_creates_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120000" "main"

  if [[ -d "$CHANGES/20260408-120000-main/session" ]]; then
    pass "diff_on_exit creates session/ subfolder"
  else
    fail "diff_on_exit should create session/ subfolder"
  fi
}

test_on_exit_writes_uncommitted_diff() {
  local DIR="$FIXTURE_DIR/oe_uncommitted"
  local CHANGES="$FIXTURE_DIR/oe_uncommitted_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"

  echo "agent work" > "$DIR/result.txt"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120001" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120001" "main")
  if [[ -f "$SESSION_DIR/session/uncommitted.diff" && -s "$SESSION_DIR/session/uncommitted.diff" ]]; then
    pass "diff_on_exit writes non-empty uncommitted.diff in session/ dir"
  else
    fail "diff_on_exit should write non-empty uncommitted.diff in session/ dir"
  fi
}

test_on_exit_writes_all_changes_diff() {
  local DIR="$FIXTURE_DIR/oe_allchanges"
  local CHANGES="$FIXTURE_DIR/oe_allchanges_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"

  echo "agent work" > "$DIR/result.txt"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120002" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120002" "main")
  if [[ -f "$SESSION_DIR/session/all-changes.diff" && -s "$SESSION_DIR/session/all-changes.diff" ]]; then
    pass "diff_on_exit writes non-empty all-changes.diff in session/ dir"
  else
    fail "diff_on_exit should write non-empty all-changes.diff in session/ dir"
  fi
}

test_on_exit_writes_patches() {
  local DIR="$FIXTURE_DIR/oe_patches"
  local CHANGES="$FIXTURE_DIR/oe_patches_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  commit_change "$DIR" "first"
  commit_change "$DIR" "second"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120003" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120003" "main")
  local COUNT
  COUNT=$(find "$SESSION_DIR/session/patches" -name '*.diff' 2>/dev/null | wc -l)
  if [[ "$COUNT" -ge 1 ]]; then
    pass "diff_on_exit writes .diff files inside session/patches/ ($COUNT diffs)"
  else
    fail "diff_on_exit should write .diff files in session/patches/, got $COUNT"
  fi
}

test_on_exit_writes_changed_files() {
  local DIR="$FIXTURE_DIR/oe_changedfiles"
  local CHANGES="$FIXTURE_DIR/oe_changedfiles_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"

  echo "agent work" > "$DIR/result.txt"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120004" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120004" "main")
  if [[ -d "$SESSION_DIR/session/changed-files" ]] && [[ -f "$SESSION_DIR/session/changed-files/result.txt" ]]; then
    pass "diff_on_exit writes changed-files/ with file copies"
  else
    fail "diff_on_exit should write changed-files/ with file copies"
  fi
}

test_on_exit_no_sweep_commit() {
  local DIR="$FIXTURE_DIR/oe_nosweep"
  local CHANGES="$FIXTURE_DIR/oe_nosweep_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"

  # Uncommitted change — should NOT be committed by diff_on_exit
  echo "agent work" > "$DIR/result.txt"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120005" "main"

  # The working tree should still be dirty after diff_on_exit (no sweep commit)
  if ! git -C "$DIR" diff --quiet HEAD 2>/dev/null; then
    pass "diff_on_exit does not perform sweep commit (tree still dirty)"
  else
    fail "diff_on_exit should not sweep-commit; tree should still be dirty"
  fi
}

test_on_exit_writes_export_time() {
  local DIR="$FIXTURE_DIR/oe_exporttime"
  local CHANGES="$FIXTURE_DIR/oe_exporttime_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  commit_change "$DIR" "work"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120006" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120006" "main")
  if [[ -f "$SESSION_DIR/session/EXPORT-TIME.txt" && -s "$SESSION_DIR/session/EXPORT-TIME.txt" ]]; then
    pass "diff_on_exit writes EXPORT-TIME.txt in session/ dir"
  else
    fail "diff_on_exit should write EXPORT-TIME.txt in session/ dir"
  fi
}

test_on_exit_folder_name_format() {
  local DIR="$FIXTURE_DIR/oe_foldername"
  local CHANGES="$FIXTURE_DIR/oe_foldername_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  commit_change "$DIR" "work"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120007" "feature-branch"

  if [[ -d "$CHANGES/20260408-120007-feature-branch" ]]; then
    pass "diff_on_exit creates folder with <SESSION_TS>-<BRANCH> format"
  else
    fail "diff_on_exit should create folder 20260408-120007-feature-branch"
  fi
}

test_on_exit_multiple_sessions_accumulate() {
  local DIR1="$FIXTURE_DIR/oe_multi1"
  local DIR2="$FIXTURE_DIR/oe_multi2"
  local CHANGES="$FIXTURE_DIR/oe_multi_out"
  mkdir -p "$CHANGES"

  make_sandbox "$DIR1"
  echo "session 1 work" > "$DIR1/s1.txt"
  diff_on_exit "$DIR1" "$CHANGES" "20260408-100000" "main"

  make_sandbox "$DIR2"
  echo "session 2 work" > "$DIR2/s2.txt"
  diff_on_exit "$DIR2" "$CHANGES" "20260408-110000" "main"

  local COUNT
  COUNT=$(find "$CHANGES" -mindepth 1 -maxdepth 1 -type d | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "diff_on_exit accumulates multiple session directories"
  else
    fail "diff_on_exit should create separate dirs per session, got $COUNT"
  fi
}

test_on_exit_missing_args_fails() {
  if diff_on_exit "" "" "" "" 2>/dev/null; then
    fail "diff_on_exit should fail with missing args"
  else
    pass "diff_on_exit fails with missing args"
  fi
}

# ===================================================================
# diff_on_autosave
# ===================================================================

test_on_autosave_creates_autosave_dir() {
  local DIR="$FIXTURE_DIR/oa_creates"
  local CHANGES="$FIXTURE_DIR/oa_creates_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-120000" "main"

  if [[ -d "$CHANGES/20260408-120000-main/autosave" ]]; then
    pass "diff_on_autosave creates autosave/ subfolder"
  else
    fail "diff_on_autosave should create autosave/ subfolder"
  fi
}

test_on_autosave_writes_uncommitted_diff() {
  local DIR="$FIXTURE_DIR/oa_uncommitted"
  local CHANGES="$FIXTURE_DIR/oa_uncommitted_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"

  echo "checkpoint" > "$DIR/work.txt"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-120001" "main"

  local AUTOSAVE_DIR="$CHANGES/20260408-120001-main/autosave"
  if [[ -f "$AUTOSAVE_DIR/uncommitted.diff" && -s "$AUTOSAVE_DIR/uncommitted.diff" ]]; then
    pass "diff_on_autosave writes non-empty uncommitted.diff in autosave/ dir"
  else
    fail "diff_on_autosave should write non-empty uncommitted.diff in autosave/ dir"
  fi
}

test_on_autosave_does_not_commit() {
  local DIR="$FIXTURE_DIR/oa_nocommit"
  local CHANGES="$FIXTURE_DIR/oa_nocommit_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"

  echo "agent checkpoint" > "$DIR/work.txt"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-120002" "main"

  # Tree should still be dirty — autosave does not commit
  if ! git -C "$DIR" diff --quiet HEAD 2>/dev/null; then
    pass "diff_on_autosave does not commit pending changes"
  else
    fail "diff_on_autosave should not commit — tree should be dirty"
  fi
}

test_on_autosave_writes_patches() {
  local DIR="$FIXTURE_DIR/oa_patches"
  local CHANGES="$FIXTURE_DIR/oa_patches_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  commit_change "$DIR" "first"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-120003" "main"

  local AUTOSAVE_DIR="$CHANGES/20260408-120003-main/autosave"
  local COUNT
  COUNT=$(find "$AUTOSAVE_DIR/patches" -name '*.diff' 2>/dev/null | wc -l)
  if [[ "$COUNT" -ge 1 ]]; then
    pass "diff_on_autosave writes .diff files in autosave/patches/"
  else
    fail "diff_on_autosave should write .diff files in autosave/patches/"
  fi
}

test_on_autosave_writes_export_time() {
  local DIR="$FIXTURE_DIR/oa_exporttime"
  local CHANGES="$FIXTURE_DIR/oa_exporttime_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  commit_change "$DIR" "work"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-120004" "main"

  local AUTOSAVE_DIR="$CHANGES/20260408-120004-main/autosave"
  if [[ -f "$AUTOSAVE_DIR/EXPORT-TIME.txt" && -s "$AUTOSAVE_DIR/EXPORT-TIME.txt" ]]; then
    pass "diff_on_autosave writes EXPORT-TIME.txt in autosave/ dir"
  else
    fail "diff_on_autosave should write EXPORT-TIME.txt in autosave/ dir"
  fi
}

test_on_autosave_overwrites_previous() {
  local DIR="$FIXTURE_DIR/oa_overwrite"
  local CHANGES="$FIXTURE_DIR/oa_overwrite_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"

  echo "first tick" > "$DIR/work.txt"
  diff_on_autosave "$DIR" "$CHANGES" "20260408-120005" "main"

  sleep 1
  echo "second tick" > "$DIR/work.txt"
  diff_on_autosave "$DIR" "$CHANGES" "20260408-120005" "main"

  local AUTOSAVE_DIR="$CHANGES/20260408-120005-main/autosave"
  if grep -q "second" "$AUTOSAVE_DIR/uncommitted.diff" 2>/dev/null; then
    pass "diff_on_autosave overwrites previous autosave with latest state"
  else
    fail "diff_on_autosave should overwrite with latest state"
  fi
}

test_autosave_and_exit_write_separate_subfolders() {
  local DIR="$FIXTURE_DIR/oeoa_separate"
  local CHANGES="$FIXTURE_DIR/oeoa_separate_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  commit_change "$DIR" "work"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-120000" "main"
  diff_on_exit "$DIR" "$CHANGES" "20260408-120000" "main"

  local SESSION_DIR="$CHANGES/20260408-120000-main"
  if [[ -d "$SESSION_DIR/session" && -d "$SESSION_DIR/autosave" ]]; then
    pass "diff_on_exit and diff_on_autosave write separate session/ and autosave/ subfolders"
  else
    fail "diff_on_exit and diff_on_autosave should write separate subfolders"
  fi
}

test_on_autosave_missing_args_fails() {
  if diff_on_autosave "" "" "" "" 2>/dev/null; then
    fail "diff_on_autosave should fail with missing args"
  else
    pass "diff_on_autosave fails with missing args"
  fi
}
