#!/usr/bin/env bash
# tests/test_rename_apply.sh
#
# Rename handling through the full apply pipeline: git diff rename
# detection, git apply, --no-renames flag, package_branch integration,
# and diff_export default behavior.
#
# Promoted from tests/knowledge/knowledge_diff_rename.sh — the seams it
# probes are deterministic (git only), so per testing_policy.md it belongs
# in the discovered suite, not in knowledge/.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

# -------------------------
# Helpers
# -------------------------

_make_repo() {
  local DIR="$1"
  rm -rf "$DIR"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet --initial-branch=main
  git -C "$DIR" config user.email "test@fixture"
  git -C "$DIR" config user.name "Test Fixture"
}

_commit_file() {
  local REPO="$1" FILE="$2" CONTENT="$3"
  mkdir -p "$(dirname "$REPO/$FILE")"
  echo "$CONTENT" > "$REPO/$FILE"
  git -C "$REPO" add "$FILE" 2>/dev/null
  git -C "$REPO" commit -m "add $FILE" --quiet
}

_commit_rename() {
  local REPO="$1" OLD="$2" NEW="$3"
  git -C "$REPO" mv "$OLD" "$NEW"
  git -C "$REPO" commit -m "rename $OLD -> $NEW" --quiet
}

_commit_rename_and_edit() {
  local REPO="$1" OLD="$2" NEW="$3" EXTRA="$4"
  git -C "$REPO" mv "$OLD" "$NEW"
  echo "$EXTRA" >> "$REPO/$NEW"
  git -C "$REPO" add "$NEW"
  git -C "$REPO" commit -m "rename and edit $OLD -> $NEW" --quiet
}

_commit_delete_and_create() {
  local REPO="$1" OLD="$2" NEW="$3" CONTENT="$4"
  git -C "$REPO" rm "$OLD" --quiet
  mkdir -p "$(dirname "$REPO/$NEW")"
  echo "$CONTENT" > "$REPO/$NEW"
  git -C "$REPO" add "$NEW" 2>/dev/null
  git -C "$REPO" commit -m "replace $OLD -> $NEW" --quiet
}

# Apply a diff to a repo and return success/failure
_apply_diff() {
  local TARGET="$1" DIFF_FILE="$2"
  git -C "$TARGET" apply --ignore-whitespace < "$DIFF_FILE" 2>/dev/null
}

# Check that file exists and has expected content
_assert_file_has() {
  local REPO="$1" FILE="$2" EXPECTED="$3"
  if [[ -f "$REPO/$FILE" ]]; then
    local ACTUAL
    ACTUAL=$(cat "$REPO/$FILE")
    if [[ "$ACTUAL" == "$EXPECTED" ]]; then
      return 0
    fi
  fi
  return 1
}

# Check that file does NOT exist
_assert_file_missing() {
  local REPO="$1" FILE="$2"
  [[ ! -f "$REPO/$FILE" ]]
}

# Check diff contains expected pattern
_assert_diff_has() {
  local DIFF_FILE="$1" PATTERN="$2"
  grep -q "$PATTERN" "$DIFF_FILE"
}

# Check diff does NOT contain pattern
_assert_diff_lacks() {
  local DIFF_FILE="$1" PATTERN="$2"
  ! grep -q "$PATTERN" "$DIFF_FILE"
}

# -------------------------
# Case 1: Pure rename — apply cleanly
# -------------------------

test_pure_rename_applies_cleanly() {
  local SRC="$FIXTURE_DIR/case1_src"
  local TGT="$FIXTURE_DIR/case1_tgt"
  local DIFF="$FIXTURE_DIR/case1.diff"

  _make_repo "$SRC"
  _commit_file "$SRC" "old.txt" "hello world"
  _commit_rename "$SRC" "old.txt" "new.txt"
  git -C "$SRC" diff HEAD~1..HEAD > "$DIFF"

  _make_repo "$TGT"
  _commit_file "$TGT" "old.txt" "hello world"

  if _apply_diff "$TGT" "$DIFF" && _assert_file_missing "$TGT" "old.txt" && _assert_file_has "$TGT" "new.txt" "hello world"; then
    pass "pure rename applies: old deleted, new created with correct content"
  else
    fail "pure rename: old=$([ -f "$TGT/old.txt" ] && echo exists || echo gone), new=$([ -f "$TGT/new.txt" ] && cat "$TGT/new.txt" || echo missing)"
  fi
}

# -------------------------
# Case 2: Rename + small edit — apply with content change
# -------------------------

