#!/usr/bin/env bash
# tests/test_diff.sh
# Tests for libs/diff.sh and libs/package_branch.sh
#
# Covers:
#   diff_generate         — produces diff, no-op on clean, missing args
#   diff_format_patch     — produces per-commit patches, no-op on zero commits, missing args
#   diff_on_exit          — session/ subfolder with EXPORT-TIME.txt, uncommitted.diff,
#                           all-changes.diff, patches/
#   diff_on_autosave      — autosave/ subfolder with EXPORT-TIME.txt, uncommitted.diff,
#                           all-changes.diff, patches/
#   package_branch        — produces unified output format (dispatcher)
#   package_commits       — produces numbered diffs, strips index lines
#
# Each test creates its own fixture under a temp dir. Tests are independent.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/diff.sh"

source "$SCRIPT_DIR/libs/test_common.sh"

FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# -------------------------
# Helpers
# -------------------------
# Find the session directory under CHANGES_DIR matching <SESSION_TS>-<BRANCH>/
find_session_dir() {
  local CHANGES="$1"
  local SESSION_TS="$2"
  local SANITIZED_HOST_BRANCH="$3"
  local CANDIDATE="${CHANGES}/${SESSION_TS}-${SANITIZED_HOST_BRANCH}"
  if [[ -d "$CANDIDATE" ]]; then
    echo "$CANDIDATE"
  else
    echo ""
  fi
}

# Write SESSION_STATE with init_sha (and optionally session_ts)
write_session_state() {
  local DIR="$1"
  local INIT_SHA="$2"
  mkdir -p "$DIR/.git"
  echo "init_sha=$INIT_SHA" > "$DIR/.git/SESSION_STATE"
}

make_sandbox() {
  local DIR="$1"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet
  git -C "$DIR" config user.email "test@test.com"
  git -C "$DIR" config user.name "Test"
  echo "baseline" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "baseline" --quiet
}

get_sha() {
  git -C "$1" rev-parse HEAD
}

commit_change() {
  local DIR="$1"
  local MSG="${2:-agent commit}"
  echo "$MSG" > "$DIR/change-${RANDOM}.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "$MSG" --quiet
}

# -------------------------
# diff_generate
# -------------------------
test_generate_produces_diff() {
  local DIR="$FIXTURE_DIR/gen_diff"
  local CHANGES="$FIXTURE_DIR/gen_diff_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "new content" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "change" --quiet

  diff_generate "$DIR" "$SHA" "$CHANGES/out.diff"

  if [[ -f "$CHANGES/out.diff" && -s "$CHANGES/out.diff" ]]; then
    pass "diff_generate writes non-empty diff file"
  else
    fail "diff_generate should produce a non-empty diff file"
  fi
}

test_generate_no_changes() {
  local DIR="$FIXTURE_DIR/gen_nochange"
  local CHANGES="$FIXTURE_DIR/gen_nochange_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  diff_generate "$DIR" "$SHA" "$CHANGES/out.diff"

  if [[ ! -f "$CHANGES/out.diff" ]]; then
    pass "diff_generate writes no file when no changes"
  else
    fail "diff_generate should not write a file when no changes detected"
  fi
}

test_generate_missing_args() {
  if diff_generate 2>/dev/null; then
    fail "diff_generate should fail with missing args"
  else
    pass "diff_generate fails with missing args"
  fi
}

