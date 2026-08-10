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

test_stop_uses_docker_ps() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_ps"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_stop "$FIXTURE_DIR"

  if trace_has "ps " && ! trace_has "rm "; then
    pass "stop: uses docker ps and docker stop, no docker rm"
  else
    fail "stop: expected ps+stop without rm"
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
run_test test_stop_uses_docker_ps
run_test test_stop_prune_no_compose
run_test test_stop_prune_has_system_prune
run_test test_prune_standalone_no_compose
run_test test_prune_standalone_has_system_prune

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
