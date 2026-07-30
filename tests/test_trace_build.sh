#!/usr/bin/env bash
# tests/test_trace_build.sh
# Trace tests for agent-sandbox build subcommand.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$SCRIPT_DIR/../test/stubs"

setup_build_fixture() {
  local FIXTURE_DIR="$1"
  export PROJECT_NAME="test-project"
  export PROVIDER_NAME="pi"
  export SANDBOX_DIR="$FIXTURE_DIR/sandbox"
  export PROJECT_DIR="$FIXTURE_DIR/project"
  export HOST_UID="1000"
  export HOST_GID="1000"

  mkdir -p "$SANDBOX_DIR" "$PROJECT_DIR"
  git -C "$PROJECT_DIR" init --quiet
  git -C "$PROJECT_DIR" config user.email "test@test"
  git -C "$PROJECT_DIR" config user.name "Test"
  echo "test" > "$PROJECT_DIR/README.md"
  git -C "$PROJECT_DIR" add -A
  git -C "$PROJECT_DIR" commit -m "init" --quiet

  cat > "$SANDBOX_DIR/.env" << EOF
SANDBOX_DIR=$SANDBOX_DIR
PROJECT_DIR=$PROJECT_DIR
EOF

  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"
  :> "$DOCKER_TRACE_LOG"
}

invoke_build() {
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/build.sh" \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      --targets="$PROVIDER_NAME" \
      "$@"
  ) > /dev/null 2>&1 || true
}

trace_has() {
  grep -q "$1" "$DOCKER_TRACE_LOG" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_build_inspects_images() {
  local FIXTURE_DIR="$FIXTURE_DIR/build_inspect"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  invoke_build

  if trace_has "image inspect"; then
    pass "build: docker image inspect issued"
  else
    fail "build: docker image inspect not found in trace"
  fi
}

test_build_no_compose() {
  local FIXTURE_DIR="$FIXTURE_DIR/build_noc"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  invoke_build

  if trace_has "compose"; then
    fail "build: docker compose should not be invoked"
  else
    pass "build: no docker compose invocations"
  fi
}

test_build_has_build_command() {
  local FIXTURE_DIR="$FIXTURE_DIR/build_cmd"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  invoke_build

  if trace_has "build "; then
    pass "build: docker build issued"
  else
    fail "build: docker build not found in trace"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_build_inspects_images
run_test test_build_no_compose
run_test test_build_has_build_command

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
