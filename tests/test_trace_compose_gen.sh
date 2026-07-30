#!/usr/bin/env bash
# tests/test_trace_compose_gen.sh
# Trace test: compose_generate output must not contain injected name: lines.
# Verifies the compose project name leak fix.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$SCRIPT_DIR/../test/stubs"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup_fixture() {
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
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"

  mkdir -p "$SANDBOX_DIR" "$SNAPSHOT_DIR" "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR" "$SANDBOX_DIR/.pi"

  :> "$DOCKER_TRACE_LOG"
}

# Source compose.sh functions and run compose_generate against the stub
run_compose_generate() {
  local output_file="$1"
  (
    source "$REPO_ROOT/src/build/image.sh"
    source "$REPO_ROOT/scripts/build.sh"
    source "$REPO_ROOT/src/build/compose.sh"
    export PATH="$STUB_DIR:$PATH"

    local compose_files=("$REPO_ROOT/src/build/docker-compose.yml")
    local provider_overlay="$REPO_ROOT/src/reasoning/providers/pi/docker-compose.pi.yml"
    [[ -f "$provider_overlay" ]] && compose_files+=("$provider_overlay")

    compose_generate "$output_file" "$PROJECT_NAME" "$PROVIDER_NAME" "${compose_files[@]}"
  ) > /dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_no_name_lines_in_output() {
  local FIXTURE_DIR="$FIXTURE_DIR/nonames"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  local out="$FIXTURE_DIR/compose-output.yml"
  run_compose_generate "$out"

  if [[ ! -f "$out" ]]; then
    fail "compose_generate did not produce output file"
    return
  fi

  local name_lines
  name_lines=$(grep -c '^[[:space:]]*name:' "$out" 2>/dev/null) || name_lines=0

  if [[ "$name_lines" -eq 0 ]]; then
    pass "generated compose file has zero 'name:' lines"
  else
    fail "generated compose file has $name_lines 'name:' line(s) (expected 0)"
    grep '^[[:space:]]*name:' "$out" >&2
  fi
}

test_output_is_valid_yaml() {
  local FIXTURE_DIR="$FIXTURE_DIR/validyaml"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  local out="$FIXTURE_DIR/compose-output.yml"
  run_compose_generate "$out"

  if [[ ! -f "$out" ]]; then
    fail "compose_generate did not produce output file"
    return
  fi

  # Check that key sections are present (not a comprehensive YAML parse)
  if grep -q 'services:' "$out" && grep -q 'volumes:' "$out"; then
    pass "generated compose file contains services and volumes sections"
  else
    fail "generated compose file missing expected sections"
  fi
}

test_stub_docker_config_preserves_structure() {
  local FIXTURE_DIR="$FIXTURE_DIR/configstruct"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  # Verify the stub's compose config output doesn't have name: lines either
  # (the stub returns the first input file, which shouldn't have name: lines)
  local staging_dir
  staging_dir=$(mktemp -d)
  cp "$REPO_ROOT/src/build/docker-compose.yml" "$staging_dir/00-test.yml"

  local out
  out=$(PATH="$STUB_DIR:$PATH" docker compose -f "$staging_dir/00-test.yml" config --no-interpolate 2>/dev/null || true)

  rm -rf "$staging_dir"

  # Stub returns the file directly; source templates have no name: lines
  # But container_name: has "name:" as a substring — confirm grep doesn't match it
  local name_lines
  name_lines=$(echo "$out" | grep -c '^[[:space:]]*name:') || name_lines=0

  if [[ "$name_lines" -eq 0 ]]; then
    pass "stub compose config output has no 'name:' lines"
  else
    fail "stub compose config output has $name_lines 'name:' line(s)"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_no_name_lines_in_output
run_test test_output_is_valid_yaml
run_test test_stub_docker_config_preserves_structure

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
