#!/usr/bin/env bash
# Tests for libs/routing.sh
#
# Pins cite: docs/concepts/sandbox_identity.md l.142 (export path layout);
#             devlog/discussions/design_apply_draft_workflow.md (export_path is the
#             single path constructor); design_workspace_path_resolution.md.

# Covers:
#   export_path                --  unified path construction
#   resolve_source_for_draft   --  session resolution for draft operations

set -uo pipefail

# Ensure env overrides don't leak from outside the test suite
unset WORKSPACE_DIR_NAME
unset SANDBOX_DIR_NAME
unset CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/routing.sh"

# =============================================================================
# export_path
# =============================================================================

# Given: a parent, the session subdir, and a session id, with no label
# When:  export_path runs
# Then:  the path is <parent>/session/<EXPORT_TIME>-<id>
# Asserts: the base path shape.
test_export_path_session() {
  local RESULT
  RESULT=$(export_path "/changes" "session" "a1b2c3")
  assert_matches "$RESULT" '^/changes/session/[0-9]{8}-[0-9]{6}-a1b2c3$' "export_path constructs session path with EXPORT_TIME-SESSION_ID"
}

# Given: SUBDIR=autosave
# When:  export_path runs
# Then:  no EXPORT_TIME appears (one directory, overwritten)
# Asserts: the autosave exception.
test_export_path_autosave() {
  local RESULT
  RESULT=$(export_path "/changes" "autosave" "a1b2c3")
  assert_eq "$RESULT" "/changes/autosave/a1b2c3" "export_path constructs autosave path without EXPORT_TIME (single, overwritten)"
}

# Given: a label
# When:  export_path runs for bundles
# Then:  the label sits between EXPORT_TIME and the session id
# Asserts: label position.
test_export_path_bundles_with_label() {
  local RESULT
  RESULT=$(export_path "/output" "bundles" "a1b2c3" "my-feature")
  assert_matches "$RESULT" '^/output/bundles/[0-9]{8}-[0-9]{6}-my-feature-a1b2c3$' "export_path bundles: EXPORT_TIME-LABEL-SESSION_ID"
}

# Given: no label
# When:  export_path runs for bundles
# Then:  the path is <EXPORT_TIME>-<session-id>
# Asserts: the no-label branch.
test_export_path_bundles_no_label() {
  local RESULT
  RESULT=$(export_path "/output" "bundles" "a1b2c3")
  assert_matches "$RESULT" '^/output/bundles/[0-9]{8}-[0-9]{6}-a1b2c3$' "export_path bundles: EXPORT_TIME-SESSION_ID (no label)"
}

# Given: SUBDIR=diffs
# When:  export_path runs
# Then:  the same shape is produced
# Asserts: the constructor does not special-case its subdir argument.
test_export_path_diffs_with_label() {
  local RESULT
  RESULT=$(export_path "/output" "diffs" "a1b2c3" "snapshot")
  assert_matches "$RESULT" '^/output/diffs/[0-9]{8}-[0-9]{6}-snapshot-a1b2c3$' "export_path diffs: EXPORT_TIME-LABEL-SESSION_ID"
}

# Given: three empty required arguments
# When:  export_path runs
# Then:  rc is non-zero
# Asserts: the required-argument guard.
test_export_path_missing_args() {
  if export_path "" "" "" 2>/dev/null; then
    fail "export_path should fail with empty args"
  else
    pass "export_path fails with empty args"
  fi
}

# Given: an empty session id
# When:  export_path runs
# Then:  rc is non-zero
# Asserts: the guard through the id argument.
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

# Given: a session channel holding one export directory
# When:  resolve_source_for_draft runs with the default channel
# Then:  that directory resolves
# Asserts: the default channel and auto-resolution.
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

