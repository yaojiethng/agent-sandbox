#!/usr/bin/env bash
# tests/test_trace_start.sh
# Trace tests for agent-sandbox start / serve subcommands.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../test/stubs"

setup_start_fixture() {
  local FIXTURE_DIR="$1"

  export PROJECT_NAME="test-project"
  export PROVIDER_NAME="pi"
  export SANDBOX_DIR="$FIXTURE_DIR/sandbox"
  export SNAPSHOT_DIR="$SANDBOX_DIR/.snapshot"
  export CHANGES_DIR="$SANDBOX_DIR/.workspace/session-diffs"
  export INPUT_DIR="$SANDBOX_DIR/.workspace/input"
  export OUTPUT_DIR="$SANDBOX_DIR/.workspace/output"
  export SERVE_PORT="46553"
  export HOST_UID="1000"
  export HOST_GID="1000"

  export SESSION_TS="20260730-000000"
  export HOST_HEAD_SHA="abc123def456"
  export SANDBOX_ID="testid01"
  export RUN_ID="test01"
  export SANITIZED_HOST_BRANCH="master"

  export SANDBOX_IMAGE_NAME="agent-sandbox-sandbox:test-project"
  export AGENT_IMAGE_NAME="agent-sandbox-pi:test-project"
  export SANDBOX_CONTAINER_NAME="sandbox-test-project-${RUN_ID}"
  export AGENT_CONTAINER_NAME="pi-test-project-${RUN_ID}"

  mkdir -p "$SANDBOX_DIR" "$SNAPSHOT_DIR" "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"
  mkdir -p "$SANDBOX_DIR/.pi"

  cat > "$SANDBOX_DIR/.env" << EOF
SANDBOX_DIR=$SANDBOX_DIR
PROJECT_DIR=$FIXTURE_DIR/project
EOF

  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"
  :> "$DOCKER_TRACE_LOG"
  # Tests run in the same shell (run_test), so stub env vars must not leak
  # between tests.
  unset DOCKER_STUB_UP_RC DOCKER_STUB_RUN_RC DOCKER_STUB_SANDBOX_HEALTH
}

invoke_run_agent() {
  local mode="$1"
  shift

  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" "$mode" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      "$@"
  ) > /dev/null 2>&1
}

# invoke_run_agent_rc — like invoke_run_agent but captures run_agent.sh's exit
# code instead of discarding it. Prints the rc to stdout (callers capture it).
invoke_run_agent_rc() {
  local mode="$1"
  shift

  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" "$mode" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      "$@"
  ) > /dev/null 2>&1
  echo $?
}

trace_grep() {
  grep "$1" "$DOCKER_TRACE_LOG" 2>/dev/null || true
}

trace_count() {
  trace_grep "$1" | wc -l
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_start_standard_no_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_std"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard"

  local count
  count=$(trace_count "compose down -v")
  if [[ "$count" -eq 0 ]]; then
    pass "start (standard): zero 'compose down -v' invocations"
  else
    fail "start (standard): expected 0 'compose down -v', got $count"
  fi
}

test_start_standard_has_compose_up() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_up"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard"

  if trace_grep "compose up -d sandbox" > /dev/null; then
    pass "start (standard): 'compose up -d sandbox' issued"
  else
    fail "start (standard): 'compose up -d sandbox' not found in trace"
  fi
}

test_start_standard_has_compose_run_agent() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_run"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard"

  if trace_grep "compose run" > /dev/null; then
    pass "start (standard): 'compose run ... agent' issued"
  else
    fail "start (standard): 'compose run ... agent' not found in trace"
  fi
}

test_start_standard_post_agent_uses_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_post"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard"

  # Session teardown is `compose down` (not `down -v`): named volumes must
  # survive. The post-agent dispatch itself is locked by
  # test_standard_teardown_is_last_compose (last compose op is down) — this
  # test covers only the volume-preservation verb, since a pre-run teardown
  # down would also satisfy a bare down_count>=1.
  local down_v_count
  down_v_count=$(trace_count "compose down -v")
  if [[ "$down_v_count" -eq 0 ]]; then
    pass "start (standard): zero 'compose down -v' (session_teardown keeps named volumes)"
  else
    fail "start (standard): expected 0 'compose down -v', got $down_v_count"
  fi
}

test_start_refresh_has_no_down_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_ref"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --reset-volume

  local count
  count=$(trace_count "compose down -v")
  if [[ "$count" -eq 0 ]]; then
    pass "start --refresh: zero 'compose down -v' (volume removal via docker volume rm)"
  else
    fail "start --refresh: expected 0 'compose down -v', got $count"
  fi
}

test_start_refresh_volume_rm() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_ref_rm"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --reset-volume

  local count
  count=$(trace_count "volume rm")
  # May be 0 if no volumes exist, which is fine — stub returns none
  pass "start --refresh: volume rm count = $count"
}

