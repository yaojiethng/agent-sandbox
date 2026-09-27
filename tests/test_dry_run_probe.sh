#!/usr/bin/env bash
# TEST_DEADLINE: 10
#   Budget rationale: this file runs 20+ probe invocations, so its honest
#   runtime sits near the 5s default and the 8-way parallel suite run can push
#   it over. A TIMEOUT here would also make a mutation's verdict unreadable.
# tests/test_dry_run_probe.sh
# Host-side unit harness for the dry-run bearer probes. Runs each probe with a
# Pins cite: 20260828-design-settled-dry_run_phase_split.md;
#             docs/architecture/tool_interface.md (Dry-Run Guarantees, diagnostics record).

# controllable fixture env + stubbed libs (tests/stubs/libs) and asserts each
# readiness layer's PASS/FAIL in isolation, plus the diagnostics record
# content and exit code. The probe checks are otherwise invoked exactly once,
# only through a docker dry-run -- this harness exercises them without docker.
#
# Coverage: capability (sandbox) probe and reasoning (agent) probe, one test
# per FAIL branch that forces a specific layer red, plus a healthy all-PASS run
# for each.
#
# NOTE: each test runs its probe inside a `( ... )` subshell (env is isolated),
# and writes results to a state file in key=value form (same shape as the
# record). Assertions are then made in the PARENT scope -- pass/fail must not be
# called from inside the subshell, or the counters are lost.

source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"
test_setup

STUB_LIBS="$TEST_DIR/stubs/libs"
STUB_ENV="$STUB_LIBS/bash_env.sh"
PROBE_CAP="$REPO_ROOT/scripts/dry_run_capability.sh"
PROBE_REAS="$REPO_ROOT/scripts/dry_run_reasoning.sh"
LAYERS=(docker_image workspace_mounts session_state session_data container_network agent_runtime)

kv() { awk -F= -v k="$2" '$1==k{print $2}' "$1"; }  # <file> <key>  (record/state: key=value per line)
layer_status() { kv "$1" "layer.$2"; }

make_repo() {  # $1 = dir; empty git repo with one root commit
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" config user.email "test@test" && git -C "$1" config user.name "test"
  touch "$1/.gitkeep"
  git -C "$1" add -A && git -C "$1" commit -q -m "init"
}

# -- probe runner (subshell-internal) ---------------------------------------
# Runs a probe with the currently-exported env and writes result state to $2.
PROBE_OUT="$FIXTURE_DIR/probe_out.txt"
_run_probe() {  # $1 = probe script, $2 = state file (key=value) [, $3 = record path]
  local script="$1" state="$2" rec="${3:-}"
  BASH_ENV="$STUB_ENV" bash "$script" >"$PROBE_OUT" 2>&1
  local rc=$?
  # The record path is derived from OUTPUT_DIR unless the caller names it -- a
  # probe that resolves its own paths (the bootstrap fallback) needs the
  # caller to name the record it is expected to write.
  [[ -n "$rec" ]] || rec="${OUTPUT_DIR}/dryrun.$(basename "$script" | sed 's/dry_run_//; s/\.sh//').record"
  {
    echo "rc=$rc"
    echo "record=$rec"
    echo "status=$(kv "$rec" status)"
    echo "container=$(kv "$rec" container)"
    local l
    for l in "${LAYERS[@]}"; do
      echo "layer.$l=$(kv "$rec" "layer.$l")"
    done
  } > "$state"
}

assert_all_layers_pass() {  # $1 = state file
  local state="$1" l s
  for l in "${LAYERS[@]}"; do
    s=$(layer_status "$state" "$l")
    if [[ "$s" == "PASS" ]]; then pass "layer.$l = PASS"; else fail "layer.$l = '$s' (expected PASS)"; fi
  done
}

# -- capability (sandbox) ----------------------------------------------------

# Exports a healthy capability fixture. $1 = fixture root.
_healthy_cap_env() {
  local fix="$1"
  make_repo "$fix/sandbox"
  local sha
  sha=$(git -C "$fix/sandbox" rev-parse HEAD)
  {
    echo "init_sha=$sha"
    echo "session_ts=$(date -u +%s)"
  } > "$fix/sandbox/.git/SESSION_STATE"
  mkdir -p "$fix/workspace/input" "$fix/workspace/output" "$fix/workspace/session-diffs/autosave"
  chmod 555 "$fix/workspace/input"
  export LIBS_DIR="$STUB_LIBS" ROOT="$fix" \
    INPUT_DIR="$fix/workspace/input" \
    OUTPUT_DIR="$fix/workspace/output" \
    CHANGES_DIR="$fix/workspace/session-diffs" \
    SESSION_ID="cap-sess-01" DRY_RUN_IDENTITY="capability-test"
}

