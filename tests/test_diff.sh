#!/usr/bin/env bash
# tests/test_diff.sh
# Tests for libs/diff.sh
#
# Covers:
#   diff_commit_pending   — commit dirty/clean/staged/missing-arg
#   diff_generate         — produces diff, no-op on clean, missing args
#   diff_format_patch     — produces per-commit patches, no-op on zero commits, missing args
#   diff_on_exit          — without SESSION_NAME (fallback) and with SESSION_NAME (session dir)
#   diff_on_autosave      — without SESSION_NAME and with SESSION_NAME; does not commit
#
# Each test creates its own fixture under a temp dir. Tests are independent.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/diff.sh"

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
# diff_commit_pending
# -------------------------
test_commit_pending_clean_tree() {
  local DIR="$FIXTURE_DIR/commit_clean"
  make_sandbox "$DIR"

  if diff_commit_pending "$DIR"; then
    pass "commit_pending is no-op on clean tree"
  else
    fail "commit_pending should succeed on clean tree"
  fi
}

test_commit_pending_dirty_working_tree() {
  local DIR="$FIXTURE_DIR/commit_dirty"
  make_sandbox "$DIR"

  echo "change" > "$DIR/file.txt"

  if diff_commit_pending "$DIR"; then
    local MSG
    MSG=$(git -C "$DIR" log -1 --pretty=%s)
    if [[ "$MSG" == "agent-sandbox: uncommitted changes on exit" ]]; then
      pass "commit_pending commits dirty working tree with correct message"
    else
      fail "commit_pending committed but with wrong message: $MSG"
    fi
  else
    fail "commit_pending should succeed on dirty working tree"
  fi
}

test_commit_pending_staged_changes() {
  local DIR="$FIXTURE_DIR/commit_staged"
  make_sandbox "$DIR"

  echo "staged" > "$DIR/new.txt"
  git -C "$DIR" add new.txt

  if diff_commit_pending "$DIR"; then
    local COUNT
    COUNT=$(git -C "$DIR" show --stat HEAD | grep -c "new.txt")
    if [[ "$COUNT" -gt 0 ]]; then
      pass "commit_pending commits staged changes"
    else
      fail "commit_pending committed but staged file not included"
    fi
  else
    fail "commit_pending should succeed with staged changes"
  fi
}

