#!/usr/bin/env bash
# Tests for libs/routing.sh
#
# Covers:
#   export_path               — unified path construction
#   resolve_source_for_draft  — session resolution for draft operations
#   resolve_diff_for_apply    — session resolution for apply operations

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
# resolve_diff_for_apply
# =============================================================================

test_resolve_apply_default_channel() {
  local SD="$FIXTURE_DIR/sandbox_a1"
  mkdir -p "$SD/.workspace/session-diffs/session/20260408-120000-run001"
  echo "diff content" > "$SD/.workspace/session-diffs/session/20260408-120000-run001/uncommitted.diff"

  local RESULT
  RESULT=$(resolve_diff_for_apply "$SD" "session" "") || { fail "resolve_diff_for_apply failed"; return; }
  if [[ "$RESULT" == *"uncommitted.diff" ]] && [[ -f "$RESULT" ]]; then
    pass "resolve_diff_for_apply: session channel resolves uncommitted.diff"
  else
    fail "resolve_diff_for_apply: expected uncommitted.diff, got $RESULT"
  fi
}

test_resolve_apply_autosave_channel() {
  local SD="$FIXTURE_DIR/sandbox_a2"
  mkdir -p "$SD/.workspace/session-diffs/autosave/20260408-120000-main"
  echo "diff content" > "$SD/.workspace/session-diffs/autosave/20260408-120000-main/uncommitted.diff"

  local RESULT
  RESULT=$(resolve_diff_for_apply "$SD" "autosave" "") || { fail "resolve_diff_for_apply autosave failed"; return; }
  if [[ "$RESULT" == *"uncommitted.diff" ]]; then
    pass "resolve_diff_for_apply: autosave channel resolves correctly"
  else
    fail "resolve_diff_for_apply autosave: expected uncommitted.diff, got $RESULT"
  fi
}

test_resolve_apply_session_channel() {
  local SD="$FIXTURE_DIR/sandbox_a3"
  mkdir -p "$SD/.workspace/session-diffs/session/20260408-120000-main"
  echo "diff content" > "$SD/.workspace/session-diffs/session/20260408-120000-main/uncommitted.diff"

  local RESULT
  RESULT=$(resolve_diff_for_apply "$SD" "session" "") || { fail "resolve_diff_for_apply session failed"; return; }
  if [[ "$RESULT" == *"uncommitted.diff" ]]; then
    pass "resolve_diff_for_apply: session channel resolves correctly"
  else
    fail "resolve_diff_for_apply session: expected uncommitted.diff, got $RESULT"
  fi
}

test_resolve_apply_named_session() {
  local SD="$FIXTURE_DIR/sandbox_a4"
  mkdir -p "$SD/.workspace/session-diffs/session/my-session"
  echo "diff content" > "$SD/.workspace/session-diffs/session/my-session/uncommitted.diff"

  local RESULT
  RESULT=$(resolve_diff_for_apply "$SD" "session" "my-session") || { fail "resolve_diff_for_apply named failed"; return; }
  if [[ "$RESULT" == "$SD/.workspace/session-diffs/session/my-session/uncommitted.diff" ]]; then
    pass "resolve_diff_for_apply: named session resolves full path"
  else
    fail "resolve_diff_for_apply named: expected .../my-session/uncommitted.diff, got $RESULT"
  fi
}

test_resolve_apply_absolute_path_rejected() {
  local SD="$FIXTURE_DIR/sandbox_a5"
  mkdir -p "$SD/.workspace/output/diffs"

  if resolve_diff_for_apply "$SD" "diffs" "/absolute/path" 2>/dev/null; then
    fail "resolve_diff_for_apply should reject absolute paths"
  else
    pass "resolve_diff_for_apply rejects absolute paths"
  fi
}

test_resolve_apply_missing_diff() {
  local SD="$FIXTURE_DIR/sandbox_a6"
  mkdir -p "$SD/.workspace/output/diffs/empty-session"

  if resolve_diff_for_apply "$SD" "diffs" "empty-session" 2>/dev/null; then
    fail "resolve_diff_for_apply should fail when uncommitted.diff missing"
  else
    pass "resolve_diff_for_apply fails when uncommitted.diff missing"
  fi
}

test_resolve_apply_invalid_channel() {
  local SD="$FIXTURE_DIR/sandbox_a7"
  mkdir -p "$SD/.workspace"

  if resolve_diff_for_apply "$SD" "invalid" "" 2>/dev/null; then
    fail "resolve_diff_for_apply should fail with invalid channel"
  else
    pass "resolve_diff_for_apply fails with invalid channel"
  fi
}

test_resolve_apply_no_sessions() {
  local SD="$FIXTURE_DIR/sandbox_a8"
  mkdir -p "$SD/.workspace/output/diffs"

  if resolve_diff_for_apply "$SD" "diffs" "" 2>/dev/null; then
    fail "resolve_diff_for_apply should fail when no sessions exist"
  else
    pass "resolve_diff_for_apply fails when no sessions exist"
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

test_resolve_channel_base_dir_diffs() {
  local SD="$FIXTURE_DIR/routing_c6"
  mkdir -p "$SD/.workspace"
  dirs_resolve "$SD"
  local RESULT
  RESULT=$(resolve_channel_base_dir "diffs") || { fail "resolve_channel_base_dir diffs failed"; return; }
  if [[ "$RESULT" == "${OUTPUT_DIR}/diffs" ]]; then
    pass "resolve_channel_base_dir: diffs → OUTPUT_DIR/diffs"
  else
    fail "resolve_channel_base_dir diffs: expected ${OUTPUT_DIR}/diffs, got $RESULT"
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
run_test test_resolve_apply_default_channel
run_test test_resolve_apply_autosave_channel
run_test test_resolve_apply_session_channel
run_test test_resolve_apply_named_session
run_test test_resolve_apply_absolute_path_rejected
run_test test_resolve_apply_missing_diff
run_test test_resolve_apply_invalid_channel
run_test test_resolve_apply_no_sessions
run_test test_resolve_channel_base_dir_session
run_test test_resolve_channel_base_dir_autosave
run_test test_resolve_channel_base_dir_bundles
run_test test_resolve_channel_base_dir_diffs
run_test test_resolve_channel_base_dir_invalid

test_done