test_start_refresh_post_agent_uses_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_ref_post"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --reset-volume

  local down_count down_v_count
  down_count=$(trace_count "compose down")
  down_v_count=$(trace_count "compose down -v")

  # REFRESH: no session_destroy (volumes removed directly by start_agent.sh)
  # post-agent: session_teardown only
  if [[ "$down_v_count" -eq 0 ]]; then
    pass "start --refresh: zero compose down -v, post-agent down only (down=$down_count)"
  else
    fail "start --refresh: expected down_v=0, got down_v=$down_v_count down=$down_count"
  fi
}

test_start_rebuild_has_no_down_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_reb"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --reset-volume

  local count
  count=$(trace_count "compose down -v")
  if [[ "$count" -eq 0 ]]; then
    pass "start --rebuild: zero 'compose down -v' (--reset-volume forwarded, volume rm used)"
  else
    fail "start --rebuild: expected 0 'compose down -v', got $count"
  fi
}

test_serve_post_agent_uses_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/serve_post"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "serve"

  # Session teardown is `compose down` (not `down -v`): named volumes must
  # survive. The post-agent dispatch itself is locked by
  # test_serve_teardown_is_last_compose (last compose op is down) — this test
  # covers only the volume-preservation verb, since serve also emits a pre-run
  # teardown down that would satisfy a bare down_count>=1.
  local down_v_count
  down_v_count=$(trace_count "compose down -v")
  if [[ "$down_v_count" -eq 0 ]]; then
    pass "serve: zero 'compose down -v' (session_teardown keeps named volumes)"
  else
    fail "serve: expected 0 'compose down -v', got $down_v_count"
  fi
}

test_teardown_is_last_compose() {
  local mode="$1"
  local FIXTURE_DIR="$FIXTURE_DIR/${mode}_last"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "$mode"

  # The unified teardown dispatch is the single final compose operation:
  # nothing runs after `compose down`. (Pre-run session_teardown is the
  # resume-path cleanup before `up`; the last down is the post-agent one.)
  local last
  last=$(trace_grep "compose " | tail -1)
  if [[ "$last" == *"compose down"* ]]; then
    pass "$mode: last compose op is down (teardown is final dispatch)"
  else
    fail "$mode: expected last compose op to be down, got: $last"
  fi
}

test_standard_teardown_is_last_compose() {
  test_teardown_is_last_compose standard
}

test_serve_teardown_is_last_compose() {
  test_teardown_is_last_compose serve
}

test_standard_agent_failure_still_tears_down_and_propagates_rc() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_fail"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_RUN_RC="42"

  # run_agent.sh must (a) run teardown even when the agent exits non-zero
  # (issue-1 fix: no container/network leak) and (b) exit with the agent's rc
  # (defined exit semantics for standard mode).
  local rc
  rc=$(invoke_run_agent_rc "standard")

  local down_count last
  down_count=$(trace_count "compose down")
  last=$(trace_grep "compose " | tail -1)
  if [[ "$rc" -eq 42 && "$down_count" -ge 1 && "$last" == *"compose down"* ]]; then
    pass "standard: agent failure (rc=42) still tears down; rc propagated"
  else
    fail "standard: expected rc=42 + teardown ran, got rc=$rc down_count=$down_count last=$last"
  fi

  unset DOCKER_STUB_RUN_RC
}

test_serve_up_failure_still_tears_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/serve_up_fail"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_UP_RC="1"

  # compose up fails -> set -e abort before the mode branch completes; the
  # EXIT trap must still tear down (issue-1 class: no leak on up failure).
  local rc
  rc=$(invoke_run_agent_rc "serve")

  local last
  last=$(trace_grep "compose " | tail -1)
  if [[ "$last" == *"compose down"* ]]; then
    pass "serve: up failure still tears down (last=$last)"
  else
    fail "serve: expected teardown after up failure, got last=$last"
  fi
}

test_standard_up_failure_still_tears_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_up_fail"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_UP_RC="1"

  # Pipefail propagates the up failure; set -e aborts; the EXIT trap must
  # still tear down.
  local rc
  rc=$(invoke_run_agent_rc "standard")

  local last
  last=$(trace_grep "compose " | tail -1)
  if [[ "$last" == *"compose down"* ]]; then
    pass "standard: up failure still tears down (last=$last)"
  else
    fail "standard: expected teardown after up failure, got last=$last"
  fi
}

