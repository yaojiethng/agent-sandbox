#!/usr/bin/env bash
# tests/test_session_save_guard.sh
# Unit tests for the session save / autosave no-op guard in
# src/libs/session_save_policy.sh (session_save_needed, save_decision,
# _save_baseline). The module is reached through diff_export.sh, which sources
# it; the SESSION_STATE reader and the .export-status reader are exercised
# through their own libraries.
#
# Covers:
#   session_save_needed  --  the skip decision (dirty tree always saves; clean
#                            tree saves only when HEAD moved past the baseline)
#   save_decision        --  the operator-facing arm: silent save, loud skip,
#                            loud cannot-read
#   _save_baseline       --  resolves the comparison point (last .export-status
#                            HEAD, else init_sha)
#   autosave_cycle       --  the checkpoint swap, its staging path, and the
#                            failed-export and mid-swap-orphan recoveries
#   autosave_tick / autosave_loop  --  status absorption under a real set -e shell,
#                            driven through a fixture script rather than run_test
#
# The `.export-status` record's writer and readers are covered in
# tests/test_export_status.sh, with the library that defines them.
#
# The rule under test: a save runs iff the working tree is dirty (any
# uncommitted/untracked change) OR HEAD differs from BASELINE. It is skipped
# only when the tree is completely clean AND HEAD equals BASELINE.

set -uo pipefail
unset WORKSPACE_DIR_NAME SANDBOX_DIR_NAME CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/git_fixtures.sh"

# source the module under test (git_fixtures is independent)
source "${REPO_ROOT}/src/libs/diff_export.sh"
source "${REPO_ROOT}/src/libs/export_status.sh"
source "${REPO_ROOT}/src/libs/session_state.sh"
source "${REPO_ROOT}/src/libs/routing.sh"

# -- session_save_needed -----------------------------------------------------

# Given: a sandbox with an uncommitted or untracked change
# When:  session_save_needed runs
# Then:  rc 0 (save)
# Asserts: a dirty tree always saves, whatever the baseline.
test_dirty_tree_always_saves() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  local baseline
  baseline=$(get_init_sha "$fix")

  echo "uncommitted" >> "$fix/file.txt"
  if session_save_needed "$fix" "$baseline"; then
    pass "dirty tree saves (one uncommitted change)"
  else
    fail "dirty tree should always save"
  fi

  echo "more" >> "$fix/file.txt"
  if session_save_needed "$fix" "$baseline"; then
    pass "dirty tree saves regardless of change count (two changes)"
  else
    fail "two uncommitted changes must still save"
  fi

  touch "$fix/untracked.txt"
  if session_save_needed "$fix" "$baseline"; then
    pass "untracked file alone forces a save"
  else
    fail "untracked file must force a save"
  fi

}

# Given: a clean tree at the baseline
# When:  session_save_needed runs
# Then:  rc 1 (skip)
# Asserts: no work since the last save.
test_clean_tree_at_baseline_skips() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  local baseline
  baseline=$(get_init_sha "$fix")   # HEAD == init_sha, tree clean

  local rc=0
  session_save_needed "$fix" "$baseline" || rc=$?
  assert_eq "$rc" "1" "clean tree at baseline reports skip (1), not undeterminable"
}

# Given: a clean tree whose HEAD is past the baseline
# When:  session_save_needed runs
# Then:  rc 0 (save)
# Asserts: new commits force a save even on a clean tree.
test_clean_tree_past_baseline_saves() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  local baseline
  baseline=$(get_init_sha "$fix")

  commit_change "$fix" "second commit"
  # now clean but HEAD != init_sha -- must save (captures the new commit once)
  if session_save_needed "$fix" "$baseline"; then
    pass "clean tree with commits past baseline saves"
  else
    fail "clean tree past baseline must save"
  fi

  # at HEAD (== the new commit) it skips again -- level 2: nothing new
  local new_head rc=0
  new_head=$(git -C "$fix" rev-parse HEAD)
  session_save_needed "$fix" "$new_head" || rc=$?
  assert_eq "$rc" "1" "clean tree at last-saved HEAD reports skip (level 2)"
}

# -- save_decision (the caller-facing dispatch) ------------------------------

# Given: a clean tree at the baseline
# When:  save_decision runs
# Then:  rc 1 and the "nothing to save" diagnostic
# Asserts: the operator-facing skip arm.
test_save_decision_skip_reports_and_returns_1() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  # No prior export dir: the baseline resolves to init_sha, so a clean tree at
  # HEAD means nothing to save.
  local out rc=0
  out=$(save_decision "$fix" "$fix/no-prior-export" "session-export" 2>&1) || rc=$?
  assert_eq "$rc" "1" "save_decision: skip maps to 1"
  assert_contains "$out" "session-export: nothing to save" "save_decision: skip prints the label"
}