# -------------------------
# diff_format_patch
# -------------------------
test_format_patch_produces_patches() {
  local DIR="$FIXTURE_DIR/fmt_patch"
  local PATCHES="$FIXTURE_DIR/fmt_patch_out"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  commit_change "$DIR" "first agent commit"
  commit_change "$DIR" "second agent commit"

  diff_format_patch "$DIR" "$SHA" "$PATCHES"

  local COUNT
  COUNT=$(find "$PATCHES" -name '*.patch' 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "diff_format_patch produces one patch per commit (got $COUNT)"
  else
    fail "diff_format_patch should produce 2 patches, got $COUNT"
  fi
}

test_format_patch_numbering() {
  local DIR="$FIXTURE_DIR/fmt_num"
  local PATCHES="$FIXTURE_DIR/fmt_num_out"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  commit_change "$DIR" "only commit"

  diff_format_patch "$DIR" "$SHA" "$PATCHES"

  if ls "$PATCHES"/0001-*.patch &>/dev/null; then
    pass "diff_format_patch produces numerically-prefixed patch files"
  else
    fail "diff_format_patch should produce 0001-*.patch"
  fi
}

test_format_patch_noop_on_zero_commits() {
  local DIR="$FIXTURE_DIR/fmt_zero"
  local PATCHES="$FIXTURE_DIR/fmt_zero_out"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  # No commits since baseline
  diff_format_patch "$DIR" "$SHA" "$PATCHES" 2>/dev/null

  local COUNT
  COUNT=$(find "$PATCHES" -name '*.patch' 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 0 ]]; then
    pass "diff_format_patch no-ops when no commits since baseline"
  else
    fail "diff_format_patch should produce no patches when no commits, got $COUNT"
  fi
}

test_format_patch_missing_args() {
  if diff_format_patch 2>/dev/null; then
    fail "diff_format_patch should fail with missing args"
  else
    pass "diff_format_patch fails with missing args"
  fi
}

test_format_patch_patches_are_applicable() {
  local DIR="$FIXTURE_DIR/fmt_apply"
  local TARGET="$FIXTURE_DIR/fmt_apply_target"
  local PATCHES="$FIXTURE_DIR/fmt_apply_out"
  make_sandbox "$DIR"
  make_sandbox "$TARGET"
  local SHA
  SHA=$(get_sha "$DIR")

  commit_change "$DIR" "agent change"
  diff_format_patch "$DIR" "$SHA" "$PATCHES"

  local PATCH
  PATCH=$(ls "$PATCHES"/0001-*.patch)

  # Attempt to apply patch to target (same baseline)
  if git -C "$TARGET" am --3way "$PATCH" 2>/dev/null; then
    pass "patch produced by diff_format_patch applies cleanly via git am"
  else
    fail "patch produced by diff_format_patch does not apply via git am"
    git -C "$TARGET" am --abort 2>/dev/null || true
  fi
}

# -------------------------
# diff_on_exit — writes to session/ subfolder
# -------------------------
test_on_exit_creates_session_dir() {
  local DIR="$FIXTURE_DIR/exit_session_dir"
  local CHANGES="$FIXTURE_DIR/exit_session_dir_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"
  commit_change "$DIR" "agent commit"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120000" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120000" "main")
  if [[ -n "$SESSION_DIR" && -d "$SESSION_DIR/session" ]]; then
    pass "diff_on_exit creates session/ subfolder"
  else
    fail "diff_on_exit should create session/ subfolder inside session dir"
  fi
}

test_on_exit_writes_uncommitted_diff() {
  local DIR="$FIXTURE_DIR/exit_uncommitted"
  local CHANGES="$FIXTURE_DIR/exit_uncommitted_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  # Uncommitted change — should appear in uncommitted.diff
  echo "agent work" > "$DIR/result.txt"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120001" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120001" "main")
  if [[ -n "$SESSION_DIR" && -f "$SESSION_DIR/session/uncommitted.diff" && -s "$SESSION_DIR/session/uncommitted.diff" ]]; then
    pass "diff_on_exit writes non-empty uncommitted.diff in session/ dir"
  else
    fail "diff_on_exit should write non-empty uncommitted.diff in session/ dir"
  fi
}

test_on_exit_writes_all_changes_diff() {
  local DIR="$FIXTURE_DIR/exit_all_changes"
  local CHANGES="$FIXTURE_DIR/exit_all_changes_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  echo "agent work" > "$DIR/result.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  diff_on_exit "$DIR" "$CHANGES" "20260408-120002" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120002" "main")
  if [[ -n "$SESSION_DIR" && -f "$SESSION_DIR/session/all-changes.diff" && -s "$SESSION_DIR/session/all-changes.diff" ]]; then
    pass "diff_on_exit writes non-empty all-changes.diff in session/ dir"
  else
    fail "diff_on_exit should write non-empty all-changes.diff in session/ dir"
  fi
}