# Given: channel=autosave and a populated autosave base
# When:  resolve_source_for_draft runs
# Then:  the source comes from the autosave base
# Asserts: the channel mapping.
test_resolve_draft_explicit_channel_autosave() {
  local SD="$FIXTURE_DIR/sandbox2"
  mkdir -p "$SD/.workspace/session-diffs/autosave/20260408-120000-main/patches"
  touch "$SD/.workspace/session-diffs/autosave/20260408-120000-main/patches/0001-abc.diff"

  local RESULT
  RESULT=$(resolve_source_for_draft "$SD" "autosave" "") || { fail "resolve_source_for_draft autosave failed"; return; }
  local BUNDLE_NAME
  BUNDLE_NAME=$(echo "$RESULT" | cut -f2)
  assert_eq "$BUNDLE_NAME" "20260408-120000-main" "resolve_source_for_draft: autosave channel resolves correctly"
}

# Autosave auto-resolution must follow the directory MTIME (last saved), not
# the name: autosave dirs are named by SESSION_ID, so name order is meaningless.
# Given: two autosave directories where the lexicographic maximum is the older one
# When:  resolve_source_for_draft auto-resolves
# Then:  the newest by mtime wins
# Asserts: the mtime rule for the autosave channel.
test_resolve_draft_autosave_newest_by_mtime() {
  local SD="$FIXTURE_DIR/sandbox_mtime"
  local BASE="$SD/.workspace/session-diffs/autosave"
  mkdir -p "$BASE/aaaa"/patches "$BASE/zzzz"/patches
  touch "$BASE/aaaa/patches/0001-a.diff" "$BASE/zzzz/patches/0001-z.diff"
  # zzzz is the lexicographically-largest name but was saved LONGER ago;
  # aaaa was saved most recently. mtime must win over name order.
  touch -d "2020-01-01" "$BASE/zzzz"
  touch -d "2030-01-01" "$BASE/aaaa"

  local RESULT
  RESULT=$(resolve_source_for_draft "$SD" "autosave" "") || { fail "resolve_source_for_draft autosave (mtime) failed"; return; }
  local BUNDLE_NAME
  BUNDLE_NAME=$(echo "$RESULT" | cut -f2)
  assert_eq "$BUNDLE_NAME" "aaaa" "resolve_source_for_draft: autosave auto-resolve picks newest mtime, not largest name"
}

# A stale staging directory must never be selectable as a bundle. Driven by
# the shipped autosave_cycle: an interrupted cycle leaves the staging path
# outside autosave/, so the readers cannot pick it up. Guards the invariant
# that the channel holds checkpoint directories only.
# Given: an interrupted cycle leaves its staging path outside the channel
# When:  the channel is resolved
# Then:  the staging directory is never selectable
# Asserts: the channel holds checkpoint directories only.
test_staging_dir_is_not_selectable() {
  local SD="$FIXTURE_DIR/sandbox_staging"
  local CHANGES="$SD/.workspace/session-diffs"
  local SID="main"
  mkdir -p "$CHANGES/autosave/aaaa/patches" "$CHANGES/autosave/zzzz/patches"
  touch "$CHANGES/autosave/aaaa/patches/0001-a.diff" "$CHANGES/autosave/zzzz/patches/0001-z.diff"
  touch -d "2030-01-01" "$CHANGES/autosave/aaaa"

  # An interrupted cycle: a partial bundle at the staging path, newer than the
  # good checkpoint. The staging path belongs outside the channel, so the
  # readers must ignore it. Planting it directly models a SIGKILL mid-export,
  # which the cycle cannot clean up.
  mkdir -p "${CHANGES}/.autosave-staging-$SID/patches"
  touch "${CHANGES}/.autosave-staging-$SID/patches/0001-partial.diff"
  touch -d "2040-01-01" "${CHANGES}/.autosave-staging-$SID"

  local RESULT BUNDLE_NAME
  RESULT=$(resolve_source_for_draft "$SD" "autosave" "") || { fail "resolve_source_for_draft failed"; return; }
  BUNDLE_NAME=$(echo "$RESULT" | cut -f2)
  assert_eq "$BUNDLE_NAME" "aaaa" "an interrupted cycle's staging path is not selectable"

  local LATEST
  LATEST=$(resolve_latest_dir_by_mtime "$CHANGES/autosave")
  assert_eq "$LATEST" "$CHANGES/autosave/aaaa" "mtime reader ignores the staging path"
}