# Given: an unreadable repository
# When:  save_decision runs
# Then:  rc 0 and the cannot-read warning
# Asserts: the undeterminable arm saves loudly rather than skipping.
test_save_decision_undeterminable_saves_and_warns() {
  # The defect this guards: a sandbox whose .git cannot be read must not be
  # reported as "nothing to save". save_decision returns 0 (proceed) and says
  # why.
  local fix
  fix=$(get_fixture_dir)
  local out rc=0
  out=$(save_decision "$fix" "$fix/no-prior-export" "session-export" 2>&1) || rc=$?
  assert_eq "$rc" "0" "save_decision: undeterminable maps to 0 (save anyway)"
  assert_contains "$out" "cannot read the sandbox repository" \
      "save_decision: undeterminable says why"
  if [[ "$out" == *"nothing to save"* ]]; then
    fail "save_decision must not report nothing-to-save when git is unreadable"
  else
    pass "save_decision: undeterminable is not reported as nothing to save"
  fi
}

# -- _save_baseline ----------------------------------------------------------

# Given: no successful export in the export directory
# When:  _save_baseline runs
# Then:  the recorded init_sha is the baseline
# Asserts: the first-save level.
test_baseline_falls_back_to_init_sha() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  local expect
  expect=$(get_init_sha "$fix")

  local out
  out=$(_save_baseline "$fix" "$fix/nonexistent-dir")
  assert_eq "$out" "$expect" "_save_baseline falls back to init_sha when no prior export"
}

# Given: a successful export whose record carries a HEAD line
# When:  _save_baseline runs
# Then:  that HEAD is the baseline
# Asserts: the last-saved level.
test_baseline_reads_last_export_head() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"

  local exp_dir="$fix/prior"
  mkdir -p "$exp_dir"
  # a previous successful export recorded a HEAD that is not init_sha
  _write_export_status "$exp_dir" "SUCCESS" "20260622-120000" "0" "$(get_init_sha "$fix")" "deadbeefcafe"

  local out
  out=$(_save_baseline "$fix" "$exp_dir")
  assert_eq "$out" "deadbeefcafe" "_save_baseline uses last saved HEAD over init_sha"
}

# Given: a failed export that nevertheless carries a HEAD line
# When:  _save_baseline runs
# Then:  the baseline falls back to init_sha
# Asserts: only a successful export moves the baseline.
test_baseline_ignores_failed_export() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  local expect
  expect=$(get_init_sha "$fix")

  local exp_dir="$fix/prior"
  mkdir -p "$exp_dir"
  _write_export_status "$exp_dir" "FAIL" "20260622-120000" "1" "$(get_init_sha "$fix")" "deadbeefcafe"

  local out
  out=$(_save_baseline "$fix" "$exp_dir")
  assert_eq "$out" "$expect" "_save_baseline falls back to init_sha when prior export FAILed"
}

# Given: a repository git cannot read
# When:  session_save_needed runs
# Then:  rc 2 (undeterminable), never the skip code
# Asserts: a broken sandbox is not reported as nothing to save.
test_unreadable_repository_is_undeterminable() {
  # A sandbox whose .git cannot be read must not look like "nothing to save".
  # Returns 2 (undeterminable) so the caller saves or fails loudly instead of
  # reporting a clean tree.
  local fix
  fix=$(get_fixture_dir)
  local rc=0
  session_save_needed "$fix" "whatever" || rc=$?
  assert_eq "$rc" "2" "non-repository path: undeterminable, not skip"

  # Corrupt .git: present but not a valid repository.
  mkdir -p "$fix/.git"
  rc=0
  session_save_needed "$fix" "whatever" || rc=$?
  assert_eq "$rc" "2" "corrupt .git: undeterminable, not skip"
}

# Given: a dirty tree
# When:  save_decision runs
# Then:  rc 0 and no diagnostic
# Asserts: the save arm is silent.
test_save_decision_save_arm_is_silent_and_returns_0() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  echo "dirty" >> "$fix/file.txt"
  local out rc=0
  out=$(save_decision "$fix" "$fix/no-prior-export" "session-export" 2>&1) || rc=$?
  assert_eq "$rc" "0" "save_decision: dirty tree maps to 0 (save)"
  assert_empty "$out" "save_decision: the save arm prints nothing"
}

# -- session_export_needed (exit-time durable-record decision) --------------

