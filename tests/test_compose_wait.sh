#!/usr/bin/env bash
# tests/test_compose_wait.sh
# Unit tests for src/build/compose.sh -- compose_sandbox_wait.
#
# Covers:
#   compose_sandbox_wait  --  healthy success, the exited/dead fast-fail, and
#                             the container name it polls.
#   compose_args          --  project-name lowercasing, character sanitation,
#                             the session-id suffix, and the sandbox-dir hash fallback.

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

# Given: a project name, sandbox dir, generated file, and session id
# When:  compose_args runs
# Then:  COMPOSE_ARGS carries the lowercased, session-scoped project name, the project directory, and the -f file
# Asserts: the compose namespace a session's volume, network, and containers are addressed by
test_compose_args_builds_session_namespace() {
  ( compose_args "proj" "/tmp/sbx" "/gen/session.yml" "abc123"
    [[ "${COMPOSE_ARGS[0]}" == "--project-name" \
       && "${COMPOSE_ARGS[1]}" == "proj-abc123" \
       && "${COMPOSE_ARGS[2]}" == "--project-directory" \
       && "${COMPOSE_ARGS[3]}" == "/tmp/sbx" \
       && "${COMPOSE_ARGS[4]}" == "-f" \
       && "${COMPOSE_ARGS[5]}" == "/gen/session.yml" ]] )
  if [[ $? -eq 0 ]]; then
    pass "compose_args builds the session-scoped namespace and -f args"
  else
    fail "compose_args namespace wrong: ${COMPOSE_ARGS[*]:-unset}"
  fi
}

# Given: an upper-case project name
# When:  compose_args runs
# Then:  the project-name value is lowercased
# Asserts: docker resource names stay lower case
test_compose_args_lowercases_project() {
  ( compose_args "UPPER" "/tmp/sbx" "/gen/s.yml" "sid"
    [[ "${COMPOSE_ARGS[1]}" == "upper-sid" ]] )
  if [[ $? -eq 0 ]]; then
    pass "compose_args lowercases the project name"
  else
    fail "compose_args did not lowercase the project name"
  fi
}

# Given: a project name carrying characters outside [a-z0-9-]
# When:  compose_args runs
# Then:  each offending character becomes a hyphen
# Asserts: a project name cannot inject an invalid docker name character
test_compose_args_sanitises_project() {
  ( compose_args "a_b.c" "/tmp/sbx" "/gen/s.yml" "sid"
    [[ "${COMPOSE_ARGS[1]}" == "a-b-c-sid" ]] )
  if [[ $? -eq 0 ]]; then
    pass "compose_args sanitises non-alphanumeric project-name characters"
  else
    fail "compose_args sanitation wrong: ${COMPOSE_ARGS[1]:-unset}"
  fi
}

# Given: no session id
# When:  compose_args runs
# Then:  the project name ends with the first six hex of the sandbox dir's sha256
# Asserts: the documented hash fallback keeps two sessions on one project apart
test_compose_args_hash_fallback_without_session() {
  local expected
  expected="proj-$(echo "/tmp/sbx" | sha256sum | cut -c1-6)"
  ( compose_args "proj" "/tmp/sbx" "/gen/s.yml"
    [[ "${COMPOSE_ARGS[1]}" == "$expected" ]] )
  if [[ $? -eq 0 ]]; then
    pass "compose_args falls back to the sandbox-dir hash without a session id"
  else
    fail "compose_args hash fallback wrong: ${COMPOSE_ARGS[1]:-unset} expected $expected"
  fi
}

run_test test_compose_sandbox_wait_healthy
run_test test_compose_sandbox_wait_exited_fails_fast
run_test test_compose_sandbox_wait_dead_fails_fast
run_test test_compose_sandbox_wait_timeout
run_test test_compose_args_builds_session_namespace
run_test test_compose_args_lowercases_project
run_test test_compose_args_sanitises_project
run_test test_compose_args_hash_fallback_without_session

test_done test_compose_wait