# Given: a healthy capability fixture (valid init_sha, mounts, autosave dir)
# When:  the capability probe runs
# Then:  rc=0, record status PASS, identity echoed, every layer PASS
# Asserts: the healthy path of the check framework and the record writer.
test_cap_healthy_rc0_record_pass() {
  local fix="$FIXTURE_DIR/cap-healthy" state="$FIXTURE_DIR/cap_healthy.state"
  ( _healthy_cap_env "$fix"; _run_probe "$PROBE_CAP" "$state" )
  assert_rc 0 "$(kv "$state" rc)" "capability healthy exit code"
  assert_eq "$(kv "$state" status)" PASS "capability record status"
  assert_eq "$(kv "$state" container)" capability-test "capability record container identity"
  assert_all_layers_pass "$state"
}
run_test test_cap_healthy_rc0_record_pass

# Given: a healthy capability fixture whose channel paths are NOT in the env
# When:  the capability probe runs (it must resolve them from ROOT)
# Then:  rc=0, the record lands in the resolved OUTPUT_DIR, every layer PASS
# Asserts: the shared bootstrap's dirs_resolve fallback. The compose overlay
# always injects the paths, so nothing else exercises the fallback branch.
test_probe_bootstrap_resolves_channels_from_root() {
  local fix="$FIXTURE_DIR/bootstrap-defaults" state="$FIXTURE_DIR/bootstrap_defaults.state"
  local rec="$fix/workspace/output/dryrun.capability.record"
  ( _healthy_cap_env "$fix"
    unset CHANGES_DIR INPUT_DIR OUTPUT_DIR
    _run_probe "$PROBE_CAP" "$state" "$rec" )
  assert_rc 0 "$(kv "$state" rc)" "capability probe with no channel env vars"
  assert_eq "$(kv "$state" status)" PASS "record status when the channels resolve from ROOT"
  assert_all_layers_pass "$state"
}
run_test test_probe_bootstrap_resolves_channels_from_root

# Given: a well-formed but nonexistent init_sha
# When:  the capability probe runs
# Then:  rc=1, status FAIL, layer.session_state FAIL, session_data still PASS
# Asserts: per-layer failure isolation in the record.
test_cap_session_state_fail() {
  local fix="$FIXTURE_DIR/cap-ss" state="$FIXTURE_DIR/cap_ss.state"
  ( _healthy_cap_env "$fix"
    # a well-formed but nonexistent 40-hex id: `cat-file -e ...^{commit}`
    # refuses it (unlike `rev-parse --verify`, which accepts any full-length
    # hex without checking object existence -- see probe + own Findings)
    echo "init_sha=0000000000000000000000000000000000000000" > "$fix/sandbox/.git/SESSION_STATE"
    _run_probe "$PROBE_CAP" "$state" )
  assert_rc 1 "$(kv "$state" rc)" "capability session_state-fail exit code"
  assert_eq "$(kv "$state" status)" FAIL "capability record status (session_state fail)"
  assert_eq "$(layer_status "$state" session_state)" FAIL "layer.session_state = FAIL"
  assert_eq "$(layer_status "$state" session_data)" PASS "layer.session_data still PASS"
}
run_test test_cap_session_state_fail

# Given: a failing diff_export (STUB_DIFF_EXPORT_FAIL=1)
# When:  the capability probe runs
# Then:  rc=1, layer.session_data FAIL, session_state still PASS
# Asserts: a data-plane failure stays in its layer.
test_cap_session_data_fail() {
  local fix="$FIXTURE_DIR/cap-sd" state="$FIXTURE_DIR/cap_sd.state"
  ( _healthy_cap_env "$fix"
    export STUB_DIFF_EXPORT_FAIL=1  # diff_export fails while SESSION_STATE stays valid
    _run_probe "$PROBE_CAP" "$state" )
  assert_rc 1 "$(kv "$state" rc)" "capability session_data-fail exit code"
  assert_eq "$(kv "$state" status)" FAIL "capability record status (session_data fail)"
  assert_eq "$(layer_status "$state" session_data)" FAIL "layer.session_data = FAIL"
  assert_eq "$(layer_status "$state" session_state)" PASS "layer.session_state still PASS"
}
run_test test_cap_session_data_fail

