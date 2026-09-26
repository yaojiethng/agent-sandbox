#!/usr/bin/env bash
# tests/test_stop_fail_closed.sh
# The stop fail-closed contract: a failing `docker stop` aborts the run.
#
# Covers:
#   scripts/stop.sh  --  a failing docker stop exits non-zero (no `|| true`)

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"
STOP_SCRIPT="$REPO_ROOT/scripts/stop.sh"

# Given: the docker stub reporting one container and failing the stop
# When:  stop.sh runs
# Then:  rc is non-zero, so the stop failure is not swallowed
# Asserts: docker stop stays fail-closed.
test_stop_failure_aborts() {
  local sandbox="$FIXTURE_DIR/sandbox"
  mkdir -p "$sandbox"
  local rc=0
  (
    export PATH="$STUB_DIR:$PATH"
    export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"
    export DOCKER_STUB_PS_IDS="abc123def456"
    export DOCKER_STUB_STOP_FAIL=1
    bash "$STOP_SCRIPT" --name=test-project --sandbox="$sandbox" \
      --project="$FIXTURE_DIR/project"
  ) >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "a failing docker stop aborts stop.sh (fail-closed)"
  else
    fail "stop.sh returned 0 with a failing docker stop"
  fi
}

run_test test_stop_failure_aborts

test_done test_stop_fail_closed.sh
