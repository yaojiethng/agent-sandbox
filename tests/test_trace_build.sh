#!/usr/bin/env bash
# tests/test_trace_build.sh
# Trace tests for agent-sandbox build subcommand.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/buildkit_progress.sh"
# For container_sig / *_sig_sources behavior-lock tests. build.sh's main() is
# guarded, so sourcing is safe and exposes only its library functions.
source "$REPO_ROOT/scripts/build.sh"

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

# invoke_build_err — like invoke_build but captures combined stdout+stderr and
# the exit code, so tests can assert on build failure messages and semantics.
invoke_build_err() {
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/build.sh" \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      --targets="$PROVIDER_NAME" \
      "$@"
  ) 2>&1
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

# Regression (session 20260812-12 / roadmap "set -e test-harness blind spot"):
# build.sh relies on the caller setting `set -euo pipefail`; a standalone
# `bash build.sh` (as the trace tests invoke it) previously inherited the
# harness's no-`-e`, so the production failure-abort semantics were never
# exercised. build.sh now self-enables `-e` on standalone invocation. Under a
# failing docker build the result must be the descriptive `build_image: ERROR
# build FAILED` message (the session-03 fix), not a silent bare `set -e` abort.
test_build_image_failure_surfaces_descriptive_error_under_e() {
  local FIXTURE_DIR="$FIXTURE_DIR/build_fail_e"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_BUILD_RC="42"

  local out
  out=$(invoke_build_err) || true

  unset DOCKER_STUB_BUILD_RC

  if echo "$out" | grep -q "build_image: ERROR build FAILED"; then
    pass "build: failing docker build under standalone set -e surfaces descriptive error"
  else
    fail "build: expected descriptive build_image ERROR under set -e; got: $(echo "$out" | tail -3)"
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

# The (string-as-list → array) refactor is behavior-preserving at the LIST
# level: for path sets whose entries are all whitespace-free, the old unquoted
# word-split call and the new array call produce the SAME argument list. So a
# content-hash pin would NOT detect a regression to the old string-as-list
# form (identical arrays → identical hash) and would spurious-fail on any
# legitimate edit to a source file. The correct lock is the list construction
# itself: exact ordered membership. A hash test below only checks the plumbing
# runs end-to-end, not the hash's value.
test_container_sig_sources_list() {
  local -a sandbox agent
  mapfile -t sandbox < <(_sandbox_sig_sources)
  # Count check catches string-as-list regressions: `echo "a b c"` yields a
  # single element (the space-joined string), which `"${arr[*]}"` would stringify
  # identically and hide. Element count + ordered string together lock the list.
  local sandbox_expected="src/libs src/capability/entrypoint.sh src/capability/snapshot.sh docs/architecture docs/concepts"
  if [[ "${#sandbox[@]}" -ne 5 || "${sandbox[*]}" != "$sandbox_expected" ]]; then
    fail "container_sig: sandbox source list differs; got ${#sandbox[@]} elts '${sandbox[*]}'"
    return
  fi

  mapfile -t agent < <(_agent_sig_sources "$REPO_ROOT" "pi")
  local agent_expected="src/libs src/reasoning/entrypoint.sh docs/architecture docs/concepts src/reasoning/agent/skills src/reasoning/agent/prompts src/reasoning/providers/pi/config src/reasoning/providers/pi/preflight.sh"
  if [[ "${#agent[@]}" -ne 8 || "${agent[*]}" != "$agent_expected" ]]; then
    fail "container_sig: agent[pi] source list differs; got ${#agent[@]} elts '${agent[*]}'"
    return
  fi

  pass "container_sig: sandbox + agent[pi] source lists exact and ordered"
}

# End-to-end plumbing check: container_sig over the loaded sources returns a
# 64-hex hash (NOT pinned to a value — content is environmental and shifts on
# any edit). The behavior-lock for the refactor is the list test above.
test_container_sig_hashes_real_sources() {
  local -a sandbox
  mapfile -t sandbox < <(_sandbox_sig_sources)
  local sig
  sig="$(container_sig "$REPO_ROOT" "${sandbox[@]+${sandbox[@]}}")" || {
    fail "container_sig: sandbox sources hashing failed with rc=$?"
    return
  }
  if [[ "$sig" =~ ^[0-9a-f]{64}$ ]]; then
    pass "container_sig: real-sources end-to-end hash is a 64-hex string (${sig:0:12})..."
  else
    fail "container_sig: expected 64-hex hash, got '$sig'"
  fi
}

# A missing source path must fail loudly (diagnostic + non-zero), not silently
# abort (no diagnostic) and not silently return a hash of an empty file set.
# The `|| rc=$?` capture keeps this test from aborting if the harness is
# switched to `set -e` (roadmap), while still recording the non-zero status.
test_container_sig_missing_path_fails_with_diagnostic() {
  local -a sources=( "src/libs" "src/capability/DOES_NOT_EXIST" )
  local out err rc=0
  out="$(container_sig "$REPO_ROOT" "${sources[@]+${sources[@]}}" 2>/tmp/csig_err)" || rc=$?
  err="$(cat /tmp/csig_err)"
  rm -f /tmp/csig_err

  if [[ "$rc" -ne 0 && -z "$out" && "$err" == *"source path not found"* ]]; then
    pass "container_sig: missing source path fails loudly with diagnostic"
  else
    fail "container_sig: expected rc!=0 + empty output + diagnostic, got rc=$rc out='$out' err='$err'"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_buildkit_current_step_empty_log_returns_zero
run_test test_container_sig_sources_list
run_test test_container_sig_hashes_real_sources
run_test test_container_sig_missing_path_fails_with_diagnostic
run_test test_buildkit_current_step_parses_last_step
run_test test_build_inspects_images
run_test test_build_no_compose
run_test test_build_has_build_command
run_test test_build_uses_plain_progress
run_test test_build_image_failure_surfaces_descriptive_error_under_e

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