# Given: an unwritable CHANGES_DIR parent
# When:  the capability probe runs
# Then:  rc=1, layer.container_network FAIL, session_data still PASS
# Asserts: a marker-write failure stays in its layer.
test_cap_container_network_fail() {
  local fix="$FIXTURE_DIR/cap-net" state="$FIXTURE_DIR/cap_net.state"
  ( _healthy_cap_env "$fix"
    local ro="$fix/ro-diffs"
    mkdir -p "$ro" && chmod 555 "$ro"
    export CHANGES_DIR="$ro/session-diffs"  # marker write fails (unwritable parent)
    _run_probe "$PROBE_CAP" "$state" )
  assert_rc 1 "$(kv "$state" rc)" "capability container_network-fail exit code"
  assert_eq "$(kv "$state" status)" FAIL "capability record status (network fail)"
  assert_eq "$(layer_status "$state" container_network)" FAIL "layer.container_network = FAIL"
  assert_eq "$(layer_status "$state" session_data)" PASS "layer.session_data still PASS"
}
run_test test_cap_container_network_fail

# -- reasoning (agent) -------------------------------------------------------

# Exports a healthy reasoning fixture. $1 = fixture root.
_healthy_reas_env() {
  local fix="$1"
  make_repo "$fix/sandbox"
  local sha
  sha=$(git -C "$fix/sandbox" rev-parse HEAD)
  {
    echo "init_sha=$sha"
    echo "session_ts=$(date -u +%s)"
  } > "$fix/sandbox/.git/SESSION_STATE"
  mkdir -p "$fix/agent-home" "$fix/work/input" "$fix/work/output" "$fix/work/session-diffs"
  chmod 555 "$fix/work/input"
  # capability-layer marker at CHANGES_DIR, the shared mount both probes resolve
  echo "CAPABILITY_LAYER_OK" > "$fix/work/session-diffs/.dryrun_capability_marker"
  export LIBS_DIR="$STUB_LIBS" ROOT="$fix" \
    AGENT_HOME="$fix/agent-home" PROVIDER_NAME="custom" AGENT_CMD="sh" \
    INPUT_DIR="$fix/work/input" OUTPUT_DIR="$fix/work/output" \
    CHANGES_DIR="$fix/work/session-diffs" EXPECTED_MOUNT_TARGET="$fix/work/session-diffs" \
    SESSION_ID="reas-sess-01" DRY_RUN_IDENTITY="reasoning-test"
}

# Given: a healthy reasoning fixture (marker, read-only input, non-root)
# When:  the reasoning probe runs
# Then:  rc=0, status PASS, identity echoed, every layer PASS
# Asserts: the reasoning probe's healthy path.
test_reas_healthy_rc0_record_pass() {
  local fix="$FIXTURE_DIR/reas-healthy" state="$FIXTURE_DIR/reas_healthy.state"
  ( _healthy_reas_env "$fix"; _run_probe "$PROBE_REAS" "$state" )
  assert_rc 0 "$(kv "$state" rc)" "reasoning healthy exit code"
  assert_eq "$(kv "$state" status)" PASS "reasoning record status"
  assert_eq "$(kv "$state" container)" reasoning-test "reasoning record container identity"
  assert_all_layers_pass "$state"
}
run_test test_reas_healthy_rc0_record_pass

# Given: no SESSION_STATE file
# When:  the reasoning probe runs
# Then:  rc=1, layer.session_state FAIL, workspace_mounts still PASS
# Asserts: identity failure isolation.
test_reas_session_state_fail() {
  local fix="$FIXTURE_DIR/reas-ss" state="$FIXTURE_DIR/reas_ss.state"
  ( _healthy_reas_env "$fix"
    rm -f "$fix/sandbox/.git/SESSION_STATE"
    _run_probe "$PROBE_REAS" "$state" )
  assert_rc 1 "$(kv "$state" rc)" "reasoning session_state-fail exit code"
  assert_eq "$(kv "$state" status)" FAIL "reasoning record status (session_state fail)"
  assert_eq "$(layer_status "$state" session_state)" FAIL "layer.session_state = FAIL"
  assert_eq "$(layer_status "$state" workspace_mounts)" PASS "layer.workspace_mounts still PASS"
}
run_test test_reas_session_state_fail