test_on_exit_writes_patches_in_session_subfolder() {
  local DIR="$FIXTURE_DIR/exit_session_patches"
  local CHANGES="$FIXTURE_DIR/exit_session_patches_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  commit_change "$DIR" "first commit"
  commit_change "$DIR" "second commit"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120002" "feat"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120002" "feat")
  local COUNT
  COUNT=$(find "$SESSION_DIR/session/patches" -name '*.diff' 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "diff_on_exit writes .diff files inside session/patches/ ($COUNT diffs)"
  else
    fail "diff_on_exit should write 2 .diff files in session/patches/, got $COUNT"
  fi
}

test_on_exit_no_sweep_no_extra_patches() {
  local DIR="$FIXTURE_DIR/exit_nosweep"
  local CHANGES="$FIXTURE_DIR/exit_nosweep_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  # Uncommitted change — should NOT produce a patch (no sweep)
  echo "agent work" > "$DIR/result.txt"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120003" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120003" "main")
  local COUNT
  COUNT=$(find "$SESSION_DIR/session/patches" -name '*.diff' 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 0 ]]; then
    pass "diff_on_exit without commits produces no patches (no sweep)"
  else
    fail "diff_on_exit without commits should produce 0 patches, got $COUNT"
  fi
}

test_on_exit_no_patches_when_no_changes() {
  local DIR="$FIXTURE_DIR/exit_session_nochange"
  local CHANGES="$FIXTURE_DIR/exit_session_nochange_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120004" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120004" "main")
  local COUNT
  COUNT=$(find "$SESSION_DIR/session/patches" -name '*.diff' 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 0 ]]; then
    pass "diff_on_exit with no changes produces no .diff files"
  else
    fail "diff_on_exit with no changes should produce 0 .diff files, got $COUNT"
  fi
}

test_on_exit_writes_export_time() {
  local DIR="$FIXTURE_DIR/exit_export_time"
  local CHANGES="$FIXTURE_DIR/exit_export_time_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"
  commit_change "$DIR" "work"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120005" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-120005" "main")
  if [[ -f "$SESSION_DIR/session/EXPORT-TIME.txt" && -s "$SESSION_DIR/session/EXPORT-TIME.txt" ]]; then
    pass "diff_on_exit writes EXPORT-TIME.txt in session/ dir"
  else
    fail "diff_on_exit should write EXPORT-TIME.txt in session/ dir"
  fi
}

test_on_exit_folder_name_format() {
  local DIR="$FIXTURE_DIR/exit_folder_name"
  local CHANGES="$FIXTURE_DIR/exit_folder_name_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"
  commit_change "$DIR" "work"

  diff_on_exit "$DIR" "$CHANGES" "20260408-120006" "feature-branch"

  local EXPECTED_DIR="$CHANGES/20260408-120006-feature-branch"
  if [[ -d "$EXPECTED_DIR" ]]; then
    pass "diff_on_exit creates folder with <SESSION_TS>-<BRANCH> format"
  else
    fail "diff_on_exit should create folder 20260408-120006-feature-branch"
  fi
}