# Given: work since the branch point, committed or uncommitted
# When:  session_export_needed runs
# Then:  rc 0 (run)
# Asserts: an ephemeral autosave never suppresses the durable exit export.
test_session_export_runs_with_work_despite_committed_or_uncommitted() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"

  # one committed change past the branch point
  commit_change "$fix" "second commit"
  local rc=0
  session_export_needed "$fix" || rc=$?
  assert_eq "$rc" "0" "session export runs after a committed change"

  # one uncommitted change
  echo dirty >> "$fix/file.txt"
  rc=0
  session_export_needed "$fix" || rc=$?
  assert_eq "$rc" "0" "session export runs with an uncommitted change"

  # a current autosave dir must not suppress it (the reported defect)
  mkdir -p "$fix/changes/autosave/s-x"
  rc=0
  session_export_needed "$fix" || rc=$?
  assert_eq "$rc" "0" "session export runs when an autosave already captured the state"
}

# Given: a clean tree at the branch point
# When:  session_export_needed runs
# Then:  rc 1 (skip)
# Asserts: no work at all means no exit export.
test_session_export_skips_clean_tree_at_branch_point() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"

  local rc=99
  session_export_needed "$fix" || rc=$?
  assert_eq "$rc" "1" "session export skips a clean tree at the branch point"
}

# -- autosave cycle ----------------------------------------------------------

# The autosave cycle, driven through the shipped autosave_cycle in
# src/libs/session_save_policy.sh (never a copy of it -- an inlined copy cannot
# detect the production code drifting). Two defects lived here: the staging
# path inside the channel, and `mv` into a channel directory that was never
# created, which failed outright on a fresh sandbox.
# Given: a checkpoint directory and its channel
# When:  autosave_cycle runs with a successful export
# Then:  the checkpoint lands at the channel path, the staging path is cleared,
#        nothing is nested inside the checkpoint, and no staging or aside path survives
# Asserts: the swap sequence and its cleanup invariants (also covers the failed-export
#          log rescue: the export's EXPORT-ERROR.log is moved beside the channel).
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
# directly (not through `run_test`) because `run_test`'s test subshell runs
# `set +e`, which suppresses `set -e` for everything the test function spawns
# -- exactly the condition the mechanism has to survive. A fixture script
# sources the shipped library under `set -euo pipefail`, runs one tick whose
# export fails, and must reach a second tick.
# Given: a tick whose decision is undeterminable, under a real set -e shell
# When:  the tick runs
# Then:  it returns without aborting the cell
# Asserts: every tick status is absorbed under set -e.
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
# `run_test`'s test subshell runs `set +e`, which suppresses `set -e` for
# everything it spawns -- including nested function calls and background
# subshells started from it. An unguarded call in `autosave_loop` therefore
# does NOT abort here; the probe below runs the shipped loop under a real
# `set -euo pipefail` shell, so removing the `|| true` from `autosave_loop`
# aborts the probe on the first failing tick and the marker file never
# appears.
# Given: a loop whose export command fails on every call
# When:  autosave_loop runs until it is signalled
# Then:  it keeps ticking, and an unset session id is reported rather than fatal
# Asserts: no tick outcome ends the loop.
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
# Given: the shipped call site's stub export
# When:  autosave_cycle invokes it
# Then:  arg 1 is the sandbox dir, arg 2 the staging path, arg 3 the session id
# Asserts: the cycle supplies the export arguments, the regression that once broke
#          every autosave in production while the suite stayed green.
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
# Given: an unreadable repository and a healthy one
# When:  autosave_cycle runs against each
# Then:  the healthy cycle writes a non-empty checkpoint and the unreadable one
#        saves anyway rather than reporting nothing to save
# Asserts: the undeterminable path end to end.
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

# -- run ---------------------------------------------------------------------

run_test test_dirty_tree_always_saves
run_test test_clean_tree_at_baseline_skips
run_test test_clean_tree_past_baseline_saves
run_test test_unreadable_repository_is_undeterminable
run_test test_save_decision_skip_reports_and_returns_1
run_test test_save_decision_undeterminable_saves_and_warns
run_test test_baseline_falls_back_to_init_sha
run_test test_baseline_reads_last_export_head
run_test test_baseline_ignores_failed_export
run_test test_save_decision_save_arm_is_silent_and_returns_0
run_test test_session_export_runs_with_work_despite_committed_or_uncommitted
run_test test_session_export_skips_clean_tree_at_branch_point

run_test test_autosave_swap_sequence
run_test test_autosave_tick_absorbs_status_under_real_set_e
run_test test_autosave_loop_survives_failing_ticks
run_test test_entrypoint_autosave_call_arguments
run_test test_autosave_cycle_refuses_unreadable_repo_end_to_end

test_done