# Given: AGENT_HOME unset
# When:  the reasoning probe runs
# Then:  rc=1, layer.workspace_mounts FAIL, session_state still PASS
# Asserts: section maps a failing check to its layer name.
test_reas_workspace_mounts_fail() {
  local fix="$FIXTURE_DIR/reas-ws" state="$FIXTURE_DIR/reas_ws.state"
  ( _healthy_reas_env "$fix"
    unset AGENT_HOME
    _run_probe "$PROBE_REAS" "$state" )
  assert_rc 1 "$(kv "$state" rc)" "reasoning workspace_mounts-fail exit code"
  assert_eq "$(kv "$state" status)" FAIL "reasoning record status (workspace_mounts fail)"
  assert_eq "$(layer_status "$state" workspace_mounts)" FAIL "layer.workspace_mounts = FAIL"
  assert_eq "$(layer_status "$state" session_state)" PASS "layer.session_state still PASS"
}
run_test test_reas_workspace_mounts_fail

# Given: AGENT_CMD points to a missing command
# When:  the reasoning probe runs
# Then:  rc=1, layer.agent_runtime FAIL, session_state still PASS
# Asserts: runtime failure isolation.
test_reas_agent_runtime_fail() {
  local fix="$FIXTURE_DIR/reas-rt" state="$FIXTURE_DIR/reas_rt.state"
  ( _healthy_reas_env "$fix"
    export AGENT_CMD="no-such-command-xyz"
    _run_probe "$PROBE_REAS" "$state" )
  assert_rc 1 "$(kv "$state" rc)" "reasoning agent_runtime-fail exit code"
  assert_eq "$(kv "$state" status)" FAIL "reasoning record status (agent_runtime fail)"
  assert_eq "$(layer_status "$state" agent_runtime)" FAIL "layer.agent_runtime = FAIL"
  assert_eq "$(layer_status "$state" session_state)" PASS "layer.session_state still PASS"
}
run_test test_reas_agent_runtime_fail

# Given: CHANGES_DIR differs from EXPECTED_MOUNT_TARGET
# When:  the reasoning probe runs
# Then:  rc=1, layer.container_network FAIL, session_state still PASS
# Asserts: a mount-target mismatch is critical.
test_reas_container_network_fail() {
  local fix="$FIXTURE_DIR/reas-net" state="$FIXTURE_DIR/reas_net.state"
  ( _healthy_reas_env "$fix"
    local other="$fix/work/other-diffs"
    mkdir -p "$other"
    export CHANGES_DIR="$other"  # != EXPECTED_MOUNT_TARGET -> CRITICAL FAIL
    _run_probe "$PROBE_REAS" "$state" )
  assert_rc 1 "$(kv "$state" rc)" "reasoning container_network-fail exit code"
  assert_eq "$(kv "$state" status)" FAIL "reasoning record status (container_network fail)"
  assert_eq "$(layer_status "$state" container_network)" FAIL "layer.container_network = FAIL"
  assert_eq "$(layer_status "$state" session_state)" PASS "layer.session_state still PASS"
}
run_test test_reas_container_network_fail

# Direct unit test of the shared lib function the probe + diagnostics now use.
# dry_run_harness.sh (shared across both probes) is referenced by the probes
# via LIBS_DIR; this literal reference keeps stub-lib liveness truthful.
# Given: four sandboxes (valid commit, bogus hex, missing key, blob object)
# When:  init_sha_is_valid runs on each
# Then:  0, 1, 1, 1
# Asserts: object existence and commit type are checked, not just hex shape.
test_init_sha_is_valid_lib() {
  source "$REPO_ROOT/src/libs/session_state.sh"
  source "$REPO_ROOT/src/libs/dry_run_harness.sh"
  local fix="$FIXTURE_DIR/init-sha-lib"

  local valid="$fix/valid/sandbox"
  make_repo "$valid"
  local sha; sha=$(git -C "$valid" rev-parse HEAD)
  echo "init_sha=$sha" > "$valid/.git/SESSION_STATE"
  init_sha_is_valid "$valid"; assert_rc 0 "$?" "valid commit -> success"

  local bogus="$fix/bogus/sandbox"
  make_repo "$bogus"
  echo "init_sha=0000000000000000000000000000000000000000" > "$bogus/.git/SESSION_STATE"
  init_sha_is_valid "$bogus"; if [[ $? -ne 0 ]]; then pass "bogus hex -> fail"; else fail "bogus hex -> FAIL expected, succeeded"; fi

  local missing="$fix/missing/sandbox"
  make_repo "$missing"
  init_sha_is_valid "$missing"; assert_rc 1 "$?" "missing init_sha -> fail"

  local blob="$fix/blob/sandbox"
  make_repo "$blob"
  local blobs; blobs=$(printf 'data' | git -C "$blob" hash-object -w --stdin)
  echo "init_sha=$blobs" > "$blob/.git/SESSION_STATE"
  init_sha_is_valid "$blob"; if [[ $? -ne 0 ]]; then pass "non-commit (blob) object -> fail"; else fail "non-commit (blob) object -> FAIL expected, succeeded"; fi
}
run_test test_init_sha_is_valid_lib

