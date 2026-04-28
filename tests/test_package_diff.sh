#!/usr/bin/env bash
# tests/test_package_diff.sh
# Tests for libs/package_diff.sh
#
# Covers:
#   package_diff.sh       — produces changes.diff, index lines stripped,
#                           output path, baseline resolution, missing args

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIFF_SCRIPT="$SCRIPT_DIR/../libs/package_diff.sh"
source "$SCRIPT_DIR/libs/git_fixtures.sh"

PASS=0
FAIL=0
FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
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
# (repo setup helpers sourced from tests/libs/git_fixtures.sh)

# -------------------------
# package_diff.sh — basic functionality
# -------------------------
test_package_diff_produces_changes_diff() {
  local DIR="$FIXTURE_DIR/pd_basic"
  local OUTDIR="$FIXTURE_DIR/pd_basic_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"
  local BASELINE
  BASELINE=$(get_init_sha "$DIR")

  echo "new content" > "$DIR/newfile.txt"

  # Run script from within the repo directory
  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --baseline="$BASELINE" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  if ls "$OUTDIR"/diffs/*-test/changes.diff >/dev/null 2>&1; then
    pass "package_diff.sh produces changes.diff in diffs/<timestamp>-<name>/"
  else
    fail "package_diff.sh should produce changes.diff in diffs/ subfolder"
  fi
}

test_package_diff_index_lines_stripped() {
  local DIR="$FIXTURE_DIR/pd_noindex"
  local OUTDIR="$FIXTURE_DIR/pd_noindex_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"
  local BASELINE
  BASELINE=$(get_init_sha "$DIR")

  echo "change" > "$DIR/changed.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --baseline="$BASELINE" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local DIFF_FILE
  DIFF_FILE=$(ls "$OUTDIR"/diffs/*-test/changes.diff 2>/dev/null | head -n1)
  if [[ -n "$DIFF_FILE" ]] && ! grep -q '^index ' "$DIFF_FILE"; then
    pass "package_diff.sh strips index lines from changes.diff"
  else
    fail "package_diff.sh should strip index lines"
  fi
}

test_package_diff_output_path_structure() {
  local DIR="$FIXTURE_DIR/pd_path"
  local OUTDIR="$FIXTURE_DIR/pd_path_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"
  local BASELINE
  BASELINE=$(get_init_sha "$DIR")

  echo "change" > "$DIR/changed.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --baseline="$BASELINE" --name=mytest --outdir="$OUTDIR" >/dev/null 2>&1)

  if [[ -d "$OUTDIR/diffs" ]] && \
     ls "$OUTDIR"/diffs/*-mytest >/dev/null 2>&1; then
    pass "package_diff.sh writes to diffs/<timestamp>-<name>/ structure"
  else
    fail "package_diff.sh should write to diffs/ subfolder"
  fi
}

# -------------------------
# package_diff.sh — baseline resolution
# -------------------------
test_package_diff_baseline_arg() {
  local DIR="$FIXTURE_DIR/pd_baseline"
  local OUTDIR="$FIXTURE_DIR/pd_baseline_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"
  local BASELINE
  BASELINE=$(get_init_sha "$DIR")

  echo "change" > "$DIR/changed.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --baseline="$BASELINE" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  if ls "$OUTDIR"/diffs/*-test/changes.diff >/dev/null 2>&1; then
    pass "package_diff.sh uses --baseline argument"
  else
    fail "package_diff.sh should use --baseline"
  fi
}

test_package_diff_baseline_required_outside_container() {
  local DIR="$FIXTURE_DIR/pd_nobaseline"
  local OUTDIR="$FIXTURE_DIR/pd_nobaseline_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"

  # No --baseline, not in container context (override HOME to avoid workspace/output detection)
  local OUTPUT
  OUTPUT=$(cd "$DIR" && HOME=/nonexistent bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" 2>&1)
  if echo "$OUTPUT" | grep -q "baseline is required"; then
    pass "package_diff.sh requires --baseline outside container"
  else
    fail "package_diff.sh should require --baseline outside container"
  fi
}

test_package_diff_init_sha_fallback() {
  local DIR="$FIXTURE_DIR/pd_initsha"
  local OUTDIR="$FIXTURE_DIR/pd_initsha_out"
  mkdir -p "$DIR" "$OUTDIR"
  make_committed_repo "$DIR"
  local INIT_SHA
  INIT_SHA=$(get_init_sha "$DIR")

  # Write INIT_SHA file
  echo "$INIT_SHA" > "$DIR/.git/INIT_SHA"

  echo "change" > "$DIR/changed.txt"

  # No --baseline, but INIT_SHA file exists
  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  if ls "$OUTDIR"/diffs/*-test/changes.diff >/dev/null 2>&1; then
    pass "package_diff.sh falls back to INIT_SHA file"
  else
    fail "package_diff.sh should fall back to INIT_SHA file"
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
  local BASELINE
  BASELINE=$(get_init_sha "$DIR")

  # No changes
  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --baseline="$BASELINE" --name=test --outdir="$OUTDIR" 2>&1)

  # Should report nothing to package and not create output dir
  if ! ls "$OUTDIR"/diffs/*-test >/dev/null 2>&1; then
    pass "package_diff.sh produces no output when no changes"
  else
    fail "package_diff.sh should not create output when no changes"
  fi
}

test_package_diff_missing_args() {
  local DIR="$FIXTURE_DIR/pd_missing_args"
  mkdir -p "$DIR"
  make_committed_repo "$DIR"

  local OUTPUT
  OUTPUT=$(cd "$DIR" && HOME=/nonexistent bash "$PACKAGE_DIFF_SCRIPT" 2>&1)
  if echo "$OUTPUT" | grep -q "Usage"; then
    pass "package_diff.sh shows usage with no args"
  else
    fail "package_diff.sh should show usage with no args"
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
  local BASELINE
  BASELINE=$(get_init_sha "$DIR")

  echo "change" > "$DIR/changed.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --baseline="$BASELINE" --name=custom_label --outdir="$OUTDIR" >/dev/null 2>&1)

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
  local BASELINE
  BASELINE=$(get_init_sha "$DIR")

  echo "change" > "$DIR/my_special_file.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --baseline="$BASELINE" --outdir="$OUTDIR" >/dev/null 2>&1)

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
  make_committed_repo "$DIR"
  make_committed_repo "$TARGET"
  local BASELINE
  BASELINE=$(get_init_sha "$DIR")

  echo "change" > "$DIR/changed.txt"
  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --baseline="$BASELINE" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local DIFF_FILE
  DIFF_FILE=$(ls "$OUTDIR"/diffs/*-test/changes.diff 2>/dev/null | head -n1)

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
  local BASELINE
  BASELINE=$(get_init_sha "$DIR")

  echo "unique content here" > "$DIR/unique.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --baseline="$BASELINE" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local DIFF_FILE
  DIFF_FILE=$(ls "$OUTDIR"/diffs/*-test/changes.diff 2>/dev/null | head -n1)

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
  local BASELINE
  BASELINE=$(get_init_sha "$DIR")

  # Untracked file
  echo "untracked" > "$DIR/untracked.txt"

  (cd "$DIR" && bash "$PACKAGE_DIFF_SCRIPT" --baseline="$BASELINE" --name=test --outdir="$OUTDIR" >/dev/null 2>&1)

  local DIFF_FILE
  DIFF_FILE=$(ls "$OUTDIR"/diffs/*-test/changes.diff 2>/dev/null | head -n1)

  if [[ -n "$DIFF_FILE" ]] && grep -q "untracked.txt" "$DIFF_FILE"; then
    pass "package_diff.sh includes untracked files in diff"
  else
    fail "package_diff.sh should include untracked files"
  fi
}

# -------------------------
# Run all tests
# -------------------------
run_test test_package_diff_produces_changes_diff
run_test test_package_diff_index_lines_stripped
run_test test_package_diff_output_path_structure
run_test test_package_diff_baseline_arg
run_test test_package_diff_baseline_required_outside_container
run_test test_package_diff_init_sha_fallback
run_test test_package_diff_no_changes
run_test test_package_diff_missing_args
run_test test_package_diff_unknown_arg
run_test test_package_diff_name_arg
run_test test_package_diff_automatic_name_derivation
run_test test_package_diff_diff_is_applicable
run_test test_package_diff_diff_contains_expected_content
run_test test_package_diff_includes_untracked

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
