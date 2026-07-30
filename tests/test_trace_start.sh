#!/usr/bin/env bash
# tests/test_trace_start.sh
# Trace tests for agent-sandbox start / serve subcommands.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$SCRIPT_DIR/../test/stubs"

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
}

invoke_run_agent() {
  local mode="$1"
  shift

  (
    exec() { echo "[exec overridden: $*]" >&2; return 0; }
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" "$mode" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      "$@"
  ) > /dev/null 2>&1 || true
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

test_start_standard_post_agent_uses_stop() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_post"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard"

  local stop_count down_v_count
  stop_count=$(trace_count "compose stop")
  down_v_count=$(trace_count "compose down -v")

  # compose_stop uses 'stop'; compose_destroy would use 'down -v' (not used for standard)
  if [[ "$down_v_count" -eq 0 && "$stop_count" -ge 1 ]]; then
    pass "start (standard): compose stop used (stop_count=$stop_count), no down -v"
  else
    fail "start (standard): expected stop_count>=1 down_v_count=0, got stop_count=$stop_count down_v_count=$down_v_count"
  fi
}

test_start_refresh_has_one_down_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_ref"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --reset-volume

  local count
  count=$(trace_count "compose down -v")
  if [[ "$count" -eq 1 ]]; then
    pass "start --refresh: exactly one 'compose down -v' (pre-start only)"
  else
    fail "start --refresh: expected 1 'compose down -v', got $count"
  fi
}

test_start_refresh_post_agent_uses_stop() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_ref_post"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --reset-volume

  local stop_count down_v_count
  stop_count=$(trace_count "compose stop")
  down_v_count=$(trace_count "compose down -v")

  # pre-start: compose_destroy → down -v (1)
  # post-agent: compose_stop → stop (1)
  if [[ "$down_v_count" -eq 1 && "$stop_count" -eq 1 ]]; then
    pass "start --refresh: pre-start destroy + post-agent stop (down_v=$down_v_count, stop=$stop_count)"
  else
    fail "start --refresh: expected down_v=1 stop=1, got down_v=$down_v_count stop=$stop_count"
  fi
}

test_start_rebuild_has_one_down_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_reb"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --reset-volume

  local count
  count=$(trace_count "compose down -v")
  if [[ "$count" -eq 1 ]]; then
    pass "start --rebuild: exactly one 'compose down -v' (--reset-volume forwarded)"
  else
    fail "start --rebuild: expected 1 'compose down -v', got $count"
  fi
}

test_serve_post_agent_no_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/serve_post"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "serve"

  local down_v_count
  down_v_count=$(trace_count "compose down -v")
  if [[ "$down_v_count" -eq 0 ]]; then
    pass "serve: zero 'compose down -v' (post-agent uses compose_stop)"
  else
    fail "serve: expected 0 'compose down -v', got $down_v_count"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_start_standard_no_v
run_test test_start_standard_has_compose_up
run_test test_start_standard_has_compose_run_agent
run_test test_start_standard_post_agent_uses_stop
run_test test_start_refresh_has_one_down_v
run_test test_start_refresh_post_agent_uses_stop
run_test test_start_rebuild_has_one_down_v
run_test test_serve_post_agent_no_v

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
