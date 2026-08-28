#!/usr/bin/env bash
# Tests for libs/routing.sh
#
# Covers:
#   export_path               — unified path construction
#   resolve_source_for_draft  — session resolution for draft operations

set -uo pipefail

# Ensure env overrides don't leak from outside the test suite
unset WORKSPACE_DIR_NAME
unset SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME
unset CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/routing.sh"

# =============================================================================
# export_path
# =============================================================================

test_export_path_session() {
  local RESULT
  RESULT=$(export_path "/changes" "session" "a1b2c3")
  if [[ "$RESULT" =~ ^/changes/session/[0-9]{8}-[0-9]{6}-a1b2c3$ ]]; then
    pass "export_path constructs session path with EXPORT_TIME-SESSION_ID"
  else
    fail "export_path session: expected /changes/session/<ts>-a1b2c3, got $RESULT"
  fi
}

test_export_path_autosave() {
  local RESULT
  RESULT=$(export_path "/changes" "autosave" "a1b2c3")
  if [[ "$RESULT" == "/changes/autosave/a1b2c3" ]]; then
    pass "export_path constructs autosave path without EXPORT_TIME (single, overwritten)"
  else
    fail "export_path autosave: expected /changes/autosave/a1b2c3, got $RESULT"
  fi
}

test_export_path_bundles_with_label() {
  local RESULT
  RESULT=$(export_path "/output" "bundles" "a1b2c3" "my-feature")
  if [[ "$RESULT" =~ ^/output/bundles/[0-9]{8}-[0-9]{6}-my-feature-a1b2c3$ ]]; then
    pass "export_path bundles: EXPORT_TIME-LABEL-SESSION_ID"
  else
    fail "export_path bundles with label: expected /output/bundles/<ts>-my-feature-a1b2c3, got $RESULT"
  fi
}

test_export_path_bundles_no_label() {
  local RESULT
  RESULT=$(export_path "/output" "bundles" "a1b2c3")
  if [[ "$RESULT" =~ ^/output/bundles/[0-9]{8}-[0-9]{6}-a1b2c3$ ]]; then
    pass "export_path bundles: EXPORT_TIME-SESSION_ID (no label)"
  else
    fail "export_path bundles no label: expected /output/bundles/<ts>-a1b2c3, got $RESULT"
  fi
}

test_export_path_diffs_with_label() {
  local RESULT
  RESULT=$(export_path "/output" "diffs" "a1b2c3" "snapshot")
  if [[ "$RESULT" =~ ^/output/diffs/[0-9]{8}-[0-9]{6}-snapshot-a1b2c3$ ]]; then
    pass "export_path diffs: EXPORT_TIME-LABEL-SESSION_ID"
  else
    fail "export_path diffs with label: expected /output/diffs/<ts>-snapshot-a1b2c3, got $RESULT"
  fi
}

test_export_path_missing_args() {
  if export_path "" "" "" 2>/dev/null; then
    fail "export_path should fail with empty args"
  else
    pass "export_path fails with empty args"
  fi
}

test_export_path_missing_session_id() {
  if export_path "/changes" "session" "" 2>/dev/null; then
    fail "export_path should fail with empty SESSION_ID"
  else
    pass "export_path fails with empty SESSION_ID"
  fi
}

# =============================================================================
# resolve_source_for_draft
# =============================================================================

test_resolve_draft_default_channel() {
  # Setup: create a session dir under session/
  local SD="$FIXTURE_DIR/sandbox"
  mkdir -p "$SD/.workspace/session-diffs/session/20260408-120000-main/patches"
  touch "$SD/.workspace/session-diffs/session/20260408-120000-main/patches/0001-abc.diff"

  local RESULT
  RESULT=$(resolve_source_for_draft "$SD" "session" "") || { fail "resolve_source_for_draft failed"; return; }
  local SOURCE_DIR BUNDLE_NAME
  SOURCE_DIR=$(echo "$RESULT" | cut -f1)
  BUNDLE_NAME=$(echo "$RESULT" | cut -f2)
  if [[ "$BUNDLE_NAME" == "20260408-120000-main" ]] && [[ -n "$SOURCE_DIR" ]]; then
    pass "resolve_source_for_draft: default channel resolves latest session"
  else
    fail "resolve_source_for_draft: expected 20260408-120000-main, got $BUNDLE_NAME / $SOURCE_DIR"
  fi
}

