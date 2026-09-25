#!/usr/bin/env bash
# tests/test_compose_wait.sh
# Unit tests for src/build/compose.sh -- compose_sandbox_wait.
#
# Covers:
#   compose_sandbox_wait  --  healthy success, the exited/dead fast-fail, and
#                             the container name it polls.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/build/compose.sh"

# --- docker double -----------------------------------------------------------
# compose_sandbox_wait calls `docker inspect --format <template> <container>`.
# A shell function shadows the stub so each branch returns a controlled value
# and records the container name it was asked about. The poll runs in a command
# substitution, so the record goes to a file the parent can read back.
docker() {
  if [[ "${1:-}" == "inspect" ]]; then
    [[ -n "${DOCKER_WAIT_LOG:-}" ]] && printf '%s\n' "${4:-}" >> "$DOCKER_WAIT_LOG"
    case "${3:-}" in
      *Health.Status*) echo "${DOCKER_WAIT_HEALTH:-healthy}" ;;
      *State.Status*)  echo "${DOCKER_WAIT_STATE:-running}" ;;
    esac
    return 0
  fi
  return 0
}

# Given: a container that reports healthy
# When:  compose_sandbox_wait runs
# Then:  it returns 0 and polls SANDBOX_CONTAINER_NAME
# Asserts: the success path and the polled container identity.
test_compose_sandbox_wait_healthy() {
  export SANDBOX_CONTAINER_NAME="sandbox-proj-abc123"
  export DOCKER_WAIT_HEALTH="healthy"
  export DOCKER_WAIT_STATE="running"
  export DOCKER_WAIT_LOG="$FIXTURE_DIR/docker_calls"
  : > "$DOCKER_WAIT_LOG"
  local rc=0
  compose_sandbox_wait >/dev/null 2>&1 || rc=$?
  assert_rc 0 "$rc" "compose_sandbox_wait returns 0 when healthy"
  assert_contains "$(cat "$DOCKER_WAIT_LOG")" "sandbox-proj-abc123" \
    "compose_sandbox_wait polls SANDBOX_CONTAINER_NAME"
}

# Given: a container that has exited before becoming healthy
# When:  compose_sandbox_wait runs
# Then:  it fails fast with rc 1 and names the exited state
# Asserts: the exited fast-fail, before the timeout budget elapses.
test_compose_sandbox_wait_exited_fails_fast() {
  export SANDBOX_CONTAINER_NAME="sandbox-proj-abc123"
  export DOCKER_WAIT_HEALTH="starting"
  export DOCKER_WAIT_STATE="exited"
  export SANDBOX_WAIT_TIMEOUT="30"
  local out rc=0
  out=$(compose_sandbox_wait 2>&1) || rc=$?
  assert_rc 1 "$rc" "compose_sandbox_wait fails fast on an exited container"
  assert_contains "$out" "exited before becoming healthy" "compose_sandbox_wait reports the exited state"
}

# Given: a container in the dead state
# When:  compose_sandbox_wait runs
# Then:  it fails fast with rc 1
# Asserts: the dead branch shares the exited fast-fail.
test_compose_sandbox_wait_dead_fails_fast() {
  export SANDBOX_CONTAINER_NAME="sandbox-proj-abc123"
  export DOCKER_WAIT_HEALTH="starting"
  export DOCKER_WAIT_STATE="dead"
  export SANDBOX_WAIT_TIMEOUT="30"
  local rc=0
  compose_sandbox_wait >/dev/null 2>&1 || rc=$?
  assert_rc 1 "$rc" "compose_sandbox_wait fails fast on a dead container"
}

# Given: a container that never becomes healthy and a one-second budget
# When:  compose_sandbox_wait runs
# Then:  it returns 1 and reports the timeout
# Asserts: the timeout boundary.
test_compose_sandbox_wait_timeout() {
  export SANDBOX_CONTAINER_NAME="sandbox-proj-abc123"
  export DOCKER_WAIT_HEALTH="starting"
  export DOCKER_WAIT_STATE="running"
  export SANDBOX_WAIT_TIMEOUT="1"
  local out rc=0
  out=$(compose_sandbox_wait 2>&1) || rc=$?
  assert_rc 1 "$rc" "compose_sandbox_wait returns 1 on timeout"
  assert_contains "$out" "did not become healthy within 1s" "compose_sandbox_wait reports the timeout"
}

run_test test_compose_sandbox_wait_healthy
run_test test_compose_sandbox_wait_exited_fails_fast
run_test test_compose_sandbox_wait_dead_fails_fast
run_test test_compose_sandbox_wait_timeout

test_done test_compose_wait
