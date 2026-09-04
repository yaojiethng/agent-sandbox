#!/usr/bin/env bash
# tests/test_dry_run_probe.sh
# Host-side unit harness for the dry-run bearer probes. Runs each probe with a
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
_run_probe() {  # $1 = probe script, $2 = state file (key=value)
  local script="$1" state="$2"
  BASH_ENV="$STUB_ENV" bash "$script" >"$PROBE_OUT" 2>&1
  local rc=$?
  local rec
  rec="${OUTPUT_DIR}/dryrun.$(basename "$script" | sed 's/dry_run_//; s/\.sh//').record"
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
  export LIBS_DIR="$STUB_LIBS" ROOT="$fix" \
    INPUT_DIR="$fix/workspace/input" \
    OUTPUT_DIR="$fix/workspace/output" \
    CHANGES_DIR="$fix/workspace/session-diffs" \
    SESSION_ID="cap-sess-01" DRY_RUN_IDENTITY="capability-test"
}

test_cap_healthy_rc0_record_pass() {
  local fix="$FIXTURE_DIR/cap-healthy" state="$FIXTURE_DIR/cap_healthy.state"
  ( _healthy_cap_env "$fix"; _run_probe "$PROBE_CAP" "$state" )
  assert_rc 0 "$(kv "$state" rc)" "capability healthy exit code"
  assert_eq "$(kv "$state" status)" PASS "capability record status"
  assert_eq "$(kv "$state" container)" capability-test "capability record container identity"
  assert_all_layers_pass "$state"
}
run_test test_cap_healthy_rc0_record_pass

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
  # capability-layer marker at the SANDBOX_DIR-derived shared path (a warn check)
  mkdir -p "$fix/workspace/session-diffs"
  echo "CAPABILITY_LAYER_OK" > "$fix/workspace/session-diffs/.dryrun_capability_marker"
  export LIBS_DIR="$STUB_LIBS" ROOT="$fix" \
    AGENT_HOME="$fix/agent-home" PROVIDER_NAME="custom" AGENT_CMD="sh" \
    INPUT_DIR="$fix/work/input" OUTPUT_DIR="$fix/work/output" \
    CHANGES_DIR="$fix/work/session-diffs" EXPECTED_MOUNT_TARGET="$fix/work/session-diffs" \
    SESSION_ID="reas-sess-01" DRY_RUN_IDENTITY="reasoning-test"
}

test_reas_healthy_rc0_record_pass() {
  local fix="$FIXTURE_DIR/reas-healthy" state="$FIXTURE_DIR/reas_healthy.state"
  ( _healthy_reas_env "$fix"; _run_probe "$PROBE_REAS" "$state" )
  assert_rc 0 "$(kv "$state" rc)" "reasoning healthy exit code"
  assert_eq "$(kv "$state" status)" PASS "reasoning record status"
  assert_eq "$(kv "$state" container)" reasoning-test "reasoning record container identity"
  assert_all_layers_pass "$state"
}
run_test test_reas_healthy_rc0_record_pass

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
test_init_sha_is_valid_lib() {
  source "$REPO_ROOT/src/libs/session_state.sh"
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

test_done "test_dry_run_probe"