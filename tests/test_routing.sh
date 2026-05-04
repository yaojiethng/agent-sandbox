#!/usr/bin/env bash
# Tests for libs/routing.sh
#
# Covers:
#   session_export_path       — path construction for entrypoint exports
#   output_export_path        — path construction for manual exports
#   resolve_source_for_draft  — session resolution for draft operations
#   resolve_diff_for_apply    — session resolution for apply operations

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/routing.sh"
source "$SCRIPT_DIR/libs/test_common.sh"

FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# =============================================================================
# session_export_path
# =============================================================================

test_session_export_path_session() {
  local RESULT
  RESULT=$(session_export_path "/changes" "session" "20260408-120000" "main")
  if [[ "$RESULT" == "/changes/session/20260408-120000-main" ]]; then
    pass "session_export_path constructs session path correctly"
  else
    fail "session_export_path: expected /changes/session/20260408-120000-main, got $RESULT"
  fi
}

test_session_export_path_autosave() {
  local RESULT
  RESULT=$(session_export_path "/changes" "autosave" "20260408-120000" "feature-x")
  if [[ "$RESULT" == "/changes/autosave/20260408-120000-feature-x" ]]; then
    pass "session_export_path constructs autosave path correctly"
  else
    fail "session_export_path: expected /changes/autosave/20260408-120000-feature-x, got $RESULT"
  fi
}

test_session_export_path_missing_args() {
  if session_export_path "" "" "" "" 2>/dev/null; then
    fail "session_export_path should fail with empty args"
  else
    pass "session_export_path fails with empty args"
  fi
}

# =============================================================================
# output_export_path
# =============================================================================

test_output_export_path_creates_dir() {
  local RESULT
  RESULT=$(output_export_path "$FIXTURE_DIR" "diffs" "snapshot" "20260408-120000")
  if [[ -d "$RESULT" ]]; then
    pass "output_export_path creates output directory"
  else
    fail "output_export_path should create output directory, got $RESULT"
  fi
  rm -rf "$RESULT"
}

test_output_export_path_diffs() {
  local RESULT
  RESULT=$(output_export_path "$FIXTURE_DIR" "diffs" "snapshot" "20260408-120000")
  local BASENAME
  BASENAME=$(basename "$RESULT")
  local PARENT
  PARENT=$(basename "$(dirname "$RESULT")")
  if [[ "$PARENT" == "diffs" ]]; then
    pass "output_export_path places output under diffs/ subdir"
  else
    fail "output_export_path: expected .../diffs/<ts>-snapshot-..., got parent=$PARENT"
  fi
  if [[ "$BASENAME" == *"-snapshot-20260408-120000" ]]; then
    pass "output_export_path includes session-ts suffix"
  else
    fail "output_export_path: expected <ts>-snapshot-20260408-120000, got $BASENAME"
  fi
  rm -rf "$RESULT"
}

test_output_export_path_bundles() {
  local RESULT
  RESULT=$(output_export_path "$FIXTURE_DIR" "bundles" "my-feature")
  local PARENT
  PARENT=$(basename "$(dirname "$RESULT")")
  if [[ "$PARENT" == "bundles" ]]; then
    pass "output_export_path places output under bundles/ subdir"
  else
    fail "output_export_path: expected .../bundles/<ts>-my-feature, got parent=$PARENT"
  fi
  rm -rf "$RESULT"
}

test_output_export_path_no_session_ts() {
  local RESULT
  RESULT=$(output_export_path "$FIXTURE_DIR" "diffs" "snapshot")
  local BASENAME
  BASENAME=$(basename "$RESULT")
  if [[ "$BASENAME" == *"-snapshot" ]] && [[ "$BASENAME" != *"-snapshot-"* ]]; then
    pass "output_export_path omits session-ts when not provided"
  else
    fail "output_export_path: expected <ts>-snapshot, got $BASENAME"
  fi
  rm -rf "$RESULT"
}

