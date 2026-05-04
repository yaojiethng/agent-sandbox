#!/usr/bin/env bash
# Tests for libs/package_branch.sh — dispatcher produces unified output format
#
# Expected output layout (under OUTPUT_DIR/):
#   patches/0001-<sha>.diff
#   patches/0002-<sha>.diff
#   ...
#   uncommitted.diff
#   all-changes.diff
#   changed-files/MANIFEST.txt
#   changed-files/<path>/<file>

set -uo pipefail

FIXTURE_DIR=$(mktemp -d)
trap 'rm -rf "$FIXTURE_DIR"' EXIT

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/git_fixtures.sh"

plan 18

# -------------------------------------------------------------------
# Helper: create a clean sandbox with a commit, write SESSION_STATE
# -------------------------------------------------------------------
make_sandbox_with_state() {
  local DIR="$1"
  make_sandbox "$DIR"
  local SHA
  SHA=$(get_sha "$DIR")
  write_session_state "$DIR" "$SHA"
  echo "$SHA"
}

# -------------------------------------------------------------------
# Helper: create one or more commits in the sandbox
# -------------------------------------------------------------------
commit_file() {
  local DIR="$1"
  local FILE="$2"
  local CONTENT="${3:-file content}"
  mkdir -p "$(dirname "$DIR/$FILE")"
  echo "$CONTENT" > "$DIR/$FILE"
  git -C "$DIR" add "$FILE"
  git -C "$DIR" commit -m "add $FILE" --quiet
}

# ===================================================================
# package_branch produces the unified output layout
# ===================================================================

test_dispatcher_creates_patches_dir() {
  local DIR="$FIXTURE_DIR/pb_patches"
  local OUT="$FIXTURE_DIR/pb_patches_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"

  package_branch "$DIR" "$OUT"

  if [[ -d "$OUT/patches" ]] && ls "$OUT/patches/"*.diff >/dev/null 2>&1; then
    pass "package_branch creates patches/ with diff files"
  else
    fail "package_branch should create patches/ with .diff files"
  fi
}

test_dispatcher_creates_uncommitted_diff() {
  local DIR="$FIXTURE_DIR/pb_uncommitted"
  local OUT="$FIXTURE_DIR/pb_uncommitted_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"

  echo "unstaged work" > "$DIR/new.txt"
  git -C "$DIR" add -N new.txt 2>/dev/null || true

  package_branch "$DIR" "$OUT"

  if [[ -f "$OUT/uncommitted.diff" ]]; then
    pass "package_branch creates uncommitted.diff"
  else
    fail "package_branch should create uncommitted.diff"
  fi
}

test_dispatcher_creates_all_changes_diff() {
  local DIR="$FIXTURE_DIR/pb_allchanges"
  local OUT="$FIXTURE_DIR/pb_allchanges_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"

  package_branch "$DIR" "$OUT"

  if [[ -f "$OUT/all-changes.diff" ]]; then
    pass "package_branch creates all-changes.diff"
  else
    fail "package_branch should create all-changes.diff"
  fi
}

test_dispatcher_creates_changed_files() {
  local DIR="$FIXTURE_DIR/pb_changedfiles"
  local OUT="$FIXTURE_DIR/pb_changedfiles_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"

  package_branch "$DIR" "$OUT"

  if [[ -d "$OUT/changed-files" ]] && [[ -f "$OUT/changed-files/a.txt" ]]; then
    pass "package_branch creates changed-files/ with file copies"
  else
    fail "package_branch should create changed-files/ with copied files"
  fi
}

test_dispatcher_writes_manifest() {
  local DIR="$FIXTURE_DIR/pb_manifest"
  local OUT="$FIXTURE_DIR/pb_manifest_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"

  package_branch "$DIR" "$OUT"

  if [[ -f "$OUT/changed-files/MANIFEST.txt" ]] && [[ -s "$OUT/changed-files/MANIFEST.txt" ]]; then
    pass "package_branch writes MANIFEST.txt in changed-files/"
  else
    fail "package_branch should write non-empty MANIFEST.txt"
  fi
}

test_dispatcher_produces_numbered_diffs() {
  local DIR="$FIXTURE_DIR/pb_numbered"
  local OUT="$FIXTURE_DIR/pb_numbered_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"
  commit_file "$DIR" "b.txt"

  package_branch "$DIR" "$OUT"

  local COUNT
  COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "package_branch produces 2 numbered diffs for 2 commits (got $COUNT)"
  else
    fail "package_branch should produce 2 diffs for 2 commits, got $COUNT"
  fi
}

test_dispatcher_prefix_numbering() {
  local DIR="$FIXTURE_DIR/pb_prefix"
  local OUT="$FIXTURE_DIR/pb_prefix_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"
  commit_file "$DIR" "b.txt"
  commit_file "$DIR" "c.txt"

  package_branch "$DIR" "$OUT"

  if ls "$OUT/patches/0001-"*.diff >/dev/null 2>&1 && \
     ls "$OUT/patches/0002-"*.diff >/dev/null 2>&1 && \
     ls "$OUT/patches/0003-"*.diff >/dev/null 2>&1; then
    pass "package_branch uses 0001-, 0002-, 0003- prefix"
  else
    fail "package_branch should use 0001-, 0002-, 0003- prefix for 3 commits"
  fi
}