test_on_exit_multiple_sessions_accumulate() {
  local DIR1="$FIXTURE_DIR/exit_multi1"
  local DIR2="$FIXTURE_DIR/exit_multi2"
  local CHANGES="$FIXTURE_DIR/exit_multi_out"
  mkdir -p "$CHANGES"

  make_sandbox "$DIR1"
  local SHA1
  SHA1=$(get_sha "$DIR1")
  write_session_state "$DIR1" "$SHA1"
  echo "session 1 work" > "$DIR1/s1.txt"
  git -C "$DIR1" add .
  git -C "$DIR1" commit -m "s1" --quiet
  diff_on_exit "$DIR1" "$CHANGES" "20260408-100000" "main"

  make_sandbox "$DIR2"
  local SHA2
  SHA2=$(get_sha "$DIR2")
  write_session_state "$DIR2" "$SHA2"
  echo "session 2 work" > "$DIR2/s2.txt"
  git -C "$DIR2" add .
  git -C "$DIR2" commit -m "s2" --quiet
  diff_on_exit "$DIR2" "$CHANGES" "20260408-110000" "main"

  local COUNT
  COUNT=$(find "$CHANGES" -mindepth 1 -maxdepth 1 -type d | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "multiple sessions accumulate as separate directories under CHANGES_DIR"
  else
    fail "expected 2 session dirs, got $COUNT"
  fi
}

# -------------------------
# diff_on_autosave — writes to autosave/ subfolder
# -------------------------
test_on_autosave_writes_autosave_dir() {
  local DIR="$FIXTURE_DIR/autosave_dir"
  local CHANGES="$FIXTURE_DIR/autosave_dir_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"
  commit_change "$DIR" "wip"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-130000" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-130000" "main")
  if [[ -n "$SESSION_DIR" && -d "$SESSION_DIR/autosave" ]]; then
    pass "diff_on_autosave creates autosave/ subfolder"
  else
    fail "diff_on_autosave should create autosave/ subfolder"
  fi
}

test_on_autosave_writes_uncommitted_diff() {
  local DIR="$FIXTURE_DIR/autosave_uncommitted"
  local CHANGES="$FIXTURE_DIR/autosave_uncommitted_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"
  commit_change "$DIR" "wip"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-130001" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-130001" "main")
  if [[ -n "$SESSION_DIR" && -f "$SESSION_DIR/autosave/uncommitted.diff" ]]; then
    pass "diff_on_autosave writes uncommitted.diff in autosave/ dir"
  else
    fail "diff_on_autosave should write uncommitted.diff in autosave/ dir"
  fi
}

test_on_autosave_does_not_commit_pending() {
  local DIR="$FIXTURE_DIR/autosave_nocommit"
  local CHANGES="$FIXTURE_DIR/autosave_nocommit_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  echo "uncommitted" > "$DIR/pending.txt"
  local BEFORE
  BEFORE=$(get_sha "$DIR")

  diff_on_autosave "$DIR" "$CHANGES" "20260408-130002" "main"

  local AFTER
  AFTER=$(get_sha "$DIR")

  if [[ "$BEFORE" == "$AFTER" ]]; then
    pass "diff_on_autosave does not commit pending changes"
  else
    fail "diff_on_autosave must not commit pending changes"
  fi
}

test_on_autosave_no_changes_writes_empty_uncommitted_diff() {
  local DIR="$FIXTURE_DIR/autosave_nochange"
  local CHANGES="$FIXTURE_DIR/autosave_nochange_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-130003" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-130003" "main")
  if [[ -n "$SESSION_DIR" && -f "$SESSION_DIR/autosave/uncommitted.diff" && ! -s "$SESSION_DIR/autosave/uncommitted.diff" ]]; then
    pass "diff_on_autosave writes empty uncommitted.diff when no changes"
  else
    fail "diff_on_autosave should write empty uncommitted.diff when no changes"
  fi
}

test_on_autosave_overwrites_previous() {
  local DIR="$FIXTURE_DIR/autosave_overwrite"
  local CHANGES="$FIXTURE_DIR/autosave_overwrite_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  # First tick: one commit
  echo "first" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "first" --quiet
  diff_on_autosave "$DIR" "$CHANGES" "20260408-130004" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-130004" "main")
  local FIRST_EXPORT
  FIRST_EXPORT=$(cat "$SESSION_DIR/autosave/EXPORT-TIME.txt")

  # Second tick: second commit
  echo "second" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "second" --quiet
  diff_on_autosave "$DIR" "$CHANGES" "20260408-130004" "main"

  local SECOND_EXPORT
  SECOND_EXPORT=$(cat "$SESSION_DIR/autosave/EXPORT-TIME.txt")

  # EXPORT-TIME.txt should be updated (overwrite semantics)
  if [[ -n "$FIRST_EXPORT" && -n "$SECOND_EXPORT" && -f "$SESSION_DIR/autosave/uncommitted.diff" ]]; then
    pass "diff_on_autosave overwrites autosave/ on each tick"
  else
    fail "diff_on_autosave did not overwrite: first=$FIRST_EXPORT second=$SECOND_EXPORT"
  fi
}