# There must be no docker-image layer assertion in the probes (CP-owned/dedup);
# assert the probes don't emit one, guarding the readiness contract shape.
# Given: healthy fixtures for both probes
# When:  each probe runs
# Then:  neither stdout contains a docker_image section
# Asserts: docker_image is CP-owned and unasserted by the probes.
test_no_docker_image_layer_assertion() {
  local fix="$FIXTURE_DIR/no-image-layer"
  local cap_out="$FIXTURE_DIR/cap_noimg.txt" reas_out="$FIXTURE_DIR/reas_noimg.txt"
  local cstate="$FIXTURE_DIR/cap_noimg.state" rstate="$FIXTURE_DIR/reas_noimg.state"
  ( _healthy_cap_env "$fix"; _run_probe "$PROBE_CAP" "$cstate"; cp "$PROBE_OUT" "$cap_out" )
  ( _healthy_reas_env "$fix"; _run_probe "$PROBE_REAS" "$rstate"; cp "$PROBE_OUT" "$reas_out" )
  if grep -q "=== docker_image ===" "$cap_out" || grep -q "=== docker_image ===" "$reas_out"; then
    fail "probes emit a docker_image section"
  else
    pass "probes emit no docker_image section (CP-owned/dedup)"
  fi
}
run_test test_no_docker_image_layer_assertion

# Given: a capability fixture whose INPUT_DIR is absent (a warning-only failure)
# When:  the capability probe runs
# Then:  rc=0, status PASS, zero critical failures, and the warning summary
# Asserts: a warning never flips the layer verdict or the exit status.
test_cap_warning_only_run() {
  local fix="$FIXTURE_DIR/cap-warn" state="$FIXTURE_DIR/cap_warn.state"
  ( _healthy_cap_env "$fix"
    export INPUT_DIR="$fix/workspace/absent-input"
    _run_probe "$PROBE_CAP" "$state" )
  assert_rc 0 "$(kv "$state" rc)" "warning-only run exits 0"
  assert_eq "$(kv "$state" status)" PASS "warning-only record status stays PASS"
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "critical failures: 0" "warning-only run reports zero critical failures"
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "Review warnings before production use" \
    "warning-only run prints the warning summary"
}
run_test test_cap_warning_only_run

# Given: a healthy capability fixture
# When:  the capability probe runs
# Then:  the export_path check passes in the probe's own shell
# Asserts: export_path is called without a bash -c child (which inherits no
#          function definitions and so could never pass in production).
test_cap_export_path_check_passes() {
  local fix="$FIXTURE_DIR/cap-exportpath" state="$FIXTURE_DIR/cap_exportpath.state"
  ( _healthy_cap_env "$fix"; _run_probe "$PROBE_CAP" "$state" )
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "PASS  export_path: resolves with available env vars" \
    "export_path resolves when called directly"
}
run_test test_cap_export_path_check_passes