test_resolve_draft_explicit_channel_autosave() {
  local SD="$FIXTURE_DIR/sandbox2"
  mkdir -p "$SD/.workspace/session-diffs/autosave/20260408-120000-main/patches"
  touch "$SD/.workspace/session-diffs/autosave/20260408-120000-main/patches/0001-abc.diff"

  local RESULT
  RESULT=$(resolve_source_for_draft "$SD" "autosave" "") || { fail "resolve_source_for_draft autosave failed"; return; }
  local BUNDLE_NAME
  BUNDLE_NAME=$(echo "$RESULT" | cut -f2)
  if [[ "$BUNDLE_NAME" == "20260408-120000-main" ]]; then
    pass "resolve_source_for_draft: autosave channel resolves correctly"
  else
    fail "resolve_source_for_draft autosave: expected 20260408-120000-main, got $BUNDLE_NAME"
  fi
}

test_resolve_draft_named_session() {
  local SD="$FIXTURE_DIR/sandbox3"
  mkdir -p "$SD/.workspace/session-diffs/session/my-session/patches"
  touch "$SD/.workspace/session-diffs/session/my-session/patches/0001-abc.diff"

  local RESULT
  RESULT=$(resolve_source_for_draft "$SD" "session" "my-session") || { fail "resolve_source_for_draft named failed"; return; }
  local SOURCE_DIR BUNDLE_NAME
  SOURCE_DIR=$(echo "$RESULT" | cut -f1)
  BUNDLE_NAME=$(echo "$RESULT" | cut -f2)
  if [[ "$BUNDLE_NAME" == "my-session" ]]; then
    pass "resolve_source_for_draft: named session resolves correctly"
  else
    fail "resolve_source_for_draft named: expected my-session, got $BUNDLE_NAME"
  fi
}

test_resolve_draft_absolute_path_rejected() {
  local SD="$FIXTURE_DIR/sandbox4"
  mkdir -p "$SD/.workspace/output/bundles"

  if resolve_source_for_draft "$SD" "session" "/absolute/path" 2>/dev/null; then
    fail "resolve_source_for_draft should reject absolute paths"
  else
    pass "resolve_source_for_draft rejects absolute paths"
  fi
}

test_resolve_draft_missing_session() {
  local SD="$FIXTURE_DIR/sandbox5"
  mkdir -p "$SD/.workspace/session-diffs/session"

  if resolve_source_for_draft "$SD" "session" "nonexistent" 2>/dev/null; then
    fail "resolve_source_for_draft should fail with missing session"
  else
    pass "resolve_source_for_draft fails with missing session"
  fi
}

test_resolve_draft_bundles_channel() {
  local SD="$FIXTURE_DIR/sandbox6"
  mkdir -p "$SD/.workspace/output/bundles/20260408-120000-my-bundle/patches"
  touch "$SD/.workspace/output/bundles/20260408-120000-my-bundle/patches/0001-abc.diff"

  local RESULT
  RESULT=$(resolve_source_for_draft "$SD" "bundles" "") || { fail "resolve_source_for_draft bundles failed"; return; }
  local BUNDLE_NAME
  BUNDLE_NAME=$(echo "$RESULT" | cut -f2)
  if [[ "$BUNDLE_NAME" == "20260408-120000-my-bundle" ]]; then
    pass "resolve_source_for_draft: bundles channel resolves correctly"
  else
    fail "resolve_source_for_draft bundles: expected 20260408-120000-my-bundle, got $BUNDLE_NAME"
  fi
}

test_resolve_draft_invalid_channel() {
  local SD="$FIXTURE_DIR/sandbox7"
  mkdir -p "$SD/.workspace"

  if resolve_source_for_draft "$SD" "invalid" "" 2>/dev/null; then
    fail "resolve_source_for_draft should fail with invalid channel"
  else
    pass "resolve_source_for_draft fails with invalid channel"
  fi
}

# =============================================================================
# resolve_channel_base_dir
# =============================================================================

test_resolve_channel_base_dir_session() {
  local SD="$FIXTURE_DIR/routing_c1"
  mkdir -p "$SD/.workspace"
  dirs_resolve "$SD"
  local RESULT
  RESULT=$(resolve_channel_base_dir "session") || { fail "resolve_channel_base_dir session failed"; return; }
  if [[ "$RESULT" == "${CHANGES_DIR}/session" ]]; then
    pass "resolve_channel_base_dir: session → CHANGES_DIR/session"
  else
    fail "resolve_channel_base_dir session: expected ${CHANGES_DIR}/session, got $RESULT"
  fi
}