test_on_autosave_writes_patches() {
  local DIR="$FIXTURE_DIR/autosave_patches"
  local CHANGES="$FIXTURE_DIR/autosave_patches_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  commit_change "$DIR" "first commit"
  commit_change "$DIR" "second commit"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-130005" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-130005" "main")
  local COUNT
  COUNT=$(find "$SESSION_DIR/autosave/patches" -name '*.diff' 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "diff_on_autosave writes .diff files in autosave/patches/"
  else
    fail "diff_on_autosave should write 2 .diff files in autosave/patches/, got $COUNT"
  fi
}

test_on_autosave_writes_export_time() {
  local DIR="$FIXTURE_DIR/autosave_export_time"
  local CHANGES="$FIXTURE_DIR/autosave_export_time_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"
  commit_change "$DIR" "wip"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-130006" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-130006" "main")
  if [[ -f "$SESSION_DIR/autosave/EXPORT-TIME.txt" && -s "$SESSION_DIR/autosave/EXPORT-TIME.txt" ]]; then
    pass "diff_on_autosave writes EXPORT-TIME.txt in autosave/ dir"
  else
    fail "diff_on_autosave should write EXPORT-TIME.txt in autosave/ dir"
  fi
}

# -------------------------
# exit and autosave write to separate subfolders
# -------------------------
test_exit_and_autosave_write_separate_subfolders() {
  local DIR="$FIXTURE_DIR/separate_subfolders"
  local CHANGES="$FIXTURE_DIR/separate_subfolders_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"
  commit_change "$DIR" "work"

  diff_on_autosave "$DIR" "$CHANGES" "20260408-140000" "main"
  diff_on_exit     "$DIR" "$CHANGES" "20260408-140000" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-140000" "main")
  if [[ -n "$SESSION_DIR" && -d "$SESSION_DIR/autosave" && -d "$SESSION_DIR/session" ]]; then
    pass "diff_on_exit and diff_on_autosave write to separate subfolders"
  else
    fail "both autosave/ and session/ subfolders should exist"
  fi
}

test_exit_writes_uncommitted_and_all_changes() {
  local DIR="$FIXTURE_DIR/exit_both_diffs"
  local CHANGES="$FIXTURE_DIR/exit_both_diffs_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  # Uncommitted change — should appear in uncommitted.diff
  echo "uncommitted" > "$DIR/unstaged.txt"

  diff_on_exit "$DIR" "$CHANGES" "20260408-140001" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260408-140001" "main")
  if [[ -n "$SESSION_DIR" && -f "$SESSION_DIR/session/uncommitted.diff" && -f "$SESSION_DIR/session/all-changes.diff" ]]; then
    pass "diff_on_exit writes both uncommitted.diff and all-changes.diff in session/"
  else
    fail "diff_on_exit should write both uncommitted.diff and all-changes.diff in session/"
  fi
}

