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
source "$REPO_ROOT/src/libs/session_save_policy.sh"

# =============================================================================
# export_path
# =============================================================================

test_export_path_session() {
  local RESULT
  RESULT=$(export_path "/changes" "session" "a1b2c3")
  assert_matches "$RESULT" '^/changes/session/[0-9]{8}-[0-9]{6}-a1b2c3$' "export_path constructs session path with EXPORT_TIME-SESSION_ID"
}

test_export_path_autosave() {
  local RESULT
  RESULT=$(export_path "/changes" "autosave" "a1b2c3")
  assert_eq "$RESULT" "/changes/autosave/a1b2c3" "export_path constructs autosave path without EXPORT_TIME (single, overwritten)"
}

test_export_path_bundles_with_label() {
  local RESULT
  RESULT=$(export_path "/output" "bundles" "a1b2c3" "my-feature")
  assert_matches "$RESULT" '^/output/bundles/[0-9]{8}-[0-9]{6}-my-feature-a1b2c3$' "export_path bundles: EXPORT_TIME-LABEL-SESSION_ID"
}

test_export_path_bundles_no_label() {
  local RESULT
  RESULT=$(export_path "/output" "bundles" "a1b2c3")
  assert_matches "$RESULT" '^/output/bundles/[0-9]{8}-[0-9]{6}-a1b2c3$' "export_path bundles: EXPORT_TIME-SESSION_ID (no label)"
}

test_export_path_diffs_with_label() {
  local RESULT
  RESULT=$(export_path "/output" "diffs" "a1b2c3" "snapshot")
  assert_matches "$RESULT" '^/output/diffs/[0-9]{8}-[0-9]{6}-snapshot-a1b2c3$' "export_path diffs: EXPORT_TIME-LABEL-SESSION_ID"
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
  assert_eq "$BUNDLE_NAME" "20260408-120000-main" "resolve_source_for_draft: autosave channel resolves correctly"
}

# Autosave auto-resolution must follow the directory MTIME (last saved), not
# the name: autosave dirs are named by SESSION_ID, so name order is meaningless.
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

