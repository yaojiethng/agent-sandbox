#!/usr/bin/env bash
# tests/test_package_diff.sh
# Tests for libs/package_diff.sh
#
# Covers:
#   package_diff.sh       — produces uncommitted.diff, index lines stripped,
#                           output path, SESSION_STATE fallback, missing args

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIFF_SCRIPT="$SCRIPT_DIR/../libs/package_diff.sh"
source "$SCRIPT_DIR/libs/git_fixtures.sh"

source "$SCRIPT_DIR/libs/test_common.sh"

FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# -------------------------
# Helpers
# -------------------------
write_session_state() {
  local DIR="$1"
  local INIT_SHA="$2"
  local SESSION_TS="${3:-}"
  mkdir -p "$DIR/.git"
  echo "init_sha=$INIT_SHA" > "$DIR/.git/SESSION_STATE"
  if [[ -n "$SESSION_TS" ]]; then
    echo "session_ts=$SESSION_TS" >> "$DIR/.git/SESSION_STATE"
  fi
}

# -------------------------
# package_diff.sh — basic functionality
# -------------------------
test_package_diff_produces_uncommitted_diff() {
  local DIR="$FIXTURE_DIR/pd_basic"
  local OUTDIR="$FIXTURE_DIR/pd_basic_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  echo "new content" > "$DIR/newfile.txt"

  # Run script from within the repo directory
  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  if ls "$OUTDIR"/diffs/*-test/uncommitted.diff >/dev/null 2>&1; then
    pass "package_diff.sh produces uncommitted.diff in diffs/<timestamp>-<name>/"
  else
    fail "package_diff.sh should produce uncommitted.diff in diffs/ subfolder"
  fi
}

test_package_diff_index_lines_stripped() {
  local DIR="$FIXTURE_DIR/pd_noindex"
  local OUTDIR="$FIXTURE_DIR/pd_noindex_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  echo "change" > "$DIR/changed.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local DIFF_FILE
  DIFF_FILE=$(ls "$OUTDIR"/diffs/*-test/uncommitted.diff 2>/dev/null | head -n1)
  if [[ -n "$DIFF_FILE" ]] && ! grep -q '^index ' "$DIFF_FILE"; then
    pass "package_diff.sh strips index lines from uncommitted.diff"
  else
    fail "package_diff.sh should strip index lines"
  fi
}

test_package_diff_output_path_structure() {
  local DIR="$FIXTURE_DIR/pd_path"
  local OUTDIR="$FIXTURE_DIR/pd_path_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  echo "change" > "$DIR/changed.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=mytest --outdir="$OUTDIR" >/dev/null 2>&1)

  if [[ -d "$OUTDIR/diffs" ]] && \
     ls "$OUTDIR"/diffs/*-mytest >/dev/null 2>&1; then
    pass "package_diff.sh writes to diffs/<timestamp>-<name>/ structure"
  else
    fail "package_diff.sh should write to diffs/ subfolder"
  fi
}

# -------------------------
# package_diff.sh — SESSION_STATE fallback
# -------------------------
test_package_diff_session_state_fallback() {
  local DIR="$FIXTURE_DIR/pd_session_state"
  local OUTDIR="$FIXTURE_DIR/pd_session_state_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  write_session_state "$DIR" "$INIT_SHA" "20260417-120000"

  echo "change" > "$DIR/changed.txt"

  # No --session-ts, but SESSION_STATE exists
  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  if ls "$OUTDIR"/diffs/*-test-20260417-120000/uncommitted.diff >/dev/null 2>&1; then
    pass "package_diff.sh falls back to SESSION_STATE for session_ts"
  else
    fail "package_diff.sh should fall back to SESSION_STATE for session_ts"
  fi
}

# -------------------------
# package_diff.sh — edge cases
# -------------------------
test_package_diff_no_changes() {
  local DIR="$FIXTURE_DIR/pd_nochange"
  local OUTDIR="$FIXTURE_DIR/pd_nochange_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  # No changes
  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" 2>&1)

  # Should report nothing to package and not create output dir
  if ! ls "$OUTDIR"/diffs/*-test >/dev/null 2>&1; then
    pass "package_diff.sh produces no output when no changes"
  else
    fail "package_diff.sh should not create output when no changes"
  fi
}

test_package_diff_no_changes_no_args() {
  local DIR="$FIXTURE_DIR/pd_noargs"
  local OUTDIR="$FIXTURE_DIR/pd_noargs_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  # No changes, no args — should report nothing to package
  local OUTPUT
  OUTPUT=$(cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --outdir="$OUTDIR" 2>&1)
  if echo "$OUTPUT" | grep -q "Nothing to package"; then
    pass "package_diff.sh reports nothing to package when no changes and no args"
  else
    fail "package_diff.sh should report nothing to package when no changes"
  fi
}

test_package_diff_unknown_arg() {
  local OUTPUT
  OUTPUT=$(bash "$PACKAGE_DIFF_SCRIPT" --unknown 2>&1)
  if echo "$OUTPUT" | grep -q "Unknown argument"; then
    pass "package_diff.sh rejects unknown arguments"
  else
    fail "package_diff.sh should reject unknown arguments"
  fi
}

test_package_diff_name_arg() {
  local DIR="$FIXTURE_DIR/pd_name"
  local OUTDIR="$FIXTURE_DIR/pd_name_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  echo "change" > "$DIR/changed.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=custom_label --outdir="$OUTDIR" >/dev/null 2>&1)

  if ls "$OUTDIR"/diffs/*-custom_label >/dev/null 2>&1; then
    pass "package_diff.sh uses --name for output directory label"
  else
    fail "package_diff.sh should use --name for label"
  fi
}

test_package_diff_automatic_name_derivation() {
  local DIR="$FIXTURE_DIR/pd_autoname"
  local OUTDIR="$FIXTURE_DIR/pd_autoname_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  echo "change" > "$DIR/my_special_file.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --outdir="$OUTDIR" >/dev/null 2>&1)

  # When --name is omitted, SESSION_SUMMARY defaults to "snapshot"
  if ls "$OUTDIR"/diffs/*-snapshot >/dev/null 2>&1; then
    pass "package_diff.sh falls back to 'snapshot' when --name not provided"
  else
    fail "package_diff.sh should fall back to 'snapshot'"
  fi
}

# -------------------------
# package_diff.sh — diff content verification
# -------------------------
test_package_diff_diff_is_applicable() {
  local DIR="$FIXTURE_DIR/pd_apply"
  local TARGET="$FIXTURE_DIR/pd_apply_target"
  local OUTDIR="$FIXTURE_DIR/pd_apply_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"
  make_committed_repo "$TARGET"

  echo "change" > "$DIR/changed.txt"
  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local DIFF_FILE
  DIFF_FILE=$(ls "$OUTDIR"/diffs/*-test/uncommitted.diff 2>/dev/null | head -n1)

  if [[ -n "$DIFF_FILE" ]]; then
    if git -C "$TARGET" apply "$DIFF_FILE" 2>/dev/null; then
      pass "diff produced by package_diff.sh applies cleanly via git apply"
    else
      fail "diff produced by package_diff.sh does not apply via git apply"
    fi
  else
    fail "package_diff.sh should produce a diff file"
  fi
}

test_package_diff_diff_contains_expected_content() {
  local DIR="$FIXTURE_DIR/pd_content"
  local OUTDIR="$FIXTURE_DIR/pd_content_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  echo "unique content here" > "$DIR/unique.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local DIFF_FILE
  DIFF_FILE=$(ls "$OUTDIR"/diffs/*-test/uncommitted.diff 2>/dev/null | head -n1)

  if [[ -n "$DIFF_FILE" ]] && grep -q "unique content here" "$DIFF_FILE"; then
    pass "diff contains expected file content"
  else
    fail "diff should contain expected file content"
  fi
}

# -------------------------
# package_diff.sh — untracked files
# -------------------------
test_package_diff_includes_untracked() {
  local DIR="$FIXTURE_DIR/pd_untracked"
  local OUTDIR="$FIXTURE_DIR/pd_untracked_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  # Untracked file
  echo "untracked" > "$DIR/untracked.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local DIFF_FILE
  DIFF_FILE=$(ls "$OUTDIR"/diffs/*-test/uncommitted.diff 2>/dev/null | head -n1)

  if [[ -n "$DIFF_FILE" ]] && grep -q "untracked.txt" "$DIFF_FILE"; then
    pass "package_diff.sh includes untracked files in diff"
  else
    fail "package_diff.sh should include untracked files"
  fi
}

# -------------------------
# package_diff.sh — changed-files
# -------------------------
test_package_diff_changed_files_manifest() {
  local DIR="$FIXTURE_DIR/pd_manifest"
  local OUTDIR="$FIXTURE_DIR/pd_manifest_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  echo "change a" > "$DIR/file-a.txt"
  echo "change b" > "$DIR/file-b.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local MANIFEST
  MANIFEST=$(ls "$OUTDIR"/diffs/*-test/changed-files/MANIFEST.txt 2>/dev/null | head -n1)

  if [[ -n "$MANIFEST" ]]; then
    local COUNT
    COUNT=$(grep -c '^.' "$MANIFEST" 2>/dev/null || echo 0)
    if [[ "$COUNT" -eq 2 ]]; then
      pass "changed-files/MANIFEST.txt lists correct number of files"
    else
      fail "expected 2 files in manifest, got $COUNT"
    fi
  else
    fail "changed-files/MANIFEST.txt not produced"
  fi
}

test_package_diff_changed_files_copies() {
  local DIR="$FIXTURE_DIR/pd_copies"
  local OUTDIR="$FIXTURE_DIR/pd_copies_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  echo "deep content" > "$DIR/deep.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local CF
  CF=$(ls -d "$OUTDIR"/diffs/*-test/changed-files 2>/dev/null | head -n1)

  if [[ -f "$CF/deep.txt" ]] && [[ "$(cat "$CF/deep.txt")" == "deep content" ]]; then
    pass "changed-files/ contains working tree copy with correct content"
  else
    fail "changed-files/ does not contain expected file copy"
  fi
}

test_package_diff_changed_files_untracked() {
  local DIR="$FIXTURE_DIR/pd_cf_untracked"
  local OUTDIR="$FIXTURE_DIR/pd_cf_untracked_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  echo "untracked data" > "$DIR/new-untracked.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local CF
  CF=$(ls -d "$OUTDIR"/diffs/*-test/changed-files 2>/dev/null | head -n1)

  if [[ -f "$CF/new-untracked.txt" ]]; then
    pass "changed-files/ includes untracked files"
  else
    fail "changed-files/ missing untracked file"
  fi
}

# -------------------------
# Run all tests
# -------------------------
run_test test_package_diff_produces_uncommitted_diff
run_test test_package_diff_index_lines_stripped
run_test test_package_diff_output_path_structure
run_test test_package_diff_session_state_fallback
run_test test_package_diff_no_changes
run_test test_package_diff_no_changes_no_args
run_test test_package_diff_unknown_arg
run_test test_package_diff_name_arg
run_test test_package_diff_automatic_name_derivation
run_test test_package_diff_diff_is_applicable
run_test test_package_diff_diff_contains_expected_content
run_test test_package_diff_includes_untracked

test_done