# The same mtime semantics for the raw helper (entrypoint autosave fallback).
# Given: directories with distinct mtimes
# When:  resolve_latest_dir_by_mtime runs
# Then:  the newest directory path is printed
# Asserts: the mtime read and the %T@ / path split.
test_resolve_latest_dir_by_mtime() {
  local B="$FIXTURE_DIR/mtime_base"
  mkdir -p "$B/aaa" "$B/mmm" "$B/zzz"
  touch -d "2020-01-01" "$B/aaa"
  touch -d "2030-01-01" "$B/mmm"
  touch -d "2025-01-01" "$B/zzz"
  local OUT
  OUT=$(resolve_latest_dir_by_mtime "$B")
  assert_eq "$OUT" "$B/mmm" "resolve_latest_dir_by_mtime: newest mtime wins regardless of name"
  if resolve_latest_dir_by_mtime "$FIXTURE_DIR/no-such-base" 2>/dev/null; then
    fail "resolve_latest_dir_by_mtime should fail on missing base dir"
  else
    pass "resolve_latest_dir_by_mtime: missing base -> rc!=0"
  fi
}

# Given: a BUNDLE_ARG naming an existing directory
# When:  resolve_source_for_draft runs
# Then:  that directory resolves
# Asserts: name-only resolution.
test_resolve_draft_named_session() {
  local SD="$FIXTURE_DIR/sandbox3"
  mkdir -p "$SD/.workspace/session-diffs/session/my-session/patches"
  touch "$SD/.workspace/session-diffs/session/my-session/patches/0001-abc.diff"

  local RESULT
  RESULT=$(resolve_source_for_draft "$SD" "session" "my-session") || { fail "resolve_source_for_draft named failed"; return; }
  local SOURCE_DIR BUNDLE_NAME
  SOURCE_DIR=$(echo "$RESULT" | cut -f1)
  BUNDLE_NAME=$(echo "$RESULT" | cut -f2)
  assert_eq "$BUNDLE_NAME" "my-session" "resolve_source_for_draft: named session resolves correctly"
}

# Given: an absolute BUNDLE_ARG
# When:  resolve_source_for_draft runs
# Then:  rc is non-zero
# Asserts: the rejection at return-code level only - the diagnostic is unpinned (finding 49).
test_resolve_draft_absolute_path_rejected() {
  local SD="$FIXTURE_DIR/sandbox4"
  mkdir -p "$SD/.workspace/output/bundles"

  if resolve_source_for_draft "$SD" "session" "/absolute/path" 2>/dev/null; then
    fail "resolve_source_for_draft should reject absolute paths"
  else
    pass "resolve_source_for_draft rejects absolute paths"
  fi
}

# Given: a BUNDLE_ARG that names nothing
# When:  resolve_source_for_draft runs
# Then:  rc is non-zero
# Asserts: the existence check.
test_resolve_draft_missing_session() {
  local SD="$FIXTURE_DIR/sandbox5"
  mkdir -p "$SD/.workspace/session-diffs/session"

  if resolve_source_for_draft "$SD" "session" "nonexistent" 2>/dev/null; then
    fail "resolve_source_for_draft should fail with missing session"
  else
    pass "resolve_source_for_draft fails with missing session"
  fi
}

