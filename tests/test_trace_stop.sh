#!/usr/bin/env bash
# tests/test_trace_stop.sh
# Trace tests for agent-sandbox stop / prune subcommands.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../test/stubs"

setup_stop_fixture() {
  local FIXTURE_DIR="$1"
  export PROJECT_NAME="test-project"
  export SANDBOX_DIR="$FIXTURE_DIR/sandbox"
  mkdir -p "$SANDBOX_DIR"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"
  :> "$DOCKER_TRACE_LOG"
  # Tests run in the same shell (run_test), so stub-ID vars must not leak
  # between tests.
  unset DOCKER_STUB_PS_IDS DOCKER_STUB_NETWORK_IDS DOCKER_STUB_FAIL_PS
}

invoke_stop() {
  local FIXTURE_DIR="$1"; shift
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/stop.sh" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      "$@"
  ) > /dev/null 2>&1 || true
}

invoke_prune() {
  local FIXTURE_DIR="$1"
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/prune.sh" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR"
  ) > /dev/null 2>&1 || true
}

trace_has() {
  grep -q "$1" "$DOCKER_TRACE_LOG" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_stop_no_compose() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_nc"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_stop "$FIXTURE_DIR"

  if trace_has "compose"; then
    fail "stop: docker compose should not be invoked"
  else
    pass "stop: no docker compose invocations"
  fi
}

test_stop_no_containers_does_not_teardown() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_none"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_stop "$FIXTURE_DIR"

  # Stub ps -aq returns nothing by default: no containers, no teardown.
  if trace_has "ps " && ! trace_has "rm "; then
    pass "stop: no containers -> ps only, no rm"
  else
    fail "stop: expected ps without rm when no containers"
  fi
}

test_stop_removes_containers() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_rm"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_PS_IDS="abc123def456 fedcba654321"
  invoke_stop "$FIXTURE_DIR"

  if trace_has "stop abc123def456" && trace_has "rm abc123def456"; then
    pass "stop: containers stopped and removed"
  else
    fail "stop: expected stop+rm for found containers"
  fi
}

test_stop_removes_networks() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_net"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_NETWORK_IDS="net1 net2"
  invoke_stop "$FIXTURE_DIR"

  if trace_has "network rm net1"; then
    pass "stop: session networks removed by label"
  else
    fail "stop: expected network rm for found networks"
  fi
}

test_stop_docker_failure_aborts() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_fail"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_FAIL_PS=1

  # stop.sh must abort when docker ps fails (set -e semantics), not
  # silently continue as if no containers exist.
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/stop.sh" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR"
  ) > /dev/null 2>&1
  local rc=$?

  if [[ "$rc" -ne 0 ]]; then
    pass "stop: docker ps failure aborts the script (rc=$rc)"
  else
    fail "stop: expected nonzero rc on docker ps failure, got 0"
  fi
}

test_stop_prune_no_compose() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_pr_nc"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_stop "$FIXTURE_DIR" --prune

  if trace_has "compose"; then
    fail "stop --prune: docker compose should not be invoked"
  else
    pass "stop --prune: no docker compose invocations"
  fi
}

test_stop_prune_has_system_prune() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_pr_sp"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_stop "$FIXTURE_DIR" --prune

  if trace_has "system prune"; then
    pass "stop --prune: docker system prune invoked"
  else
    fail "stop --prune: docker system prune not found in trace"
  fi
}

test_prune_standalone_no_compose() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_sa_nc"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_prune "$FIXTURE_DIR"

  if trace_has "compose"; then
    fail "prune (standalone): docker compose should not be invoked"
  else
    pass "prune (standalone): no docker compose invocations"
  fi
}

test_prune_standalone_has_system_prune() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_sa_sp"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_prune "$FIXTURE_DIR"

  if trace_has "system prune"; then
    pass "prune (standalone): docker system prune invoked"
  else
    fail "prune (standalone): docker system prune not found in trace"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_stop_no_compose
run_test test_stop_no_containers_does_not_teardown
run_test test_stop_removes_containers
run_test test_stop_removes_networks
run_test test_stop_docker_failure_aborts
run_test test_stop_prune_no_compose
run_test test_stop_prune_has_system_prune
run_test test_prune_standalone_no_compose
run_test test_prune_standalone_has_system_prune

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