test_commit_pending_missing_arg() {
  if diff_commit_pending 2>/dev/null; then
    fail "commit_pending should fail with missing SANDBOX_DIR"
  else
    pass "commit_pending fails with missing SANDBOX_DIR"
  fi
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
# diff_on_exit — no SESSION_NAME (fallback to CHANGES_DIR root)
# -------------------------
test_on_exit_commits_and_writes_staged_diff() {
  local DIR="$FIXTURE_DIR/exit_diff"
  local CHANGES="$FIXTURE_DIR/exit_diff_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "agent work" > "$DIR/result.txt"

  diff_on_exit "$DIR" "$SHA" "$CHANGES"

  if [[ -f "$CHANGES/staged.diff" && -s "$CHANGES/staged.diff" ]]; then
    pass "diff_on_exit (no session) writes staged.diff at CHANGES_DIR root"
  else
    fail "diff_on_exit should write non-empty staged.diff at root"
  fi
}

test_on_exit_no_changes() {
  local DIR="$FIXTURE_DIR/exit_nochange"
  local CHANGES="$FIXTURE_DIR/exit_nochange_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  diff_on_exit "$DIR" "$SHA" "$CHANGES"

  if [[ ! -f "$CHANGES/staged.diff" ]]; then
    pass "diff_on_exit (no session) writes no staged.diff when no changes"
  else
    fail "diff_on_exit should not write staged.diff when no changes"
  fi
}

# -------------------------
# diff_on_exit — with SESSION_NAME (session-scoped directory)
# -------------------------
test_on_exit_session_creates_session_dir() {
  local DIR="$FIXTURE_DIR/exit_session_dir"
  local CHANGES="$FIXTURE_DIR/exit_session_dir_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  commit_change "$DIR" "agent commit"

  diff_on_exit "$DIR" "$SHA" "$CHANGES" "main-20260408-120000"

  if [[ -d "$CHANGES/main-20260408-120000" ]]; then
    pass "diff_on_exit with SESSION_NAME creates session-scoped directory"
  else
    fail "diff_on_exit should create CHANGES_DIR/SESSION_NAME/"
  fi
}

test_on_exit_session_writes_staged_diff_in_session_dir() {
  local DIR="$FIXTURE_DIR/exit_session_diff"
  local CHANGES="$FIXTURE_DIR/exit_session_diff_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "agent work" > "$DIR/result.txt"

  diff_on_exit "$DIR" "$SHA" "$CHANGES" "main-20260408-120001"

  if [[ -f "$CHANGES/main-20260408-120001/staged.diff" && -s "$CHANGES/main-20260408-120001/staged.diff" ]]; then
    pass "diff_on_exit with SESSION_NAME writes staged.diff inside session dir"
  else
    fail "diff_on_exit should write staged.diff under CHANGES_DIR/SESSION_NAME/"
  fi
}

test_on_exit_session_writes_patches_in_session_dir() {
  local DIR="$FIXTURE_DIR/exit_session_patches"
  local CHANGES="$FIXTURE_DIR/exit_session_patches_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  commit_change "$DIR" "first commit"
  commit_change "$DIR" "second commit"

  diff_on_exit "$DIR" "$SHA" "$CHANGES" "feat-20260408-120002"

  local COUNT
  COUNT=$(find "$CHANGES/feat-20260408-120002/patches" -name '*.patch' 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "diff_on_exit with SESSION_NAME writes patches/ inside session dir ($COUNT patches)"
  else
    fail "diff_on_exit should write 2 patches in session patches dir, got $COUNT"
  fi
}

test_on_exit_session_sweep_commit_produces_one_patch() {
  local DIR="$FIXTURE_DIR/exit_sweep"
  local CHANGES="$FIXTURE_DIR/exit_sweep_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  # Uncommitted change — diff_on_exit sweeps it into one commit
  echo "agent work" > "$DIR/result.txt"

  diff_on_exit "$DIR" "$SHA" "$CHANGES" "main-20260408-120003"

  local COUNT
  COUNT=$(find "$CHANGES/main-20260408-120003/patches" -name '*.patch' 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 1 ]]; then
    pass "diff_on_exit sweep commit produces exactly one patch file"
  else
    fail "diff_on_exit sweep should produce 1 patch, got $COUNT"
  fi
}

test_on_exit_session_no_patches_when_no_changes() {
  local DIR="$FIXTURE_DIR/exit_session_nochange"
  local CHANGES="$FIXTURE_DIR/exit_session_nochange_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  diff_on_exit "$DIR" "$SHA" "$CHANGES" "main-20260408-120004"

  local COUNT
  COUNT=$(find "$CHANGES/main-20260408-120004/patches" -name '*.patch' 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 0 ]]; then
    pass "diff_on_exit with no changes produces no patch files"
  else
    fail "diff_on_exit with no changes should produce 0 patches, got $COUNT"
  fi
}