# The autosave cycle, driven through the shipped autosave_cycle in
# src/libs/session_save_policy.sh (never a copy of it -- an inlined copy cannot
# detect the production code drifting). Two defects lived here: the staging
# path inside the channel, and `mv` into a channel directory that was never
# created, which failed outright on a fresh sandbox.
test_autosave_swap_sequence() {
  local SD="$FIXTURE_DIR/sandbox_swap"
  local CHANGES="$SD/.workspace/session-diffs"
  local SID="swapmain"
  local as_dir="$CHANGES/autosave/$SID"

  # The stub export records the directory it was handed, so the test can assert
  # where the cycle stages. The stage must be outside the channel: the readers
  # enumerate autosave/'s direct children, so a stage there becomes selectable
  # as a bundle after an interrupted cycle.
  stub_export_ok() { echo "$2" > "$2/marker"; echo "$2" >> "$STAGE_LOG"; }
  STAGE_LOG="$FIXTURE_DIR/stage.log"
  : > "$STAGE_LOG"

  # Cycle 1: fresh sandbox, no channel directory yet. The cycle must create it
  # and land the checkpoint at the channel path.
  autosave_cycle "$CHANGES/autosave/$SID" "$CHANGES/autosave" "$SD" stub_export_ok >/dev/null 2>&1
  local rc=$?
  if [[ "$rc" -eq 0 && -f "$as_dir/marker" ]]; then
    pass "autosave cycle: a fresh sandbox lands the checkpoint at the channel path"
  else
    fail "autosave cycle: fresh-sandbox checkpoint missing (rc=$rc, found: $(find "$CHANGES" -maxdepth 3 2>/dev/null | tr '\n' ' '))"
  fi

  # The staging path must be outside the channel, and cleared afterwards.
  if [[ -e "$CHANGES/.autosave-staging-$SID" ]]; then
    fail "autosave cycle: the staging path survived a successful cycle"
  else
    pass "autosave cycle: the staging path is cleared after a successful swap"
  fi
  local staged
  staged="$(head -1 "$STAGE_LOG")"
  # Pin the documented path, not merely "not under the channel": the ADR's
  # atomicity argument depends on the staging path sharing a filesystem with
  # the channel, so the move is a rename.
  assert_eq "$staged" "$CHANGES/.autosave-staging-$SID" "autosave cycle: stages beside the channel"
  if [[ -e "$as_dir/.autosave-staging-$SID" ]]; then
    fail "autosave cycle: the stage was nested inside the channel"
  else
    pass "autosave cycle: nothing is nested inside the checkpoint directory"
  fi

  # No staging or aside artefact may remain anywhere after a successful cycle.
  local leftovers
  leftovers=$(find "$CHANGES" -maxdepth 1 -name '.autosave-*' 2>/dev/null)
  if [[ -z "$leftovers" ]]; then
    pass "autosave cycle: no staging or aside directory survives a success"
  else
    fail "autosave cycle: leftover working directory after success: $leftovers"
  fi

  # Cycle 2: the channel holds a checkpoint; the cycle replaces it in place.
  stub_export_new() { echo new > "$2/marker"; }
  autosave_cycle "$CHANGES/autosave/$SID" "$CHANGES/autosave" "$SD" stub_export_new >/dev/null 2>&1
  assert_eq "$(cat "$as_dir/marker")" "new" "autosave cycle: replacement lands in place"

  # Cycle 3: the export fails. The previous checkpoint must survive intact.
  stub_export_fail() { return 1; }
  local out rc3=0 as_old="$CHANGES/.autosave-previous-$SID"
  out=$(autosave_cycle "$CHANGES/autosave/$SID" "$CHANGES/autosave" "$SD" stub_export_fail 2>&1) || rc3=$?
  assert_eq "$rc3" "1" "autosave cycle: a failed export reports failure"
  assert_eq "$(cat "$as_dir/marker")" "new" "autosave cycle: a failed export keeps the previous checkpoint"

  # A failed export writes its diagnostic into the directory it was handed (the
  # staging path). The cycle must rescue the log before removing that path, or
  # the file the export just announced is destroyed one statement later.
  stub_export_fail_with_log() {
    echo "boom" > "$2/20260101-000000-EXPORT-ERROR.log"
    return 1
  }
  autosave_cycle "$CHANGES/autosave/$SID" "$CHANGES/autosave" "$SD" stub_export_fail_with_log >/dev/null 2>&1 || true
  if [[ -n "$(find "$CHANGES" -maxdepth 1 -name '*EXPORT-ERROR.log' 2>/dev/null)" ]]; then
    pass "autosave cycle: a failed export's error log is rescued from the staging path"
  else
    fail "autosave cycle: the export's error log was destroyed with the staging path"
  fi
  rm -f "$CHANGES"/*EXPORT-ERROR.log

  # The export receives the session id, so its diagnostic filename carries it.
  stub_export_records_id() { echo "$3" > "$FIXTURE_DIR/id.log"; return 1; }
  autosave_cycle "$CHANGES/autosave/$SID" "$CHANGES/autosave" "$SD" stub_export_records_id >/dev/null 2>&1 || true
  assert_eq "$(cat "$FIXTURE_DIR/id.log")" "$SID" "autosave cycle: the export receives the session id"

  # A failure message must not claim a checkpoint was kept when none exists.
  rm -rf "$as_dir" "$as_old"
  local no_kept
  no_kept=$(autosave_cycle "$CHANGES/autosave/$SID" "$CHANGES/autosave" "$SD" stub_export_fail 2>&1) || true
  if [[ "$no_kept" == *"kept"* ]]; then
    fail "autosave cycle: claims a checkpoint was kept when none exists"
  else
    pass "autosave cycle: no kept-checkpoint claim when there is none"
  fi

  # Cycle 4: a cycle killed mid-swap leaves the checkpoint at the aside path
  # with no live path. The next cycle must recover it rather than discard it.
  rm -rf "$as_dir" "$as_old"
  mkdir -p "$as_old" && echo orphan > "$as_old/marker"
  stub_export_after() { echo after > "$2/marker"; }
  autosave_cycle "$CHANGES/autosave/$SID" "$CHANGES/autosave" "$SD" stub_export_after >/dev/null 2>&1
  assert_eq "$(cat "$as_dir/marker")" "after" "autosave cycle: a mid-swap orphan does not lose the checkpoint"
  if [[ -e "$as_old" ]]; then
    fail "autosave cycle: the aside path survived a successful cycle"
  else
    pass "autosave cycle: the aside path is cleared after success"
  fi

  # Cycle 5: a mid-swap orphan followed by a FAILING export. The orphan must be
  # restored before the export is attempted, or the only checkpoint is stranded
  # at the aside path where no reader looks.
  rm -rf "$as_dir" "$as_old"
  mkdir -p "$as_old" && echo orphan > "$as_old/marker"
  stub_export_fail2() { return 1; }
  autosave_cycle "$CHANGES/autosave/$SID" "$CHANGES/autosave" "$SD" stub_export_fail2 >/dev/null 2>&1 || true
  assert_eq "$(cat "$as_dir/marker" 2>/dev/null)" "orphan" \
      "autosave cycle: a failed export still restores a mid-swap orphan"
}

# The status-absorption mechanism, verified in a fresh shell. This runs bash
# directly (not through `run_test`) because `run_test`'s `$1 || true` suppresses
# `set -e` for everything the test function spawns, which is exactly the
# condition the mechanism has to survive. A fixture script sources the shipped
# library under `set -euo pipefail`, runs one tick whose export fails, and must
# reach a second tick.
test_autosave_tick_absorbs_status_under_real_set_e() {
  local probe="$FIXTURE_DIR/loop_probe.sh"
  local SD="$FIXTURE_DIR/sandbox_probe"
  mkdir -p "$SD/.git"
  printf 'init_sha=abc\n' > "$SD/.git/SESSION_STATE"
  cat > "$probe" <<EOF
set -euo pipefail
source "$REPO_ROOT/src/libs/export_status.sh"
source "$REPO_ROOT/src/libs/session_state.sh"
source "$REPO_ROOT/src/libs/routing.sh"
source "$REPO_ROOT/src/libs/session_save_policy.sh"
calls="$SD/calls"; : > "\$calls"
stub() { echo x >> "\$calls"; if [[ \$(wc -l < "\$calls") -ge 2 ]]; then echo ok > "$SD/reached"; fi; return 1; }
autosave_loop 0 export_path "$SD" "$SD" sid stub & pid=\$!
for _ in \$(seq 1 50); do [[ -f "$SD/reached" ]] && break; sleep 0.05; done
kill -TERM \$pid 2>/dev/null || true
wait \$pid 2>/dev/null || true
EOF
  local rc=0
  bash "$probe" >/dev/null 2>&1 || rc=$?
  if [[ -f "$SD/reached" ]]; then
    pass "autosave loop: absorbs a failing tick under a real set -e shell"
  else
    fail "autosave loop: a failing tick ended the loop under set -e (rc=$rc)"
  fi
}

# The shipped autosave_loop, driven with an export that always fails. The loop
# must keep ticking: a bare `autosave_tick` call under `set -e` ends it on the
# first non-zero status (review round 4's blocker), and an unset session id
# must be reported rather than fatal.
#
# Mechanism is observed in a fresh bash process, not through `run_test`:
# `run_test` invokes the test function as `$1 || true`, and bash suppresses
# `set -e` for a command in a `||` list -- including nested function calls
# and background subshells started from it. An unguarded call in
# `autosave_loop` therefore does NOT abort here; the probe below runs the
# shipped loop under a real `set -euo pipefail` shell, so removing the
# `|| true` from `autosave_loop` aborts the probe on the first failing tick
# and the marker file never appears.
test_autosave_loop_survives_failing_ticks() {
  source "$REPO_ROOT/src/libs/routing.sh"
  local SD="$FIXTURE_DIR/sandbox_tickloop"
  local CHANGES="$SD/.workspace/session-diffs"
  local SID="tickloop"
  mkdir -p "$CHANGES"

  local probe="$FIXTURE_DIR/loop_marker_probe.sh"
  local reached="$SD/reached"
  rm -f "$reached"
  cat > "$probe" <<EOF
set -euo pipefail
source "$REPO_ROOT/src/libs/export_status.sh"
source "$REPO_ROOT/src/libs/session_state.sh"
source "$REPO_ROOT/src/libs/routing.sh"
source "$REPO_ROOT/src/libs/session_save_policy.sh"
calls="$SD/calls"; : > "\$calls"
stub() { echo x >> "\$calls"; if [[ \$(wc -l < "\$calls") -ge 3 ]]; then echo ok > "$reached"; fi; return 1; }
autosave_loop 0 export_path "$CHANGES" "$SD" "$SID" stub >/dev/null 2>&1 & pid=\$!
for _ in \$(seq 1 50); do [[ -f "$reached" ]] && break; sleep 0.05; done
kill -TERM \$pid 2>/dev/null || true
wait \$pid 2>/dev/null || true
EOF
  local rc=0
  bash "$probe" >/dev/null 2>&1 || rc=$?

  local attempts
  attempts=$(wc -l < "$SD/calls" 2>/dev/null || echo 0)
  if [[ -f "$reached" ]]; then
    pass "autosave loop: kept ticking after repeated failing ticks ($attempts attempts)"
  else
    fail "autosave loop: stopped on a non-zero tick ($attempts attempt(s), rc=$rc)"
  fi

  # An unset session id must skip the tick with a diagnostic, not kill the cell.
  stub_export_always_fails() { return 1; }
  local out
  out=$(
    set -euo pipefail
    autosave_loop 0 export_path "$CHANGES" "$SD" "" stub_export_always_fails 2>&1 &
    local p=$!
    sleep 1
    kill -TERM "$p" 2>/dev/null
    wait "$p" 2>/dev/null || true
  ) || true
  if [[ "$out" == *"SESSION_ID is unset"* ]]; then
    pass "autosave loop: an unset session id is reported, not fatal"
  else
    fail "autosave loop: unset session id produced no diagnostic: '$out'"
  fi
}

# The entrypoint's autosave invocation, driven verbatim. The tests above call
# autosave_cycle directly with stubs, so they cannot see the argument order the
# entrypoint passes to diff_export. That gap shipped a production break: the
# extracted tick dropped $SANDBOX_DIR, so every real tick called
# diff_export <staging> <session-id> and autosave never wrote a checkpoint.
test_entrypoint_autosave_call_arguments() {
  source "$REPO_ROOT/src/libs/routing.sh"
  local SD="$FIXTURE_DIR/sandbox_callargs"
  local CHANGES="$SD/.workspace/session-diffs"
  mkdir -p "$CHANGES"

  # Record diff_export's arguments as the entrypoint passes them.
  diff_export() { printf '%s\n' "$@" > "$FIXTURE_DIR/callargs.log"; return 1; }
  # Drive the shipped loop for a single tick rather than transcribing the
  # entrypoint's call: the entrypoint names only the export verb and the cycle
  # supplies the arguments, which is what keeps a dropped argument from being
  # invisible. autosave_tick is the shipped path from the caller's side.
  autosave_tick export_path "$CHANGES" "$SD" "sid1" diff_export >/dev/null 2>&1 || true

  local a1 a2 a3
  a1=$(sed -n 1p "$FIXTURE_DIR/callargs.log")
  a2=$(sed -n 2p "$FIXTURE_DIR/callargs.log")
  a3=$(sed -n 3p "$FIXTURE_DIR/callargs.log")
  assert_eq "$a1" "$SD" "autosave: diff_export arg 1 is the sandbox dir (cycle-supplied)"
  assert_eq "$a2" "$CHANGES/.autosave-staging-sid1" "autosave: diff_export arg 2 is the staging path (cycle-supplied)"
  assert_eq "$a3" "sid1" "autosave: diff_export arg 3 is the session id (cycle-supplied)"
  unset -f diff_export
}

# The full chain with the REAL export: a corrupt index must leave the previous
# checkpoint byte-identical, not replace it with an empty SUCCESS bundle. Stub
# export verbs cannot observe this, because they replace the layer that used to
# swallow the failure.
test_autosave_cycle_refuses_unreadable_repo_end_to_end() {
  source "$REPO_ROOT/src/libs/export_status.sh"
  source "$REPO_ROOT/src/libs/session_state.sh"
  source "$REPO_ROOT/src/libs/session_save_policy.sh"
  source "$REPO_ROOT/src/libs/diff_export.sh"

  local SD="$FIXTURE_DIR/sandbox_e2e"
  local CH="$SD/.workspace/session-diffs"
  local as_dir="$CH/autosave/e2e"
  mkdir -p "$SD/.git" "$CH"
  git -C "$SD" init -q
  git -C "$SD" config user.email t@t && git -C "$SD" config user.name t
  echo one > "$SD/a.txt"
  git -C "$SD" add -A && git -C "$SD" commit -qm base
  printf 'init_sha=%s\n' "$(git -C "$SD" rev-parse HEAD)" > "$SD/.git/SESSION_STATE"

  # Healthy cycle: write a real checkpoint.
  echo two > "$SD/b.txt"
  autosave_cycle "$as_dir" "$CH/autosave" "$SD" diff_export >/dev/null 2>&1 || true
  local before
  before=$(cat "$as_dir/all-changes.diff" 2>/dev/null | wc -c)
  if [[ "$before" -gt 0 ]]; then
    pass "end-to-end: a healthy cycle writes a non-empty checkpoint"
  else
    fail "end-to-end: healthy cycle produced no checkpoint content"
  fi

  # Corrupt the index, dirty the tree so the cycle attempts a save, then run it.
  printf 'garbage' > "$SD/.git/index"
  local rc=0
  autosave_cycle "$as_dir" "$CH/autosave" "$SD" diff_export >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "1" "end-to-end: an unreadable repository fails the cycle"
  assert_eq "$(cat "$as_dir/all-changes.diff" 2>/dev/null | wc -c)" "$before" \
      "end-to-end: the previous checkpoint is byte-identical after a refused cycle"
  assert_contains "$(cat "$as_dir/.export-status" 2>/dev/null)" "STATUS=SUCCESS" \
      "end-to-end: the surviving checkpoint keeps its SUCCESS status"
}

# The same mtime semantics for the raw helper (entrypoint autosave fallback).
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
  assert_eq "$BUNDLE_NAME" "20260408-120000-my-bundle" "resolve_source_for_draft: bundles channel resolves correctly"
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
  assert_eq "$RESULT" "${CHANGES_DIR}/session" "resolve_channel_base_dir: session -> CHANGES_DIR/session"
}

test_resolve_channel_base_dir_autosave() {
  local SD="$FIXTURE_DIR/routing_c2"
  mkdir -p "$SD/.workspace"
  dirs_resolve "$SD"
  local RESULT
  RESULT=$(resolve_channel_base_dir "autosave") || { fail "resolve_channel_base_dir autosave failed"; return; }
  assert_eq "$RESULT" "${CHANGES_DIR}/autosave" "resolve_channel_base_dir: autosave -> CHANGES_DIR/autosave"
}



test_resolve_channel_base_dir_bundles() {
  local SD="$FIXTURE_DIR/routing_c4"
  mkdir -p "$SD/.workspace"
  dirs_resolve "$SD"
  local RESULT
  RESULT=$(resolve_channel_base_dir "bundles") || { fail "resolve_channel_base_dir bundles failed"; return; }
  assert_eq "$RESULT" "${OUTPUT_DIR}/bundles" "resolve_channel_base_dir: bundles -> OUTPUT_DIR/bundles"
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
# resolve_channel_base_dir
# =============================================================================

test_channel_base_dir_all_channels() {
  local OUT
  OUT=$(CHANGES_DIR=/c OUTPUT_DIR=/o bash -c '
    source "$0/src/libs/routing.sh" 2>/dev/null
    CHANGES_DIR=/c OUTPUT_DIR=/o
    echo "$(resolve_channel_base_dir session)|$(resolve_channel_base_dir autosave)|$(resolve_channel_base_dir bundles)"
  ' "$REPO_ROOT")
  assert_eq "$OUT" "/c/session|/c/autosave|/o/bundles" "resolve_channel_base_dir: session/autosave under CHANGES_DIR, bundles under OUTPUT_DIR"
}

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

test_latest_dir_missing_base_fails() {
  if resolve_latest_dir "$FIXTURE_DIR/no-such-base" 2>/dev/null; then
    fail "resolve_latest_dir should fail on missing base dir"
  else
    pass "resolve_latest_dir: missing base -> rc!=0"
  fi
}

test_latest_dir_empty_base_fails() {
  mkdir -p "$FIXTURE_DIR/empty_base"
  if resolve_latest_dir "$FIXTURE_DIR/empty_base" 2>/dev/null; then
    fail "resolve_latest_dir should fail when base has no subdirectories"
  else
    pass "resolve_latest_dir: no subdirectories -> rc!=0"
  fi
}

test_latest_dir_picks_lexicographically_last() {
  # Implementation is `find | sort | tail`  --  the contract is LEXICOGRAPHIC,
  # not mtime. Pin that so nobody 'fixes' it silently.
  local B="$FIXTURE_DIR/latest_base"
  mkdir -p "$B/aaa" "$B/mmm" "$B/zzz"
  touch -d "2020-01-01" "$B/aaa"
  touch -d "2030-01-01" "$B/mmm"
  local OUT
  OUT=$(resolve_latest_dir "$B")
  assert_eq "$OUT" "$B/zzz" "resolve_latest_dir: lexicographically-last wins regardless of mtime (pinned)"
}

# =============================================================================
# _resolve_paths  --  SESSION_STATE overrides vs dirs_resolve fallback
# =============================================================================

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
run_test test_latest_dir_missing_base_fails
run_test test_latest_dir_empty_base_fails
run_test test_latest_dir_picks_lexicographically_last
run_test test_resolve_latest_dir_by_mtime
run_test test_resolve_paths_state_overrides_win
run_test test_resolve_paths_falls_back_to_dirs_resolve
run_test test_export_path_missing_session_id
run_test test_resolve_draft_default_channel
run_test test_resolve_draft_explicit_channel_autosave
run_test test_resolve_draft_autosave_newest_by_mtime
run_test test_staging_dir_is_not_selectable
run_test test_autosave_tick_absorbs_status_under_real_set_e
run_test test_autosave_loop_survives_failing_ticks
run_test test_entrypoint_autosave_call_arguments
run_test test_autosave_cycle_refuses_unreadable_repo_end_to_end
run_test test_autosave_swap_sequence
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

# Missing base directory -> exit 1, no output.
test_resolve_latest_dir_missing_base_fails() {
  local out rc
  out=$(resolve_latest_dir "$FIXTURE_DIR/does-not-exist" 2>/dev/null); rc=$?
  if [[ $rc -ne 0 && -z "$out" ]]; then
    pass "resolve_latest_dir fails cleanly on missing base"
  else
    fail "resolve_latest_dir missing base: rc=$rc out='$out'"
  fi
}

# Empty base directory -> exit 1, no output.
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
# timestamps, so lexicographic order equals chronological order  --  pin that
# assumption with realistic names.
test_resolve_latest_dir_picks_lexicographic_max_ignoring_files() {
  local B="$FIXTURE_DIR/latest_base_dated"
  mkdir -p "$B/20260501-120000" "$B/20260401-090000" "$B/20260601-010000"
  touch "$B/stray-file.txt"
  local out
  out=$(resolve_latest_dir "$B")
  assert_eq "$out" "$B/20260601-010000" "resolve_latest_dir picks lexicographic max dir, ignores files"
}

run_test test_resolve_channel_base_dir_invalid
run_test test_resolve_latest_dir_missing_base_fails
run_test test_resolve_latest_dir_empty_base_fails
run_test test_resolve_latest_dir_picks_lexicographic_max_ignoring_files

test_done

