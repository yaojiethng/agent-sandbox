#!/usr/bin/env bash
# tests/test_trace_build.sh
# Trace tests for agent-sandbox build subcommand.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/buildkit_progress.sh"

STUB_DIR="$TEST_DIR/../test/stubs"

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

test_build_uses_plain_progress() {
  local FIXTURE_DIR="$FIXTURE_DIR/build_progress"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  invoke_build

  # build_image uses --progress=plain on non-TTY (CI, pipes).  On TTY,
  # --progress=plain output is captured to a temp file and a single spinner
  # line is shown instead of BuildKit's multi-line blue progress display;
  # the captured output is only dumped on failure.
  if trace_has "progress=plain"; then
    pass "build: uses --progress=plain (captured on TTY, streams on non-TTY)"
  else
    fail "build: --progress=plain not found in trace"
  fi
}

test_buildkit_current_step_parses_last_step() {
  # _buildkit_current_step extracts the most recent BuildKit step header
  # from --progress=plain output.  Verify it returns the last step, not
  # intermediate steps or DONE/CACHED lines.
  local log
  log="$(mktemp)"
  cat > "$log" << 'EOF'
#1 [internal] load build definition from Dockerfile
#1 DONE 0.0s
#2 [stage-1 1/3] FROM node:22.22.3-slim
#2 DONE 0.5s
#3 [stage-1 2/3] RUN apt-get update && apt-get install -y curl
#3 0.123 Get:1 http://deb.debian.org
#3 1.456 Fetched 12.3 MB in 1s
#3 DONE 5.2s
#4 [stage-1 3/3] COPY src/ /app/
EOF

  local step
  step="$(_buildkit_current_step "$log")"

  if [[ "$step" == "COPY src/ /app/" ]]; then
    pass "buildkit_progress: extracts most recent step header"
  else
    fail "buildkit_progress: expected 'COPY src/ /app/' but got '$step'"
  fi
  rm -f "$log"
}

# _buildkit_current_step must return exit 0 (and empty string) when the log
# contains no BuildKit step header yet. Early in a build the captured log is
# still empty; under the sourced `set -euo pipefail` context a non-zero return
# would silently abort the whole poll loop (and the session start).
test_buildkit_current_step_empty_log_returns_zero() {
  local log
  log="$(mktemp)"
  : > "$log"

  local step rc
  step="$(_buildkit_current_step "$log")" || rc=$?
  rc="${rc:-0}"

  if [[ -z "$step" && "$rc" -eq 0 ]]; then
    pass "buildkit_progress: empty log yields empty step and exit 0"
  else
    fail "buildkit_progress: expected empty step and exit 0, got step='$step' rc='$rc'"
  fi
  rm -f "$log"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_buildkit_current_step_empty_log_returns_zero
run_test test_buildkit_current_step_parses_last_step
run_test test_build_inspects_images
run_test test_build_no_compose
run_test test_build_has_build_command
run_test test_build_uses_plain_progress

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