test_resolve_channel_base_dir_autosave() {
  local SD="$FIXTURE_DIR/routing_c2"
  mkdir -p "$SD/.workspace"
  dirs_resolve "$SD"
  local RESULT
  RESULT=$(resolve_channel_base_dir "autosave") || { fail "resolve_channel_base_dir autosave failed"; return; }
  if [[ "$RESULT" == "${CHANGES_DIR}/autosave" ]]; then
    pass "resolve_channel_base_dir: autosave → CHANGES_DIR/autosave"
  else
    fail "resolve_channel_base_dir autosave: expected ${CHANGES_DIR}/autosave, got $RESULT"
  fi
}



test_resolve_channel_base_dir_bundles() {
  local SD="$FIXTURE_DIR/routing_c4"
  mkdir -p "$SD/.workspace"
  dirs_resolve "$SD"
  local RESULT
  RESULT=$(resolve_channel_base_dir "bundles") || { fail "resolve_channel_base_dir bundles failed"; return; }
  if [[ "$RESULT" == "${OUTPUT_DIR}/bundles" ]]; then
    pass "resolve_channel_base_dir: bundles → OUTPUT_DIR/bundles"
  else
    fail "resolve_channel_base_dir bundles: expected ${OUTPUT_DIR}/bundles, got $RESULT"
  fi
}

test_resolve_channel_base_dir_invalid() {
  local SD="$FIXTURE_DIR/routing_c5"
  mkdir -p "$SD/.workspace"
  dirs_resolve "$SD"
  if resolve_channel_base_dir "invalid_channel" 2>/dev/null; then
    fail "resolve_channel_base_dir should fail with invalid channel"
  else
    pass "resolve_channel_base_dir fails with invalid channel"
  fi
}


# =============================================================================
# Run
# =============================================================================

run_test test_export_path_session
run_test test_export_path_autosave
run_test test_export_path_bundles_with_label
run_test test_export_path_bundles_no_label
run_test test_export_path_diffs_with_label
run_test test_export_path_missing_args
run_test test_export_path_missing_session_id
run_test test_resolve_draft_default_channel
run_test test_resolve_draft_explicit_channel_autosave
run_test test_resolve_draft_named_session
run_test test_resolve_draft_absolute_path_rejected
run_test test_resolve_draft_missing_session
run_test test_resolve_draft_bundles_channel
run_test test_resolve_draft_invalid_channel
run_test test_resolve_channel_base_dir_session
run_test test_resolve_channel_base_dir_autosave
run_test test_resolve_channel_base_dir_bundles
# =============================================================================
# resolve_latest_dir
# =============================================================================

# Missing base directory → exit 1, no output.
test_resolve_latest_dir_missing_base_fails() {
  local out rc
  out=$(resolve_latest_dir "$FIXTURE_DIR/does-not-exist" 2>/dev/null); rc=$?
  if [[ $rc -ne 0 && -z "$out" ]]; then
    pass "resolve_latest_dir fails cleanly on missing base"
  else
    fail "resolve_latest_dir missing base: rc=$rc out='$out'"
  fi
}

# Empty base directory → exit 1, no output.
test_resolve_latest_dir_empty_base_fails() {
  mkdir -p "$FIXTURE_DIR/empty_base"
  local out rc
  out=$(resolve_latest_dir "$FIXTURE_DIR/empty_base" 2>/dev/null); rc=$?
  if [[ $rc -ne 0 && -z "$out" ]]; then
    pass "resolve_latest_dir fails cleanly on empty base"
  else
    fail "resolve_latest_dir empty base: rc=$rc out='$out'"
  fi
}

# Files are ignored; lexicographic max wins. Session dirs are zero-padded
# timestamps, so lexicographic order equals chronological order — pin that
# assumption with realistic names.
test_resolve_latest_dir_picks_lexicographic_max_ignoring_files() {
  local B="$FIXTURE_DIR/latest_base_dated"
  mkdir -p "$B/20260501-120000" "$B/20260401-090000" "$B/20260601-010000"
  touch "$B/stray-file.txt"
  local out
  out=$(resolve_latest_dir "$B")
  if [[ "$out" == "$B/20260601-010000" ]]; then
    pass "resolve_latest_dir picks lexicographic max dir, ignores files"
  else
    fail "resolve_latest_dir → '$out', want '$B/20260601-010000'"
  fi
}

run_test test_resolve_channel_base_dir_invalid
run_test test_resolve_latest_dir_missing_base_fails
run_test test_resolve_latest_dir_empty_base_fails
run_test test_resolve_latest_dir_picks_lexicographic_max_ignoring_files

test_done