test_on_exit_session_does_not_write_to_changes_root() {
  local DIR="$FIXTURE_DIR/exit_no_root_leak"
  local CHANGES="$FIXTURE_DIR/exit_no_root_leak_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "work" > "$DIR/work.txt"

  diff_on_exit "$DIR" "$SHA" "$CHANGES" "main-20260408-120005"

  if [[ ! -f "$CHANGES/staged.diff" ]]; then
    pass "diff_on_exit with SESSION_NAME does not write staged.diff at CHANGES_DIR root"
  else
    fail "diff_on_exit with SESSION_NAME must not write staged.diff at root level"
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
  echo "session 1 work" > "$DIR1/s1.txt"
  diff_on_exit "$DIR1" "$SHA1" "$CHANGES" "main-20260408-100000"

  make_sandbox "$DIR2"
  local SHA2
  SHA2=$(get_sha "$DIR2")
  echo "session 2 work" > "$DIR2/s2.txt"
  diff_on_exit "$DIR2" "$SHA2" "$CHANGES" "main-20260408-110000"

  local COUNT
  COUNT=$(find "$CHANGES" -mindepth 1 -maxdepth 1 -type d | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "multiple sessions accumulate as separate directories under CHANGES_DIR"
  else
    fail "expected 2 session dirs, got $COUNT"
  fi
}

# -------------------------
# diff_on_autosave — no SESSION_NAME
# -------------------------
test_on_autosave_writes_autosave_diff() {
  local DIR="$FIXTURE_DIR/autosave_diff"
  local CHANGES="$FIXTURE_DIR/autosave_diff_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  commit_change "$DIR" "wip"

  diff_on_autosave "$DIR" "$SHA" "$CHANGES"

  if [[ -f "$CHANGES/autosave.diff" && -s "$CHANGES/autosave.diff" ]]; then
    pass "diff_on_autosave (no session) writes autosave.diff at CHANGES_DIR root"
  else
    fail "diff_on_autosave should write non-empty autosave.diff"
  fi
}

test_on_autosave_does_not_commit_pending() {
  local DIR="$FIXTURE_DIR/autosave_nocommit"
  local CHANGES="$FIXTURE_DIR/autosave_nocommit_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "uncommitted" > "$DIR/pending.txt"
  local BEFORE
  BEFORE=$(get_sha "$DIR")

  diff_on_autosave "$DIR" "$SHA" "$CHANGES"

  local AFTER
  AFTER=$(get_sha "$DIR")

  if [[ "$BEFORE" == "$AFTER" ]]; then
    pass "diff_on_autosave does not commit pending changes"
  else
    fail "diff_on_autosave must not commit pending changes"
  fi
}

test_on_autosave_no_changes() {
  local DIR="$FIXTURE_DIR/autosave_nochange"
  local CHANGES="$FIXTURE_DIR/autosave_nochange_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  diff_on_autosave "$DIR" "$SHA" "$CHANGES"

  if [[ ! -f "$CHANGES/autosave.diff" ]]; then
    pass "diff_on_autosave writes no file when no changes"
  else
    fail "diff_on_autosave should not write autosave.diff when no changes"
  fi
}

# -------------------------
# diff_on_autosave — with SESSION_NAME
# -------------------------
test_on_autosave_session_writes_in_session_dir() {
  local DIR="$FIXTURE_DIR/autosave_session"
  local CHANGES="$FIXTURE_DIR/autosave_session_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  commit_change "$DIR" "wip"

  diff_on_autosave "$DIR" "$SHA" "$CHANGES" "main-20260408-130000"

  if [[ -f "$CHANGES/main-20260408-130000/autosave.diff" && -s "$CHANGES/main-20260408-130000/autosave.diff" ]]; then
    pass "diff_on_autosave with SESSION_NAME writes autosave.diff inside session dir"
  else
    fail "diff_on_autosave should write autosave.diff under CHANGES_DIR/SESSION_NAME/"
  fi
}

test_on_autosave_session_does_not_write_to_changes_root() {
  local DIR="$FIXTURE_DIR/autosave_no_root_leak"
  local CHANGES="$FIXTURE_DIR/autosave_no_root_leak_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  commit_change "$DIR" "wip"

  diff_on_autosave "$DIR" "$SHA" "$CHANGES" "main-20260408-130001"

  if [[ ! -f "$CHANGES/autosave.diff" ]]; then
    pass "diff_on_autosave with SESSION_NAME does not write autosave.diff at root"
  else
    fail "diff_on_autosave with SESSION_NAME must not write autosave.diff at root"
  fi
}

# -------------------------
# exit and autosave write to separate files
# -------------------------
test_exit_and_autosave_write_separate_files() {
  local DIR="$FIXTURE_DIR/separate_files"
  local CHANGES="$FIXTURE_DIR/separate_files_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  commit_change "$DIR" "work"

  diff_on_autosave "$DIR" "$SHA" "$CHANGES"
  diff_on_exit "$DIR" "$SHA" "$CHANGES"

  if [[ -f "$CHANGES/autosave.diff" && -f "$CHANGES/staged.diff" ]]; then
    pass "diff_on_exit and diff_on_autosave write separate files (no session)"
  else
    fail "staged.diff and autosave.diff should both exist"
  fi
}

test_exit_and_autosave_write_separate_files_in_session_dir() {
  local DIR="$FIXTURE_DIR/separate_session"
  local CHANGES="$FIXTURE_DIR/separate_session_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  commit_change "$DIR" "work"

  diff_on_autosave "$DIR" "$SHA" "$CHANGES" "main-20260408-140000"
  diff_on_exit     "$DIR" "$SHA" "$CHANGES" "main-20260408-140000"

  local SESSION_DIR="$CHANGES/main-20260408-140000"
  if [[ -f "$SESSION_DIR/autosave.diff" && -f "$SESSION_DIR/staged.diff" ]]; then
    pass "diff_on_exit and diff_on_autosave write separate files inside session dir"
  else
    fail "staged.diff and autosave.diff should both exist inside session dir"
  fi
}

# -------------------------
# diff_format_patch
# -------------------------
test_format_patch_produces_patches() {
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

test_format_patch_numbering() {
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

test_format_patch_no_commits() {
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

test_format_patch_missing_args() {
  if diff_format_patch 2>/dev/null; then
    fail "diff_format_patch should fail with missing args"
  else
    pass "diff_format_patch fails with missing args"
  fi
}

# -------------------------
# Session-scoped artefacts (diff_on_exit with SESSION_NAME)
# -------------------------
test_on_exit_session_dir_created() {
  local DIR="$FIXTURE_DIR/exit_sess_dir"
  local CHANGES="$FIXTURE_DIR/exit_sess_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  diff_on_exit "$DIR" "$SHA" "$CHANGES" "main-20260417-120000"

  if [[ -d "$CHANGES/main-20260417-120000" ]]; then
    pass "diff_on_exit creates session directory"
  else
    fail "diff_on_exit should create session directory"
  fi
}

test_on_exit_session_staged_diff() {
  local DIR="$FIXTURE_DIR/exit_sess_staged"
  local CHANGES="$FIXTURE_DIR/exit_sess_staged_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  diff_on_exit "$DIR" "$SHA" "$CHANGES" "main-20260417-120000"

  if [[ -f "$CHANGES/main-20260417-120000/staged.diff" ]]; then
    pass "diff_on_exit writes staged.diff inside session directory"
  else
    fail "diff_on_exit should write staged.diff inside session directory"
  fi
}

test_on_exit_session_patches() {
  local DIR="$FIXTURE_DIR/exit_sess_patches"
  local CHANGES="$FIXTURE_DIR/exit_sess_patches_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  diff_on_exit "$DIR" "$SHA" "$CHANGES" "main-20260417-120000"

  if [[ -d "$CHANGES/main-20260417-120000/patches" ]] && \
     ls "$CHANGES/main-20260417-120000/patches/"*.patch >/dev/null 2>&1; then
    pass "diff_on_exit creates patches/ with .patch files"
  else
    fail "diff_on_exit should create patches/ directory with patch files"
  fi
}

test_on_exit_no_session_fallback() {
  local DIR="$FIXTURE_DIR/exit_no_sess"
  local CHANGES="$FIXTURE_DIR/exit_no_sess_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  # Empty SESSION_NAME — should fall back to root CHANGES_DIR
  diff_on_exit "$DIR" "$SHA" "$CHANGES" ""

  if [[ -f "$CHANGES/staged.diff" ]]; then
    pass "diff_on_exit falls back to root CHANGES_DIR with empty SESSION_NAME"
  else
    fail "diff_on_exit should fall back to root CHANGES_DIR"
  fi
}

test_on_exit_multiple_sessions_no_clobber() {
  local DIR="$FIXTURE_DIR/exit_multi"
  local CHANGES="$FIXTURE_DIR/exit_multi_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  # First session
  echo "work1" > "$DIR/file1.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work1" --quiet
  diff_on_exit "$DIR" "$SHA" "$CHANGES" "main-20260417-110000"

  # Second session (different session name)
  echo "work2" > "$DIR/file2.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work2" --quiet
  diff_on_exit "$DIR" "$SHA" "$CHANGES" "main-20260417-120000"

  if [[ -d "$CHANGES/main-20260417-110000" ]] && \
     [[ -d "$CHANGES/main-20260417-120000" ]] && \
     [[ -f "$CHANGES/main-20260417-110000/staged.diff" ]] && \
     [[ -f "$CHANGES/main-20260417-120000/staged.diff" ]]; then
    pass "diff_on_exit accumulates multiple sessions without clobbering"
  else
    fail "diff_on_exit should preserve both session directories"
  fi
}

# -------------------------
# Session-scoped artefacts (diff_on_autosave with SESSION_NAME)
# -------------------------
test_on_autosave_session_dir() {
  local DIR="$FIXTURE_DIR/autosave_sess"
  local CHANGES="$FIXTURE_DIR/autosave_sess_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  diff_on_autosave "$DIR" "$SHA" "$CHANGES" "main-20260417-120000"

  if [[ -f "$CHANGES/main-20260417-120000/autosave.diff" ]]; then
    pass "diff_on_autosave writes autosave.diff inside session directory"
  else
    fail "diff_on_autosave should write autosave.diff inside session directory"
  fi
}

test_on_autosave_no_session_fallback() {
  local DIR="$FIXTURE_DIR/autosave_no_sess"
  local CHANGES="$FIXTURE_DIR/autosave_no_sess_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "work" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  # Empty SESSION_NAME — should fall back to root CHANGES_DIR
  diff_on_autosave "$DIR" "$SHA" "$CHANGES" ""

  if [[ -f "$CHANGES/autosave.diff" ]]; then
    pass "diff_on_autosave falls back to root CHANGES_DIR with empty SESSION_NAME"
  else
    fail "diff_on_autosave should fall back to root CHANGES_DIR"
  fi
}

# -------------------------
# Run all tests
# -------------------------
run_test test_commit_pending_clean_tree
run_test test_commit_pending_dirty_working_tree
run_test test_commit_pending_staged_changes
run_test test_commit_pending_missing_arg
run_test test_generate_produces_diff
run_test test_generate_no_changes
run_test test_generate_missing_args
run_test test_format_patch_produces_patches
run_test test_format_patch_numbering
run_test test_format_patch_noop_on_zero_commits
run_test test_format_patch_missing_args
run_test test_format_patch_patches_are_applicable
run_test test_on_exit_commits_and_writes_staged_diff
run_test test_on_exit_no_changes
run_test test_on_exit_session_creates_session_dir
run_test test_on_exit_session_writes_staged_diff_in_session_dir
run_test test_on_exit_session_writes_patches_in_session_dir
run_test test_on_exit_session_sweep_commit_produces_one_patch
run_test test_on_exit_session_no_patches_when_no_changes
run_test test_on_exit_session_does_not_write_to_changes_root
run_test test_on_exit_multiple_sessions_accumulate
run_test test_on_autosave_writes_autosave_diff
run_test test_on_autosave_does_not_commit_pending
run_test test_on_autosave_no_changes
run_test test_on_autosave_session_writes_in_session_dir
run_test test_on_autosave_session_does_not_write_to_changes_root
run_test test_exit_and_autosave_write_separate_files
run_test test_format_patch_produces_patches
run_test test_format_patch_numbering
run_test test_format_patch_no_commits
run_test test_format_patch_missing_args
run_test test_on_exit_session_dir_created
run_test test_on_exit_session_staged_diff
run_test test_on_exit_session_patches
run_test test_on_exit_no_session_fallback
run_test test_on_exit_multiple_sessions_no_clobber
run_test test_on_autosave_session_dir
run_test test_on_autosave_no_session_fallback
run_test test_exit_and_autosave_write_separate_files_in_session_dir

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