# Given: an input-directory mode that breaks each half of the mount contract
# When:  the capability probe runs
# Then:  the readability check warns for a missing dir and the read-only check
#        warns for a writable one
# Asserts: both halves of the input-mount semantics are asserted, not existence alone.
test_cap_input_mount_semantics() {
  local fix="$FIXTURE_DIR/cap-input-rw" state="$FIXTURE_DIR/cap_input_rw.state"
  ( _healthy_cap_env "$fix"
    chmod 755 "$fix/workspace/input"
    _run_probe "$PROBE_CAP" "$state" )
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "WARN  INPUT_DIR is read-only" \
    "a writable input mount warns"

  local fix2="$FIXTURE_DIR/cap-input-missing" state2="$FIXTURE_DIR/cap_input_missing.state"
  ( _healthy_cap_env "$fix2"
    export INPUT_DIR="$fix2/workspace/absent-input"
    _run_probe "$PROBE_CAP" "$state2" )
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "WARN  INPUT_DIR readable" \
    "a missing input dir warns on the readability check"
}
run_test test_cap_input_mount_semantics

# Given: an invalid TMPDIR, so the probe's mktemp preconditions fail
# When:  the capability probe runs
# Then:  rc=1, both subsections end at their precondition, no raw mkdir error
#        escapes, and the diagnostics record is still written
# Asserts: a failed precondition does not run the subsection with an empty path.
test_cap_failed_tempdir_precondition() {
  local fix="$FIXTURE_DIR/cap-tmpdir" state="$FIXTURE_DIR/cap_tmpdir.state"
  ( _healthy_cap_env "$fix"
    export TMPDIR="$fix/no-such-tmpdir"
    _run_probe "$PROBE_CAP" "$state" )
  assert_ne "0" "$(kv "$state" rc)" "a failed mktemp precondition fails the probe"
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "could not create temp directory" \
    "the data-plane precondition names the cause"
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "could not create fixture directory" \
    "the session-export precondition names the cause"
  assert_not_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "mkdir: cannot create directory" \
    "no raw mkdir error escapes from an empty fixture path"
  assert_file_exists "${OUTPUT_DIR:-$fix/workspace/output}/dryrun.capability.record" \
    "the diagnostics record is still written"
}
run_test test_cap_failed_tempdir_precondition

# Given: an unwritable OUTPUT_DIR, so the record cannot be written
# When:  the capability probe runs
# Then:  rc=1 and the missing record is named as a critical failure
# Asserts: a missing record does not surface later as an orchestration timeout.
test_cap_missing_record_is_critical() {
  local fix="$FIXTURE_DIR/cap-norecord" state="$FIXTURE_DIR/cap_norecord.state"
  ( _healthy_cap_env "$fix"
    mkdir -p "$fix/nowrite"
    chmod 555 "$fix/nowrite"
    export OUTPUT_DIR="$fix/nowrite"
    _run_probe "$PROBE_CAP" "$state" )
  assert_ne "0" "$(kv "$state" rc)" "a missing diagnostics record fails the probe"
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "diagnostics record not written" \
    "the missing record is named as a critical failure"
}
run_test test_cap_missing_record_is_critical

# Given: the capability probe's marker file
# When:  the reasoning probe runs over the same CHANGES_DIR
# Then:  the marker literal written by one probe is the literal read by the other
# Asserts: the cross-container marker name and value are one contract, not two copies.
test_marker_round_trips_between_probes() {
  local fix="$FIXTURE_DIR/marker-roundtrip"
  local cstate="$FIXTURE_DIR/marker_cap.state" rstate="$FIXTURE_DIR/marker_reas.state"
  ( _healthy_cap_env "$fix"; _run_probe "$PROBE_CAP" "$cstate" )
  local marker="$fix/workspace/session-diffs/.dryrun_capability_marker"
  assert_file_exists "$marker" "the capability probe writes the cross-container marker"
  assert_eq "$(cat "$marker")" "CAPABILITY_LAYER_OK" \
    "the marker carries the literal the reasoning probe expects"
  ( _healthy_reas_env "$fix"
    export CHANGES_DIR="$fix/workspace/session-diffs" \
           EXPECTED_MOUNT_TARGET="$fix/workspace/session-diffs"
    _run_probe "$PROBE_REAS" "$rstate" )
  assert_eq "$(layer_status "$rstate" container_network)" PASS \
    "the reasoning probe reads the marker from CHANGES_DIR"
}
run_test test_marker_round_trips_between_probes