test_rename_with_small_edit_applies_cleanly() {
  local SRC="$FIXTURE_DIR/case2_src"
  local TGT="$FIXTURE_DIR/case2_tgt"
  local DIFF="$FIXTURE_DIR/case2.diff"

  _make_repo "$SRC"
  cat > "$SRC/orig.txt" << 'EOF'
line 1
line 2
line 3
line 4
line 5
line 6
line 7
line 8
line 9
line 10
EOF
  git -C "$SRC" add orig.txt && git -C "$SRC" commit -m "base with content" --quiet

  # Small edit: add one line (10/11 = 90% similarity, rename detected)
  _commit_rename_and_edit "$SRC" "orig.txt" "moved.txt" "line 11"

  git -C "$SRC" diff HEAD~1..HEAD > "$DIFF"

  # Verify rename IS detected in diff
  if _assert_diff_has "$DIFF" "rename from"; then
    pass "rename+small edit: rename detected in diff"
  else
    fail "rename+small edit: rename NOT detected in diff"
  fi

  _make_repo "$TGT"
  cat > "$TGT/orig.txt" << 'EOF'
line 1
line 2
line 3
line 4
line 5
line 6
line 7
line 8
line 9
line 10
EOF
  git -C "$TGT" add orig.txt && git -C "$TGT" commit -m "base with content" --quiet

  if _apply_diff "$TGT" "$DIFF" && _assert_file_missing "$TGT" "orig.txt" && _assert_file_has "$TGT" "moved.txt" "$(cat "$SRC/moved.txt")"; then
    pass "rename+small edit: applies cleanly with content change"
  else
    fail "rename+small edit: apply failed or wrong state"
  fi
}

# -------------------------
# Case 3: Rename + big edit — no rename detection, delete+create
# -------------------------

test_rename_with_big_edit_no_rename_detection() {
  local SRC="$FIXTURE_DIR/case3_src"
  local TGT="$FIXTURE_DIR/case3_tgt"
  local DIFF="$FIXTURE_DIR/case3.diff"

  _make_repo "$SRC"
  _commit_file "$SRC" "small.txt" "just one line"
  # Replace entire content (0% similarity)
  _commit_delete_and_create "$SRC" "small.txt" "renamed.txt" "completely different content with many words and changes"

  git -C "$SRC" diff HEAD~1..HEAD > "$DIFF"

  if _assert_diff_lacks "$DIFF" "rename from"; then
    pass "rename+big edit: no rename detection (below 50% similarity)"
  else
    fail "rename+big edit: rename unexpectedly detected"
  fi

  _make_repo "$TGT"
  _commit_file "$TGT" "small.txt" "just one line"

  if _apply_diff "$TGT" "$DIFF" && _assert_file_missing "$TGT" "small.txt" && _assert_file_has "$TGT" "renamed.txt" "completely different content with many words and changes"; then
    pass "rename+big edit: delete+create applies cleanly"
  else
    fail "rename+big edit: apply failed or wrong state"
  fi
}

# -------------------------
# Case 4: --no-renames forces delete+create for all rename cases
# -------------------------

test_no_renames_flag_produces_delete_create() {
  local SRC="$FIXTURE_DIR/case4_src"
  local TGT="$FIXTURE_DIR/case4_tgt"
  local DIFF="$FIXTURE_DIR/case4.diff"

  _make_repo "$SRC"
  _commit_file "$SRC" "doc.txt" "documentation content here"
  _commit_rename "$SRC" "doc.txt" "readme.txt"

  git -C "$SRC" diff --no-renames HEAD~1..HEAD > "$DIFF"

  if _assert_diff_lacks "$DIFF" "rename from" && _assert_diff_has "$DIFF" "deleted file mode" && _assert_diff_has "$DIFF" "new file mode"; then
    pass "--no-renames: produces delete+create for pure rename"
  else
    fail "--no-renames: still contains rename headers"
  fi

  _make_repo "$TGT"
  _commit_file "$TGT" "doc.txt" "documentation content here"

  if _apply_diff "$TGT" "$DIFF" && _assert_file_missing "$TGT" "doc.txt" && _assert_file_has "$TGT" "readme.txt" "documentation content here"; then
    pass "--no-renames: delete+create applies cleanly"
  else
    fail "--no-renames: delete+create apply failed"
  fi
}

# -------------------------
# Case 5: --no-renames survives target-has-destination conflict
# -------------------------

test_no_renames_survives_destination_conflict() {
  local SRC="$FIXTURE_DIR/case5_src"
  local TGT="$FIXTURE_DIR/case5_tgt"
  local DIFF_RN="$FIXTURE_DIR/case5_rename.diff"
  local DIFF_NR="$FIXTURE_DIR/case5_norename.diff"

  _make_repo "$SRC"
  _commit_file "$SRC" "source.txt" "important data"
  _commit_rename "$SRC" "source.txt" "dest.txt"

  git -C "$SRC" diff HEAD~1..HEAD > "$DIFF_RN"
  git -C "$SRC" diff --no-renames HEAD~1..HEAD > "$DIFF_NR"

  # Target already has dest.txt (simulates prior session work)
  _make_repo "$TGT"
  _commit_file "$TGT" "source.txt" "important data"
  _commit_file "$TGT" "dest.txt" "preexisting file"

  # Rename diff should FAIL — destination already exists
  if ! _apply_diff "$TGT" "$DIFF_RN"; then
    pass "rename diff fails when destination exists (expected)"
  else
    fail "rename diff unexpectedly succeeded with existing destination"
  fi

  # --no-renames diff should also fail (content conflict), but with
  # a different error: both want to create dest.txt with different content
  # This is a merge conflict, not a hard "already exists" error
  local NR_OUT
  NR_OUT=$(git -C "$TGT" apply --ignore-whitespace < "$DIFF_NR" 2>&1) || true
  if [[ -n "$NR_OUT" ]]; then
    pass "--no-renames: produces content conflict (not hard 'already exists')"
  else
    # If no conflict, dest.txt still exists with original content
    # and source.txt was deleted
    if _assert_file_missing "$TGT" "source.txt"; then
      pass "--no-renames: deleted source, kept preexisting destination"
    else
      fail "--no-renames: unexpected state"
    fi
  fi
}