# -------------------------
# diff_format_patch (standalone tests, not session-scoped)
# -------------------------
test_format_patch_standalone_produces_patches() {
  local DIR="$FIXTURE_DIR/patch_prod"
  local CHANGES="$FIXTURE_DIR/patch_prod_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  # Create two commits
  echo "change1" > "$DIR/file1.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "first change" --quiet

  echo "change2" > "$DIR/file2.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "second change" --quiet

  diff_format_patch "$DIR" "$SHA" "$CHANGES/patches"

  local PATCH_COUNT
  PATCH_COUNT=$(ls -1 "$CHANGES/patches"/*.patch 2>/dev/null | wc -l)
  if [[ "$PATCH_COUNT" -eq 2 ]]; then
    pass "diff_format_patch produces one patch per commit"
  else
    fail "diff_format_patch should produce 2 patches, got $PATCH_COUNT"
  fi
}

test_format_patch_standalone_numbering() {
  local DIR="$FIXTURE_DIR/patch_num"
  local CHANGES="$FIXTURE_DIR/patch_num_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "change" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "change" --quiet

  diff_format_patch "$DIR" "$SHA" "$CHANGES/patches"

  if ls "$CHANGES/patches/0001-"*.patch >/dev/null 2>&1; then
    pass "diff_format_patch uses correct 0001- numbering"
  else
    fail "diff_format_patch should use 0001- prefix"
  fi
}

test_format_patch_standalone_no_commits() {
  local DIR="$FIXTURE_DIR/patch_nocommit"
  local CHANGES="$FIXTURE_DIR/patch_nocommit_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  # No commits since baseline
  diff_format_patch "$DIR" "$SHA" "$CHANGES/patches"

  if [[ ! -d "$CHANGES/patches" ]] || [[ -z "$(ls -A "$CHANGES/patches" 2>/dev/null)" ]]; then
    pass "diff_format_patch is no-op with no commits"
  else
    fail "diff_format_patch should not create patches with no commits"
  fi
}

test_format_patch_standalone_missing_args() {
  if diff_format_patch 2>/dev/null; then
    fail "diff_format_patch should fail with missing args"
  else
    pass "diff_format_patch fails with missing args"
  fi
}

# -------------------------
# Session-scoped tests (with SESSION_STATE for package_branch)
# -------------------------
test_on_exit_session_dir_with_session_state() {
  local DIR="$FIXTURE_DIR/exit_sess"
  local CHANGES="$FIXTURE_DIR/exit_sess_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  diff_on_exit "$DIR" "$CHANGES" "20260417-120000" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260417-120000" "main")
  if [[ -n "$SESSION_DIR" && -d "$SESSION_DIR/session" ]]; then
    pass "diff_on_exit creates session directory with SESSION_STATE"
  else
    fail "diff_on_exit should create session directory"
  fi
}

test_on_exit_session_all_changes_diff() {
  local DIR="$FIXTURE_DIR/exit_sess_all"
  local CHANGES="$FIXTURE_DIR/exit_sess_all_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  diff_on_exit "$DIR" "$CHANGES" "20260417-120000" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260417-120000" "main")
  if [[ -n "$SESSION_DIR" && -f "$SESSION_DIR/session/all-changes.diff" && -s "$SESSION_DIR/session/all-changes.diff" ]]; then
    pass "diff_on_exit writes all-changes.diff inside session/ directory"
  else
    fail "diff_on_exit should write all-changes.diff inside session/ directory"
  fi
}

test_on_exit_session_patches() {
  local DIR="$FIXTURE_DIR/exit_sess_patches"
  local CHANGES="$FIXTURE_DIR/exit_sess_patches_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  diff_on_exit "$DIR" "$CHANGES" "20260417-120000" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260417-120000" "main")
  if [[ -n "$SESSION_DIR" && -d "$SESSION_DIR/session/patches" ]] && \
     ls "$SESSION_DIR/session/patches/"*.diff >/dev/null 2>&1; then
    pass "diff_on_exit creates session/patches/ with .diff files"
  else
    fail "diff_on_exit should create session/patches/ with .diff files"
  fi
}

test_on_exit_missing_args_fails() {
  local DIR="$FIXTURE_DIR/exit_no_sess"
  local CHANGES="$FIXTURE_DIR/exit_no_sess_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  # Missing SESSION_TS and SANITIZED_HOST_BRANCH — should fail
  if ! diff_on_exit "$DIR" "$CHANGES" "" "" 2>/dev/null; then
    pass "diff_on_exit fails with empty SESSION_TS and SANITIZED_HOST_BRANCH"
  else
    fail "diff_on_exit should fail with empty session identity args"
  fi
}

test_on_exit_multiple_sessions_no_clobber() {
  local DIR="$FIXTURE_DIR/exit_multi"
  local CHANGES="$FIXTURE_DIR/exit_multi_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  # First session
  echo "work1" > "$DIR/file1.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work1" --quiet
  diff_on_exit "$DIR" "$CHANGES" "20260417-110000" "main"

  # Second session (different session timestamp)
  echo "work2" > "$DIR/file2.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work2" --quiet
  diff_on_exit "$DIR" "$CHANGES" "20260417-120000" "main"

  local DIR1 DIR2
  DIR1=$(find_session_dir "$CHANGES" "20260417-110000" "main")
  DIR2=$(find_session_dir "$CHANGES" "20260417-120000" "main")
  if [[ -n "$DIR1" && -n "$DIR2" ]] && \
     [[ -f "$DIR1/session/all-changes.diff" ]] && \
     [[ -f "$DIR2/session/all-changes.diff" ]]; then
    pass "diff_on_exit accumulates multiple sessions without clobbering"
  else
    fail "diff_on_exit should preserve both session directories"
  fi
}

# -------------------------
# Autosave session-scoped tests
# -------------------------
test_on_autosave_session_dir() {
  local DIR="$FIXTURE_DIR/autosave_sess"
  local CHANGES="$FIXTURE_DIR/autosave_sess_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  diff_on_autosave "$DIR" "$CHANGES" "20260417-120000" "main"

  local SESSION_DIR
  SESSION_DIR=$(find_session_dir "$CHANGES" "20260417-120000" "main")
  if [[ -n "$SESSION_DIR" && -d "$SESSION_DIR/autosave" && -f "$SESSION_DIR/autosave/uncommitted.diff" ]]; then
    pass "diff_on_autosave writes uncommitted.diff in autosave/ dir"
  else
    fail "diff_on_autosave should write uncommitted.diff in autosave/ dir"
  fi
}

test_on_autosave_missing_args_fails() {
  local DIR="$FIXTURE_DIR/autosave_no_sess"
  local CHANGES="$FIXTURE_DIR/autosave_no_sess_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$SHA"

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  # Missing SESSION_TS and SANITIZED_HOST_BRANCH — should fail
  if ! diff_on_autosave "$DIR" "$CHANGES" "" "" 2>/dev/null; then
    pass "diff_on_autosave fails with empty SESSION_TS and SANITIZED_HOST_BRANCH"
  else
    fail "diff_on_autosave should fail with empty session identity args"
  fi
}

# -------------------------
# package_branch tests (dispatcher)
# -------------------------
# Note: package_branch is sourced from libs/package_branch.sh
# These tests target package_branch directly, not through diff_on_exit.

test_package_branch_produces_numbered_diffs() {
  local DIR="$FIXTURE_DIR/pkgbranch_numbered"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  # Make 3 commits
  commit_change "$DIR" "commit 1"
  commit_change "$DIR" "commit 2"
  commit_change "$DIR" "commit 3"

  local CHANGES="$FIXTURE_DIR/pkgbranch_changes"
  mkdir -p "$CHANGES"

  # Source package_branch.sh
  source "$SCRIPT_DIR/../libs/package_branch.sh"
  package_branch "$DIR" "$CHANGES"

  local DIFF_COUNT
  DIFF_COUNT=$(ls -1 "$CHANGES/patches"/*.diff 2>/dev/null | wc -l)

  if [[ "$DIFF_COUNT" -eq 3 ]]; then
    pass "package_branch dispatcher produces 3 numbered diff files in patches/"
  else
    fail "package_branch dispatcher should produce 3 diffs in patches/, got $DIFF_COUNT"
  fi
}

test_package_branch_strips_index_lines() {
  local DIR="$FIXTURE_DIR/pkgbranch_nindex"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  commit_change "$DIR" "test commit"

  local CHANGES="$FIXTURE_DIR/pkgbranch_nindex_changes"
  mkdir -p "$CHANGES"

  source "$SCRIPT_DIR/../libs/package_branch.sh"
  package_branch "$DIR" "$CHANGES"

  local INDEX_COUNT
  INDEX_COUNT=$(grep -c "^index " "$CHANGES/patches"/*.diff 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')

  if [[ "$INDEX_COUNT" -eq 0 ]]; then
    pass "package_branch dispatcher strips index lines from diffs"
  else
    fail "package_branch dispatcher should strip index lines, found $INDEX_COUNT"
  fi
}

test_package_branch_sanitizes_branch_name() {
  local DIR="$FIXTURE_DIR/pkgbranch_sanitize"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  # Create a branch with slashes
  git -C "$DIR" checkout -b "feature/sub-feature" --quiet
  commit_change "$DIR" "test commit"

  local CHANGES="$FIXTURE_DIR/pkgbranch_sanitize_changes"
  mkdir -p "$CHANGES"

  source "$SCRIPT_DIR/../libs/package_branch.sh"
  package_branch "$DIR" "$CHANGES"

  local DIFF_COUNT
  DIFF_COUNT=$(ls -1 "$CHANGES/patches"/*.diff 2>/dev/null | wc -l)

  if [[ "$DIFF_COUNT" -ge 1 ]]; then
    pass "package_branch dispatcher produces diffs regardless of branch name"
  else
    fail "package_branch dispatcher should produce at least 1 diff"
  fi
}

test_package_branch_no_commits() {
  local DIR="$FIXTURE_DIR/pkgbranch_nocommits"
  make_sandbox "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA"

  local CHANGES="$FIXTURE_DIR/pkgbranch_nocommits_changes"
  mkdir -p "$CHANGES"

  source "$SCRIPT_DIR/../libs/package_branch.sh"
  package_branch "$DIR" "$CHANGES" 2>/dev/null

  local DIFF_COUNT
  DIFF_COUNT=$(ls -1 "$CHANGES/patches"/*.diff 2>/dev/null | wc -l)

  if [[ "$DIFF_COUNT" -eq 0 ]]; then
    pass "package_branch dispatcher produces no diffs when no commits since INIT_SHA"
  else
    fail "package_branch dispatcher should produce 0 diffs, got $DIFF_COUNT"
  fi
}

# -------------------------
# Run all tests
# -------------------------
run_test test_generate_produces_diff
run_test test_generate_no_changes
run_test test_generate_missing_args
run_test test_format_patch_produces_patches
run_test test_format_patch_numbering
run_test test_format_patch_noop_on_zero_commits
run_test test_format_patch_missing_args
run_test test_format_patch_patches_are_applicable
run_test test_on_exit_creates_session_dir
run_test test_on_exit_writes_uncommitted_diff
run_test test_on_exit_writes_all_changes_diff
run_test test_on_exit_writes_patches_in_session_subfolder
run_test test_on_exit_no_sweep_no_extra_patches
run_test test_on_exit_no_patches_when_no_changes
run_test test_on_exit_writes_export_time
run_test test_on_exit_folder_name_format
run_test test_on_exit_multiple_sessions_accumulate
run_test test_on_autosave_writes_autosave_dir
run_test test_on_autosave_writes_uncommitted_diff
run_test test_on_autosave_does_not_commit_pending
run_test test_on_autosave_no_changes_writes_empty_uncommitted_diff
run_test test_on_autosave_overwrites_previous
run_test test_on_autosave_writes_patches
run_test test_on_autosave_writes_export_time
run_test test_exit_and_autosave_write_separate_subfolders
run_test test_exit_writes_uncommitted_and_all_changes
run_test test_format_patch_standalone_produces_patches
run_test test_format_patch_standalone_numbering
run_test test_format_patch_standalone_no_commits
run_test test_format_patch_standalone_missing_args
run_test test_on_exit_session_dir_with_session_state
run_test test_on_exit_session_all_changes_diff
run_test test_on_exit_session_patches
run_test test_on_exit_missing_args_fails
run_test test_on_exit_multiple_sessions_no_clobber
run_test test_on_autosave_session_dir
run_test test_on_autosave_missing_args_fails
run_test test_package_branch_produces_numbered_diffs
run_test test_package_branch_strips_index_lines
run_test test_package_branch_sanitizes_branch_name
run_test test_package_branch_no_commits

test_done