test_dispatcher_overwrites_output() {
  local DIR="$FIXTURE_DIR/pb_overwrite"
  local OUT="$FIXTURE_DIR/pb_overwrite_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"

  package_branch "$DIR" "$OUT"

  local FIRST_COUNT
  FIRST_COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)

  commit_file "$DIR" "b.txt"
  package_branch "$DIR" "$OUT"

  local SECOND_COUNT
  SECOND_COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)

  if [[ "$SECOND_COUNT" -eq 2 ]] && [[ "$FIRST_COUNT" -eq 1 ]]; then
    pass "package_branch overwrites: 1 diff first run, 2 diffs second run"
  else
    fail "package_branch should overwrite output, got $FIRST_COUNT then $SECOND_COUNT"
  fi
}

test_dispatcher_diff_is_applicable() {
  local DIR="$FIXTURE_DIR/pb_apply"
  local OUT="$FIXTURE_DIR/pb_apply_out"
  local TARGET="$FIXTURE_DIR/pb_apply_target"
  mkdir -p "$OUT" "$TARGET"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt" "hello world"

  package_branch "$DIR" "$OUT"

  # Init target repo and apply the patch
  git -C "$TARGET" init --quiet
  git -C "$TARGET" config user.email "t@t"
  git -C "$TARGET" config user.name "t"
  git -C "$TARGET" commit --allow-empty -m "base" --quiet
  echo "hello world" > "$TARGET/a.txt"

  if git -C "$TARGET" apply < <(grep -v '^index ' "$OUT/patches/0001-"*.diff) 2>/dev/null; then
    pass "diff produced by package_branch applies via git apply"
  else
    fail "diff produced by package_branch does not apply via git apply"
  fi
}

test_dispatcher_diff_contains_content() {
  local DIR="$FIXTURE_DIR/pb_content"
  local OUT="$FIXTURE_DIR/pb_content_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt" "unique-content"

  package_branch "$DIR" "$OUT"

  if grep -q "unique-content" "$OUT/patches/"*.diff 2>/dev/null; then
    pass "diff contains expected file content"
  else
    fail "diff should contain expected file content"
  fi
}

test_dispatcher_strips_index_lines() {
  local DIR="$FIXTURE_DIR/pb_index"
  local OUT="$FIXTURE_DIR/pb_index_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"

  package_branch "$DIR" "$OUT"

  local HAS_INDEX
  HAS_INDEX=$(grep -c '^index ' "$OUT/patches/"*.diff 2>/dev/null || echo 0)
  if [[ "$HAS_INDEX" -eq 0 ]]; then
    pass "package_branch strips index lines from text diffs"
  else
    fail "package_branch should strip index lines from text diffs, found $HAS_INDEX"
  fi
}

test_dispatcher_includes_untracked_in_changed_files() {
  local DIR="$FIXTURE_DIR/pb_untracked"
  local OUT="$FIXTURE_DIR/pb_untracked_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  echo "untracked content" > "$DIR/untracked.txt"

  package_branch "$DIR" "$OUT"

  if [[ -f "$OUT/changed-files/untracked.txt" ]]; then
    pass "package_branch includes untracked file in changed-files/"
  else
    fail "package_branch should include untracked file in changed-files/"
  fi
}

test_dispatcher_single_commit() {
  local DIR="$FIXTURE_DIR/pb_single"
  local OUT="$FIXTURE_DIR/pb_single_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"

  package_branch "$DIR" "$OUT"

  local COUNT
  COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 1 ]]; then
    pass "package_branch produces 1 diff for single commit"
  else
    fail "package_branch should produce 1 diff for single commit, got $COUNT"
  fi
}

test_dispatcher_two_commits() {
  local DIR="$FIXTURE_DIR/pb_two"
  local OUT="$FIXTURE_DIR/pb_two_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"
  commit_file "$DIR" "b.txt"

  package_branch "$DIR" "$OUT"

  local COUNT
  COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)
  if [[ "$COUNT" -eq 2 ]]; then
    pass "package_branch produces 2 diffs for 2 commits"
  else
    fail "package_branch should produce 2 diffs for 2 commits, got $COUNT"
  fi
}

test_dispatcher_no_commits() {
  local DIR="$FIXTURE_DIR/pb_none"
  local OUT="$FIXTURE_DIR/pb_none_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"

  package_branch "$DIR" "$OUT"

  local PATCH_COUNT
  PATCH_COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)
  if [[ "$PATCH_COUNT" -eq 0 ]]; then
    pass "package_branch produces no diffs when no commits"
  else
    fail "package_branch should produce 0 diffs when no commits, got $PATCH_COUNT"
  fi
}

test_dispatcher_missing_args() {
  if package_branch "" "" 2>/dev/null; then
    fail "package_branch should fail with missing args"
  else
    pass "package_branch fails with missing args"
  fi
}