# Given: a healthy reasoning fixture, and one whose marker carries wrong content
# When:  the reasoning probe runs over each
# Then:  the marker is gone in the first case and still in place in the second
# Asserts: the marker is a handshake token the reader consumes, so a leftover
#          marker cannot let a later probe pass the cross-container check
#          against a capability layer that never ran.
test_marker_is_consumed_by_the_reader() {
  local fix="$FIXTURE_DIR/marker-consumed" state="$FIXTURE_DIR/marker_consumed.state"
  local marker="$fix/work/session-diffs/.dryrun_capability_marker"
  ( _healthy_reas_env "$fix"
    _run_probe "$PROBE_REAS" "$state" )
  assert_rc 0 "$(kv "$state" rc)" "reasoning probe with the capability marker present"
  assert_eq "$(test -f "$marker" && echo present || echo absent)" "absent" \
    "the reasoning probe removes the capability marker it read"

  local fix2="$FIXTURE_DIR/marker-kept" state2="$FIXTURE_DIR/marker_kept.state"
  ( _healthy_reas_env "$fix2"
    echo "WRONG_VALUE" > "$fix2/work/session-diffs/.dryrun_capability_marker"
    _run_probe "$PROBE_REAS" "$state2" )
  assert_ne "0" "$(kv "$state2" rc)" "a wrong marker fails the reasoning probe"
  assert_eq "$(test -f "$fix2/work/session-diffs/.dryrun_capability_marker" && echo present || echo absent)" "present" \
    "the failure branch leaves the marker in place for diagnosis"
}
run_test test_marker_is_consumed_by_the_reader

# Given: no capability marker under CHANGES_DIR
# When:  the reasoning probe runs
# Then:  rc=1 and layer.container_network FAILs
# Asserts: the cross-container check is critical, not a warning.
test_reas_absent_marker_is_critical() {
  local fix="$FIXTURE_DIR/reas-nomarker" state="$FIXTURE_DIR/reas_nomarker.state"
  ( _healthy_reas_env "$fix"
    rm -f "$fix/work/session-diffs/.dryrun_capability_marker"
    _run_probe "$PROBE_REAS" "$state" )
  assert_ne "0" "$(kv "$state" rc)" "an absent marker fails the reasoning probe"
  assert_eq "$(layer_status "$state" container_network)" FAIL \
    "layer.container_network = FAIL when the marker is absent"
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "capability layer marker: not found under CHANGES_DIR" \
    "the absent marker is named"
}
run_test test_reas_absent_marker_is_critical

# Given: an unknown provider and no AGENT_CMD
# When:  the reasoning probe runs
# Then:  rc=1 and layer.agent_runtime FAILs
# Asserts: an unknown provider fails closed rather than downgrading to a warning.
test_reas_unknown_provider_fails_closed() {
  local fix="$FIXTURE_DIR/reas-unknown" state="$FIXTURE_DIR/reas_unknown.state"
  ( _healthy_reas_env "$fix"
    unset AGENT_CMD
    export PROVIDER_NAME="custom"
    _run_probe "$PROBE_REAS" "$state" )
  assert_ne "0" "$(kv "$state" rc)" "an unknown provider fails the reasoning probe"
  assert_eq "$(layer_status "$state" agent_runtime)" FAIL \
    "layer.agent_runtime = FAIL for an unknown provider"
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "agent binary unknown for provider" \
    "the unknown provider is named"
}
run_test test_reas_unknown_provider_fails_closed

# Given: a SESSION_STATE file that is present but carries an empty init_sha
# When:  the reasoning probe runs
# Then:  the presence check passes and the readable check is the refusal
# Asserts: the two session_state criticals are individually observable.
test_reas_empty_init_sha_is_distinguishable() {
  local fix="$FIXTURE_DIR/reas-empty-sha" state="$FIXTURE_DIR/reas_empty_sha.state"
  ( _healthy_reas_env "$fix"
    printf 'init_sha=\nsession_ts=%s\n' "$(date -u +%s)" > "$fix/sandbox/.git/SESSION_STATE"
    _run_probe "$PROBE_REAS" "$state" )
  assert_ne "0" "$(kv "$state" rc)" "an empty init_sha fails the reasoning probe"
  assert_eq "$(layer_status "$state" session_state)" FAIL \
    "layer.session_state = FAIL for an empty init_sha"
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "PASS  sandbox/.git/SESSION_STATE exists" \
    "the presence check passes when the file is present"
  assert_contains "$(cat "$PROBE_OUT" 2>/dev/null)" "FAIL  SESSION_STATE.init_sha readable" \
    "the readable check is the refusal"
}
run_test test_reas_empty_init_sha_is_distinguishable

test_done "test_dry_run_probe"