# Given: channel=bundles and a populated bundles base
# When:  resolve_source_for_draft runs
# Then:  the source comes from OUTPUT_DIR/bundles
# Asserts: the bundles mapping.
test_resolve_draft_bundles_channel() {
  local SD="$FIXTURE_DIR/sandbox6"
  mkdir -p "$SD/.workspace/output/bundles/20260408-120000-my-bundle/patches"
  touch "$SD/.workspace/output/bundles/20260408-120000-my-bundle/patches/0001-abc.diff"

  local RESULT
  RESULT=$(resolve_source_for_draft "$SD" "bundles" "") || { fail "resolve_source_for_draft bundles failed"; return; }
  local BUNDLE_NAME
  BUNDLE_NAME=$(echo "$RESULT" | cut -f2)
  assert_eq "$BUNDLE_NAME" "20260408-120000-my-bundle" "resolve_source_for_draft: bundles channel resolves correctly"
}

# Given: an unknown channel
# When:  resolve_channel_base_dir runs
# Then:  rc 1 and the valid-channel list is printed
# Asserts: rejection with guidance.
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

# Given: channel=session
# When:  resolve_channel_base_dir runs
# Then:  it prints CHANGES_DIR/session
# Asserts: the session mapping.
test_resolve_channel_base_dir_session() {
  local SD="$FIXTURE_DIR/routing_c1"
  mkdir -p "$SD/.workspace"
  dirs_resolve "$SD"
  local RESULT
  RESULT=$(resolve_channel_base_dir "session") || { fail "resolve_channel_base_dir session failed"; return; }
  assert_eq "$RESULT" "${CHANGES_DIR}/session" "resolve_channel_base_dir: session -> CHANGES_DIR/session"
}

# Given: channel=autosave
# When:  resolve_channel_base_dir runs
# Then:  it prints CHANGES_DIR/autosave
# Asserts: the autosave mapping.
test_resolve_channel_base_dir_autosave() {
  local SD="$FIXTURE_DIR/routing_c2"
  mkdir -p "$SD/.workspace"
  dirs_resolve "$SD"
  local RESULT
  RESULT=$(resolve_channel_base_dir "autosave") || { fail "resolve_channel_base_dir autosave failed"; return; }
  assert_eq "$RESULT" "${CHANGES_DIR}/autosave" "resolve_channel_base_dir: autosave -> CHANGES_DIR/autosave"
}



# Given: channel=bundles
# When:  resolve_channel_base_dir runs
# Then:  it prints OUTPUT_DIR/bundles
# Asserts: the bundles mapping.
test_resolve_channel_base_dir_bundles() {
  local SD="$FIXTURE_DIR/routing_c4"
  mkdir -p "$SD/.workspace"
  dirs_resolve "$SD"
  local RESULT
  RESULT=$(resolve_channel_base_dir "bundles") || { fail "resolve_channel_base_dir bundles failed"; return; }
  assert_eq "$RESULT" "${OUTPUT_DIR}/bundles" "resolve_channel_base_dir: bundles -> OUTPUT_DIR/bundles"
}

# Given: an unknown channel
# When:  resolve_channel_base_dir runs
# Then:  rc 1 and the valid-channel list is printed
# Asserts: rejection (same behaviour as test_resolve_draft_invalid_channel, different name; finding 52).
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
# resolve_channel_base_dir
# =============================================================================