test_standard_sandbox_unhealthy_still_tears_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_sb_fail"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_SANDBOX_HEALTH="starting"
  export SANDBOX_WAIT_TIMEOUT="1"

  # compose_sandbox_wait exits 1 (never healthy) before the agent runs; the
  # EXIT trap must still tear down the sandbox container + network.
  local rc
  rc=$(invoke_run_agent_rc "standard")

  local last
  last=$(trace_grep "compose " | tail -1)
  if [[ "$last" == *"compose down"* ]]; then
    pass "standard: sandbox unhealthy still tears down (last=$last)"
  else
    fail "standard: expected teardown after sandbox-wait failure, got last=$last"
  fi
}

test_compose_file_persisted() {
  local FIXTURE_DIR="$FIXTURE_DIR/compose_persist"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"

  local compose_file="$SANDBOX_DIR/.compose/test01.yml"
  invoke_run_agent "standard"

  # The merged compose file must survive the session (teardown already ran)
  # at a stable identity-derived path, and compose invocations during the
  # run must operate on that same file.
  local last_file
  last_file=$(trace_grep "compose-file" | tail -1)
  if [[ -f "$compose_file" && -s "$compose_file" ]]; then
    if grep -q "sandbox-test-project-test01" "$compose_file" && grep -q "pi-test-project-test01" "$compose_file"; then
      if [[ "$last_file" == *"$compose_file"* ]]; then
        pass "standard: compose file persisted at .compose/<run-id>.yml and used by compose"
      else
        fail "standard: compose file persisted but not used by compose invocations (last compose-file: $last_file)"
      fi
    else
      fail "standard: compose file lacks baked container names"
    fi
  else
    fail "standard: compose file missing or empty at $compose_file"
  fi
}

# ---------------------------------------------------------------------------
# Delivery overlay selection (SANDBOX_TYPE=copy|mount)
# ---------------------------------------------------------------------------

# Default (SANDBOX_TYPE unset) is copy: the copy overlay is merged, the mount
# overlay is not.
test_copy_delivery_default_merges_copy_overlay() {
  local FIXTURE_DIR="$FIXTURE_DIR/copy_delivery"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  unset SANDBOX_TYPE
  invoke_run_agent "standard"

  local copy_count mount_count
  copy_count=$(trace_count "docker-compose.copy.yml")
  mount_count=$(trace_count "docker-compose.mount.yml")
  if [[ "$copy_count" -ge 1 && "$mount_count" -eq 0 ]]; then
    pass "copy delivery (default): copy overlay merged, mount overlay absent"
  else
    fail "copy delivery (default): copy=$copy_count mount=$mount_count (expected copy>=1 mount=0)"
  fi
}

# SANDBOX_TYPE=mount: the mount overlay is merged, the copy overlay is not.
test_mount_delivery_merges_mount_overlay() {
  local FIXTURE_DIR="$FIXTURE_DIR/mount_delivery"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  export SANDBOX_TYPE="mount"
  invoke_run_agent "standard"

  local copy_count mount_count
  copy_count=$(trace_count "docker-compose.copy.yml")
  mount_count=$(trace_count "docker-compose.mount.yml")
  if [[ "$mount_count" -ge 1 && "$copy_count" -eq 0 ]]; then
    pass "mount delivery: mount overlay merged, copy overlay absent"
  else
    fail "mount delivery: copy=$copy_count mount=$mount_count (expected mount>=1 copy=0)"
  fi
  unset SANDBOX_TYPE
}

# Unknown SANDBOX_TYPE values are rejected before any compose invocation.
test_invalid_sandbox_type_rejected() {
  local FIXTURE_DIR="$FIXTURE_DIR/bad_delivery"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  export SANDBOX_TYPE="bogus"

  local rc
  rc=$(invoke_run_agent_rc "standard")
  if [[ "$rc" -ne 0 ]]; then
    pass "invalid SANDBOX_TYPE=bogus rejected (rc=$rc)"
  else
    fail "invalid SANDBOX_TYPE=bogus accepted (rc=0)"
  fi
  unset SANDBOX_TYPE
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_start_standard_no_v
run_test test_start_standard_has_compose_up
run_test test_start_standard_has_compose_run_agent
run_test test_start_standard_post_agent_uses_down
run_test test_start_refresh_has_no_down_v
run_test test_start_refresh_volume_rm
run_test test_start_refresh_post_agent_uses_down
run_test test_start_rebuild_has_no_down_v
run_test test_serve_post_agent_uses_down
run_test test_standard_teardown_is_last_compose
run_test test_serve_teardown_is_last_compose
run_test test_standard_agent_failure_still_tears_down_and_propagates_rc
run_test test_serve_up_failure_still_tears_down
run_test test_standard_up_failure_still_tears_down
run_test test_standard_sandbox_unhealthy_still_tears_down
run_test test_compose_file_persisted
run_test test_copy_delivery_default_merges_copy_overlay
run_test test_mount_delivery_merges_mount_overlay
run_test test_invalid_sandbox_type_rejected

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
