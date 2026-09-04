#!/usr/bin/env bash
# tests/test_diff_rename.sh  --  Unit tests for rename handling through our
# package_branch / diff_export pipeline.
#
# These assertions were previously housed in a manual knowledge test
# (knowledge_diff_rename.sh) where they were not run by `make test`. They probe
# our maintained internal seams (package_branch, diff_export) and belong in the
# unit suite. The git-external rename behaviour remains in the knowledge test.
#
# Run:
#   bash tests/test_diff_rename.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/session_state.sh"
source "$REPO_ROOT/src/libs/routing.sh"
source "$REPO_ROOT/src/libs/export_status.sh"
source "$REPO_ROOT/src/libs/package_branch.sh"
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/diff_export.sh"

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

_assert_diff_has() {
  local DIFF_FILE="$1" PATTERN="$2"
  grep -q "$PATTERN" "$DIFF_FILE"
}

_assert_diff_lacks() {
  local DIFF_FILE="$1" PATTERN="$2"
  ! grep -q "$PATTERN" "$DIFF_FILE"
}

test_package_branch_no_renames_true() {
  local REPO="$FIXTURE_DIR/rb_true_repo"
  local OUT="$FIXTURE_DIR/rb_true_out"
  make_repo "$REPO"
  _commit_file "$REPO" "config.yaml" "key: value"
  write_session_state "$REPO"
  _commit_rename "$REPO" "config.yaml" "settings.yaml"

  rm -rf "$OUT"; mkdir -p "$OUT"
  package_branch "$REPO" "$OUT" "true" >/dev/null 2>&1
  local PATCH; PATCH=$(ls "$OUT/patches/"*.diff 2>/dev/null | head -1)
  if [[ -z "$PATCH" ]]; then
    fail "package_branch NO_RENAMES=true: no patch generated"; return
  fi
  if _assert_diff_lacks "$PATCH" "rename from" \
     && _assert_diff_has "$PATCH" "deleted file mode" \
     && _assert_diff_has "$PATCH" "new file mode"; then
    pass "package_branch NO_RENAMES=true produces delete+create, not rename"
  else
    fail "package_branch NO_RENAMES=true produced rename or unexpected format"
  fi
}

test_package_branch_default_detects_rename() {
  local REPO="$FIXTURE_DIR/rb_default_repo"
  local OUT="$FIXTURE_DIR/rb_default_out"
  make_repo "$REPO"
  _commit_file "$REPO" "README.md" "# Project"
  write_session_state "$REPO"
  _commit_rename "$REPO" "README.md" "README.txt"

  rm -rf "$OUT"; mkdir -p "$OUT"
  package_branch "$REPO" "$OUT" "" >/dev/null 2>&1
  local PATCH; PATCH=$(ls "$OUT/patches/"*.diff 2>/dev/null | head -1)
  if [[ -z "$PATCH" ]]; then
    fail "package_branch default: no patch generated"; return
  fi
  if _assert_diff_has "$PATCH" "rename from"; then
    pass "package_branch default detects rename"
  else
    fail "package_branch default did not detect rename"
  fi
}

test_diff_export_uses_no_renames_by_default() {
  local REPO="$FIXTURE_DIR/de_nr_repo"
  local OUT="$FIXTURE_DIR/de_nr_out"
  make_repo "$REPO"
  _commit_file "$REPO" "file.txt" "content"
  write_session_state "$REPO"
  _commit_rename "$REPO" "file.txt" "renamed.txt"

  rm -rf "$OUT"; mkdir -p "$OUT"
  diff_export "$REPO" "$OUT" "" >/dev/null
  local PATCH; PATCH=$(ls "$OUT/patches/"*.diff 2>/dev/null | head -1)
  if [[ -z "$PATCH" ]]; then
    fail "diff_export: no patch generated"; return
  fi
  if _assert_diff_lacks "$PATCH" "rename from"; then
    pass "diff_export uses --no-renames by default"
  else
    fail "diff_export produced rename  --  should default to --no-renames"
  fi
}

run_test test_package_branch_no_renames_true
run_test test_package_branch_default_detects_rename
run_test test_diff_export_uses_no_renames_by_default

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ "$FAIL" -eq 0 ]]