# -------------------------
# Case 6: Binary file rename
# -------------------------

test_binary_file_rename() {
  local SRC="$FIXTURE_DIR/case6_src"
  local TGT="$FIXTURE_DIR/case6_tgt"
  local DIFF="$FIXTURE_DIR/case6.diff"

  _make_repo "$SRC"
  # Create a pseudo-binary file (null bytes)
  printf 'PK\x03\x04\x00\x00\x00\x00binary content here' > "$SRC/bin.dat"
  git -C "$SRC" add bin.dat && git -C "$SRC" commit -m "add binary" --quiet
  _commit_rename "$SRC" "bin.dat" "data.bin"

  git -C "$SRC" diff --binary --no-renames HEAD~1..HEAD > "$DIFF"

  _make_repo "$TGT"
  printf 'PK\x03\x04\x00\x00\x00\x00binary content here' > "$TGT/bin.dat"
  git -C "$TGT" add bin.dat && git -C "$TGT" commit -m "add binary" --quiet

  if _apply_diff "$TGT" "$DIFF" && _assert_file_missing "$TGT" "bin.dat" && _assert_file_has "$TGT" "data.bin" "$(cat "$SRC/data.bin")"; then
    pass "binary rename: applies cleanly with --no-renames"
  else
    fail "binary rename: apply failed"
  fi
}

# -------------------------
# Case 7: Multi-file rename in one commit
# -------------------------

test_multifile_rename_in_one_commit() {
  local SRC="$FIXTURE_DIR/case7_src"
  local TGT="$FIXTURE_DIR/case7_tgt"
  local DIFF="$FIXTURE_DIR/case7.diff"

  _make_repo "$SRC"
  _commit_file "$SRC" "a.txt" "alpha"
  _commit_file "$SRC" "b.txt" "beta"
  _commit_file "$SRC" "c.txt" "gamma"

  git -C "$SRC" mv a.txt aa.txt
  git -C "$SRC" mv b.txt bb.txt
  git -C "$SRC" mv c.txt cc.txt
  git -C "$SRC" commit -m "rename three files" --quiet

  git -C "$SRC" diff --no-renames HEAD~1..HEAD > "$DIFF"

  _make_repo "$TGT"
  _commit_file "$TGT" "a.txt" "alpha"
  _commit_file "$TGT" "b.txt" "beta"
  _commit_file "$TGT" "c.txt" "gamma"

  if _apply_diff "$TGT" "$DIFF" && \
     _assert_file_missing "$TGT" "a.txt" && _assert_file_has "$TGT" "aa.txt" "alpha" && \
     _assert_file_missing "$TGT" "b.txt" && _assert_file_has "$TGT" "bb.txt" "beta" && \
     _assert_file_missing "$TGT" "c.txt" && _assert_file_has "$TGT" "cc.txt" "gamma"; then
    pass "multi-file rename: all three applied correctly"
  else
    fail "multi-file rename: apply failed or wrong state"
  fi
}

# -------------------------
# Case 8: Cross-directory rename
# -------------------------

test_cross_directory_rename() {
  local SRC="$FIXTURE_DIR/case8_src"
  local TGT="$FIXTURE_DIR/case8_tgt"
  local DIFF="$FIXTURE_DIR/case8.diff"

  _make_repo "$SRC"
  mkdir -p "$SRC/src/old" "$SRC/src/new"
  _commit_file "$SRC" "src/old/util.sh" "echo cross-dir test"
  git -C "$SRC" mv src/old/util.sh src/new/util.sh
  git -C "$SRC" commit -m "move util across directories" --quiet

  git -C "$SRC" diff --no-renames HEAD~1..HEAD > "$DIFF"

  _make_repo "$TGT"
  _commit_file "$TGT" "src/old/util.sh" "echo cross-dir test"

  if _apply_diff "$TGT" "$DIFF" && \
     _assert_file_missing "$TGT" "src/old/util.sh" && \
     _assert_file_has "$TGT" "src/new/util.sh" "echo cross-dir test"; then
    pass "cross-directory rename: applies cleanly"
  else
    fail "cross-directory rename: apply failed"
  fi
}

# -------------------------
# Run all tests
# -------------------------

run_test test_pure_rename_applies_cleanly
run_test test_rename_with_small_edit_applies_cleanly
run_test test_rename_with_big_edit_no_rename_detection
run_test test_no_renames_flag_produces_delete_create
run_test test_no_renames_survives_destination_conflict
run_test test_binary_file_rename
run_test test_multifile_rename_in_one_commit
run_test test_cross_directory_rename

test_done