test_output_export_path_missing_args() {
  if output_export_path "" "" "" 2>/dev/null; then
    fail "output_export_path should fail with empty args"
  else
    pass "output_export_path fails with empty args"
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
  local SOURCE_DIR SESSION_NAME
  SOURCE_DIR=$(echo "$RESULT" | cut -f1)
  SESSION_NAME=$(echo "$RESULT" | cut -f2)
  if [[ "$SESSION_NAME" == "20260408-120000-main" ]] && [[ -n "$SOURCE_DIR" ]]; then
    pass "resolve_source_for_draft: default channel resolves latest session"
  else
    fail "resolve_source_for_draft: expected 20260408-120000-main, got $SESSION_NAME / $SOURCE_DIR"
  fi
}

test_resolve_draft_explicit_channel_autosave() {
  local SD="$FIXTURE_DIR/sandbox2"
  mkdir -p "$SD/.workspace/session-diffs/autosave/20260408-120000-main/patches"
  touch "$SD/.workspace/session-diffs/autosave/20260408-120000-main/patches/0001-abc.diff"

  local RESULT
  RESULT=$(resolve_source_for_draft "$SD" "autosave" "") || { fail "resolve_source_for_draft autosave failed"; return; }
  local SESSION_NAME
  SESSION_NAME=$(echo "$RESULT" | cut -f2)
  if [[ "$SESSION_NAME" == "20260408-120000-main" ]]; then
    pass "resolve_source_for_draft: autosave channel resolves correctly"
  else
    fail "resolve_source_for_draft autosave: expected 20260408-120000-main, got $SESSION_NAME"
  fi
}

test_resolve_draft_named_session() {
  local SD="$FIXTURE_DIR/sandbox3"
  mkdir -p "$SD/.workspace/session-diffs/session/my-session/patches"
  touch "$SD/.workspace/session-diffs/session/my-session/patches/0001-abc.diff"

  local RESULT
  RESULT=$(resolve_source_for_draft "$SD" "session" "my-session") || { fail "resolve_source_for_draft named failed"; return; }
  local SOURCE_DIR SESSION_NAME
  SOURCE_DIR=$(echo "$RESULT" | cut -f1)
  SESSION_NAME=$(echo "$RESULT" | cut -f2)
  if [[ "$SESSION_NAME" == "my-session" ]]; then
    pass "resolve_source_for_draft: named session resolves correctly"
  else
    fail "resolve_source_for_draft named: expected my-session, got $SESSION_NAME"
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
  local SESSION_NAME
  SESSION_NAME=$(echo "$RESULT" | cut -f2)
  if [[ "$SESSION_NAME" == "20260408-120000-my-bundle" ]]; then
    pass "resolve_source_for_draft: bundles channel resolves correctly"
  else
    fail "resolve_source_for_draft bundles: expected 20260408-120000-my-bundle, got $SESSION_NAME"
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
  mkdir -p "$SD/.workspace/output/diffs/20260408-120000-snapshot-abc"
  echo "diff content" > "$SD/.workspace/output/diffs/20260408-120000-snapshot-abc/uncommitted.diff"

  local RESULT
  RESULT=$(resolve_diff_for_apply "$SD" "diffs" "") || { fail "resolve_diff_for_apply failed"; return; }
  if [[ "$RESULT" == *"uncommitted.diff" ]] && [[ -f "$RESULT" ]]; then
    pass "resolve_diff_for_apply: default channel resolves uncommitted.diff"
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
  mkdir -p "$SD/.workspace/output/diffs/my-session"
  echo "diff content" > "$SD/.workspace/output/diffs/my-session/uncommitted.diff"

  local RESULT
  RESULT=$(resolve_diff_for_apply "$SD" "diffs" "my-session") || { fail "resolve_diff_for_apply named failed"; return; }
  if [[ "$RESULT" == "$SD/.workspace/output/diffs/my-session/uncommitted.diff" ]]; then
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
# Run
# =============================================================================

run_test test_session_export_path_session
run_test test_session_export_path_autosave
run_test test_session_export_path_missing_args
run_test test_output_export_path_creates_dir
run_test test_output_export_path_diffs
run_test test_output_export_path_bundles
run_test test_output_export_path_no_session_ts
run_test test_output_export_path_missing_args
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

test_done
