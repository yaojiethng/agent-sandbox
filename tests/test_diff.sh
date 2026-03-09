#!/usr/bin/env bash
# tests/test_diff.sh
# Tests for lib/diff.sh
#
# Each test function creates its own fixture under /tmp.
# Tests are independent — no shared state between them.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/diff.sh"

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
      pass "commit_pending commits dirty working tree"
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
# diff_on_exit
# -------------------------
test_on_exit_commits_and_writes_staged_diff() {
  local DIR="$FIXTURE_DIR/exit_diff"
  local CHANGES="$FIXTURE_DIR/exit_diff_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  # Leave an uncommitted change — diff_on_exit must commit it first
  echo "agent work" > "$DIR/result.txt"

  diff_on_exit "$DIR" "$SHA" "$CHANGES"

  if [[ -f "$CHANGES/staged.diff" && -s "$CHANGES/staged.diff" ]]; then
    pass "diff_on_exit writes staged.diff with uncommitted changes"
  else
    fail "diff_on_exit should write non-empty staged.diff"
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
    pass "diff_on_exit writes no staged.diff when no changes"
  else
    fail "diff_on_exit should not write staged.diff when no changes"
  fi
}

# -------------------------
# diff_on_autosave
# -------------------------
test_on_autosave_writes_autosave_diff() {
  local DIR="$FIXTURE_DIR/autosave_diff"
  local CHANGES="$FIXTURE_DIR/autosave_diff_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  # Commit a change so there is something to diff
  echo "in-progress" > "$DIR/wip.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "wip" --quiet

  diff_on_autosave "$DIR" "$SHA" "$CHANGES"

  if [[ -f "$CHANGES/autosave.diff" && -s "$CHANGES/autosave.diff" ]]; then
    pass "diff_on_autosave writes autosave.diff"
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

  # Leave uncommitted change — autosave must NOT commit it
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
# exit and autosave write to separate files
# -------------------------
test_exit_and_autosave_write_separate_files() {
  local DIR="$FIXTURE_DIR/separate_files"
  local CHANGES="$FIXTURE_DIR/separate_files_out"
  mkdir -p "$CHANGES"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")

  echo "work" > "$DIR/work.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "work" --quiet

  diff_on_autosave "$DIR" "$SHA" "$CHANGES"
  diff_on_exit "$DIR" "$SHA" "$CHANGES"

  if [[ -f "$CHANGES/autosave.diff" && -f "$CHANGES/staged.diff" ]]; then
    pass "diff_on_exit and diff_on_autosave write separate files"
  else
    fail "staged.diff and autosave.diff should both exist"
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
run_test test_on_exit_commits_and_writes_staged_diff
run_test test_on_exit_no_changes
run_test test_on_autosave_writes_autosave_diff
run_test test_on_autosave_does_not_commit_pending
run_test test_on_autosave_no_changes
run_test test_exit_and_autosave_write_separate_files

echo ""
echo "Results: $PASS passed, $FAIL failed"
