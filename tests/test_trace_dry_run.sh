#!/usr/bin/env bash
# tests/test_trace_dry_run.sh
# Trace tests for agent-sandbox dry-run subcommand.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$SCRIPT_DIR/../test/stubs"

setup_dry_run_fixture() {
  local FIXTURE_DIR="$1"

  export PROJECT_NAME="test-project"
  export PROVIDER_NAME="pi"
  export SANDBOX_DIR="$FIXTURE_DIR/sandbox"
  export SNAPSHOT_DIR="$SANDBOX_DIR/.snapshot"
  export CHANGES_DIR="$SANDBOX_DIR/.workspace/session-diffs"
  export INPUT_DIR="$SANDBOX_DIR/.workspace/input"
  export OUTPUT_DIR="$SANDBOX_DIR/.workspace/output"
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
}

invoke_dry_run() {
  (
    exec() { echo "[exec overridden: $*]" >&2; return 0; }
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" "dry-run" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      "$@"
  ) > /dev/null 2>&1 || true
}

trace_has() {
  grep -q "$1" "$DOCKER_TRACE_LOG" 2>/dev/null
}

trace_count() {
  local c
  c=$(grep -c "$1" "$DOCKER_TRACE_LOG" 2>/dev/null) || c=0
  echo "$c"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_dry_run_has_compose_up() {
  local FIXTURE_DIR="$FIXTURE_DIR/dry_up"
  mkdir -p "$FIXTURE_DIR"
  setup_dry_run_fixture "$FIXTURE_DIR"
  invoke_dry_run

  if trace_has "compose up"; then
    pass "dry-run: 'compose up -d' issued"
  else
    fail "dry-run: 'compose up -d' not found in trace"
  fi
}

test_dry_run_has_compose_exec() {
  local FIXTURE_DIR="$FIXTURE_DIR/dry_exec"
  mkdir -p "$FIXTURE_DIR"
  setup_dry_run_fixture "$FIXTURE_DIR"
  invoke_dry_run

  if trace_has "compose exec"; then
    pass "dry-run: 'compose exec' issued"
  else
    fail "dry-run: 'compose exec' not found in trace"
  fi
}

test_dry_run_no_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/dry_nov"
  mkdir -p "$FIXTURE_DIR"
  setup_dry_run_fixture "$FIXTURE_DIR"
  invoke_dry_run

  local count
  count=$(trace_count "compose down -v")
  if [[ "$count" -eq 0 ]]; then
    pass "dry-run: zero 'compose down -v' (no --reset-volume)"
  else
    fail "dry-run: expected 0 'compose down -v', got $count"
  fi
}

test_dry_run_refresh_has_down_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/dry_ref"
  mkdir -p "$FIXTURE_DIR"
  setup_dry_run_fixture "$FIXTURE_DIR"
  invoke_dry_run --reset-volume

  local count
  count=$(trace_count "compose down -v")
  if [[ "$count" -ge 1 ]]; then
    pass "dry-run --refresh: 'compose down -v' issued ($count time(s))"
  else
    fail "dry-run --refresh: expected 'compose down -v', got $count"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_dry_run_has_compose_up
run_test test_dry_run_has_compose_exec
run_test test_dry_run_no_v
run_test test_dry_run_refresh_has_down_v

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