# Given: all three channel names in one pass
# When:  resolve_channel_base_dir runs for each
# Then:  each maps to its resolved base
# Asserts: the whole mapping table.
test_channel_base_dir_all_channels() {
  local OUT
  OUT=$(CHANGES_DIR=/c OUTPUT_DIR=/o bash -c '
    source "$0/src/libs/routing.sh" 2>/dev/null
    CHANGES_DIR=/c OUTPUT_DIR=/o
    echo "$(resolve_channel_base_dir session)|$(resolve_channel_base_dir autosave)|$(resolve_channel_base_dir bundles)"
  ' "$REPO_ROOT")
  assert_eq "$OUT" "/c/session|/c/autosave|/o/bundles" "resolve_channel_base_dir: session/autosave under CHANGES_DIR, bundles under OUTPUT_DIR"
}

# Given: an unknown channel
# When:  resolve_channel_base_dir runs
# Then:  rc 1 and the valid-channel hint
# Asserts: rejection with guidance (overlaps test_resolve_channel_base_dir_invalid).
test_channel_base_dir_unknown_rejected() {
  local OUT RC=0
  OUT=$(resolve_channel_base_dir bogus 2>&1 </dev/null) || RC=$?
  if [[ $RC -eq 1 && "$OUT" == *"Valid: session, autosave, bundles"* ]]; then
    pass "resolve_channel_base_dir: unknown channel rejected with valid-options hint"
  else
    fail "unknown channel should fail rc1, got rc=$RC out='$OUT'"
  fi
}

# =============================================================================
# resolve_latest_dir
# =============================================================================

# Given: a base directory that does not exist
# When:  resolve_latest_dir runs
# Then:  rc is non-zero and it prints nothing
# Asserts: the missing-base guard, and that a refusal prints no path a caller could use.
test_resolve_latest_dir_missing_base_fails() {
  local out rc
  out=$(resolve_latest_dir "$FIXTURE_DIR/no-such-base" 2>/dev/null); rc=$?
  if [[ $rc -ne 0 && -z "$out" ]]; then
    pass "resolve_latest_dir: missing base -> rc!=0 and no output"
  else
    fail "resolve_latest_dir missing base: rc=$rc out='$out'"
  fi
}

# Given: a base directory with no subdirectories
# When:  resolve_latest_dir runs
# Then:  rc is non-zero and it prints nothing
# Asserts: the no-subdirectory guard, and that a refusal prints no path a caller could use.
test_resolve_latest_dir_empty_base_fails() {
  mkdir -p "$FIXTURE_DIR/empty_base"
  local out rc
  out=$(resolve_latest_dir "$FIXTURE_DIR/empty_base" 2>/dev/null); rc=$?
  if [[ $rc -ne 0 && -z "$out" ]]; then
    pass "resolve_latest_dir: no subdirectories -> rc!=0 and no output"
  else
    fail "resolve_latest_dir empty base: rc=$rc out='$out'"
  fi
}

# Given: timestamped directories whose newest mtime is not the lexicographic maximum, plus a stray file
# When:  resolve_latest_dir runs
# Then:  the lexicographic maximum directory wins and the file is ignored
# Asserts: name order, not mtime, and directories only. The implementation is
#   `find -type d | sort | tail`, and the session channels name directories with
#   zero-padded timestamps, so lexicographic order equals chronological order.
#   Pin both clauses so nobody 'fixes' the selection silently.
test_resolve_latest_dir_picks_lexicographic_max_ignoring_mtime_and_files() {
  local B="$FIXTURE_DIR/latest_base"
  mkdir -p "$B/20260401-090000" "$B/20260501-120000" "$B/20260601-010000"
  touch -d "2030-01-01" "$B/20260501-120000"   # newest mtime, not the maximum
  touch "$B/stray-file.txt"
  local OUT
  OUT=$(resolve_latest_dir "$B")
  assert_eq "$OUT" "$B/20260601-010000" "resolve_latest_dir: lexicographic maximum wins, ignoring mtime and files (pinned)"
}

# =============================================================================
# _resolve_paths  --  SESSION_STATE overrides vs dirs_resolve fallback
# =============================================================================

# Given: a complete SESSION_STATE record
# When:  _resolve_paths runs
# Then:  all three recorded values are used
# Asserts: state overrides the conventions.
test_resolve_paths_state_overrides_win() {
  source "$TEST_DIR/libs/git_fixtures.sh"
  source "$TEST_DIR/libs/session_fixtures.sh"
  local SD="$FIXTURE_DIR/rp_state"
  make_committed_repo "$SD"
  printf 'changes_dir=/custom/changes\ninput_dir=/custom/in\noutput_dir=/custom/out\n' \
    > "$SD/.git/SESSION_STATE"

  (
    unset CHANGES_DIR INPUT_DIR OUTPUT_DIR
    _resolve_paths "$SD"
    [[ "$CHANGES_DIR" == "/custom/changes" && "$INPUT_DIR" == "/custom/in" \
       && "$OUTPUT_DIR" == "/custom/out" ]]
  )
  if [[ $? -eq 0 ]]; then
    pass "_resolve_paths: SESSION_STATE values override defaults"
  else
    fail "state override path broken"
  fi
}

# Given: no SESSION_STATE record
# When:  _resolve_paths runs
# Then:  the dirs_resolve conventions are used
# Asserts: the fallback.
test_resolve_paths_falls_back_to_dirs_resolve() {
  source "$TEST_DIR/libs/git_fixtures.sh"
  local SD="$FIXTURE_DIR/rp_fallback"
  make_committed_repo "$SD"

  (
    unset CHANGES_DIR INPUT_DIR OUTPUT_DIR WORKSPACE_DIR_NAME CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME SNAPSHOT_DIR_NAME
    _resolve_paths "$SD"
    [[ "$CHANGES_DIR" == "$SD/.workspace/session-diffs" \
       && "$INPUT_DIR" == "$SD/.workspace/input" \
       && "$OUTPUT_DIR" == "$SD/.workspace/output" ]]
  )
  if [[ $? -eq 0 ]]; then
    pass "_resolve_paths: absent state falls back to dirs_resolve defaults"
  else
    fail "dirs_resolve fallback broken"
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
run_test test_channel_base_dir_all_channels
run_test test_channel_base_dir_unknown_rejected
run_test test_resolve_latest_dir_missing_base_fails
run_test test_resolve_latest_dir_empty_base_fails
run_test test_resolve_latest_dir_picks_lexicographic_max_ignoring_mtime_and_files
run_test test_resolve_latest_dir_by_mtime
# Given: a SESSION_STATE record that sets only changes_dir
# When:  _resolve_paths runs
# Then:  changes_dir is honoured and only the missing keys take the defaults
# Asserts: a partially populated record is not discarded wholesale.
test_resolve_paths_keeps_partial_record() {
  source "$TEST_DIR/libs/git_fixtures.sh"
  local SD="$FIXTURE_DIR/rp_partial"
  make_committed_repo "$SD"
  printf 'changes_dir=/custom/changes\n' > "$SD/.git/SESSION_STATE"

  (
    unset CHANGES_DIR INPUT_DIR OUTPUT_DIR WORKSPACE_DIR_NAME CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME SNAPSHOT_DIR_NAME
    _resolve_paths "$SD"
    [[ "$CHANGES_DIR" == "/custom/changes" \
       && "$INPUT_DIR" == "$SD/.workspace/input" \
       && "$OUTPUT_DIR" == "$SD/.workspace/output" ]]
  )
  if [[ $? -eq 0 ]]; then
    pass "_resolve_paths: a partial record keeps its set key and fills the rest"
  else
    fail "partial-state resolution broken"
  fi
}
run_test test_resolve_paths_keeps_partial_record

run_test test_resolve_paths_state_overrides_win
run_test test_resolve_paths_falls_back_to_dirs_resolve
run_test test_export_path_missing_session_id
run_test test_resolve_draft_default_channel
run_test test_resolve_draft_explicit_channel_autosave
run_test test_resolve_draft_autosave_newest_by_mtime
run_test test_staging_dir_is_not_selectable
run_test test_resolve_draft_named_session
run_test test_resolve_draft_absolute_path_rejected
run_test test_resolve_draft_missing_session
run_test test_resolve_draft_bundles_channel
run_test test_resolve_draft_invalid_channel
run_test test_resolve_channel_base_dir_session
run_test test_resolve_channel_base_dir_autosave
run_test test_resolve_channel_base_dir_bundles

run_test test_resolve_channel_base_dir_invalid

test_done

