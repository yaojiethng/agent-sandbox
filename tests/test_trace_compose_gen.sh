#!/usr/bin/env bash
# tests/test_trace_compose_gen.sh
# Trace test: compose_generate output must not contain injected name: lines.
# Verifies the compose project name leak fix.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup_fixture() {
  local FIXTURE_DIR="$1"
  export PROJECT_NAME="test-project"
  export PROVIDER_NAME="pi"
  export SANDBOX_DIR="$FIXTURE_DIR/sandbox"
  export WORKTREE_DIR="$SANDBOX_DIR/.worktree"
  export CHANGES_DIR="$SANDBOX_DIR/.workspace/session-diffs"
  export INPUT_DIR="$SANDBOX_DIR/.workspace/input"
  export OUTPUT_DIR="$SANDBOX_DIR/.workspace/output"
  export HOST_UID="1000"
  export HOST_GID="1000"
  export SESSION_TS="20260730-000000"
  export HOST_HEAD_SHA="abc123def456"
  export SESSION_ID="test01"
  export SANITIZED_HOST_BRANCH="master"
  export SANDBOX_IMAGE_NAME="agent-sandbox-sandbox:test-project"
  export AGENT_IMAGE_NAME="agent-sandbox-pi:test-project"
  export SANDBOX_CONTAINER_NAME="sandbox-test-project-${SESSION_ID}"
  export AGENT_CONTAINER_NAME="pi-test-project-${SESSION_ID}"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"

  mkdir -p "$SANDBOX_DIR" "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR" "$SANDBOX_DIR/.pi"

  :> "$DOCKER_TRACE_LOG"
}

# Source compose.sh functions and run compose_generate against the stub
run_compose_generate() {
  local output_file="$1"
  local delivery="${2:-copy}"
  (
    source "$REPO_ROOT/src/build/image.sh"
    source "$REPO_ROOT/scripts/build.sh"
    source "$REPO_ROOT/src/build/compose.sh"
    export PATH="$STUB_DIR:$PATH"

    local compose_files=("$REPO_ROOT/src/build/docker-compose.yml")
    if [[ "$delivery" == "copy" ]]; then
      compose_files+=("$REPO_ROOT/src/build/docker-compose.copy.yml")
    else
      compose_files+=("$REPO_ROOT/src/build/docker-compose.mount.yml")
    fi
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

  # Check that key sections are present. The stub's compose config returns
  # the first input file (the base template), so the named sandbox volume
  # (declared in the copy overlay) is not part of the stub-merged output  -- 
  # the volumes section is asserted statically against the overlay files.
  if grep -q 'services:' "$out" && grep -q 'x-session-labels:' "$out"; then
    pass "generated compose file contains services and session-labels sections"
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
  # But container_name: has "name:" as a substring  --  confirm grep doesn't match it
  local name_lines
  name_lines=$(echo "$out" | grep -c '^[[:space:]]*name:') || name_lines=0

  if [[ "$name_lines" -eq 0 ]]; then
    pass "stub compose config output has no 'name:' lines"
  else
    fail "stub compose config output has $name_lines 'name:' line(s)"
  fi
}

# ---------------------------------------------------------------------------
# Delivery overlay file-set tests
# ---------------------------------------------------------------------------

# The base template must not carry copy-only wiring: the named sandbox volume
# lives in the copy overlay so bind-mount compose never inherits it.
test_base_template_has_no_copy_only_wiring() {
  local base="$REPO_ROOT/src/build/docker-compose.yml"
  local copy_only=0
  grep -q 'SNAPSHOT_DIR' "$base" && copy_only=1
  grep -q 'sandbox-data' "$base" && copy_only=1
  grep -q '/home/agentuser/.snapshot' "$base" && copy_only=1

  if [[ "$copy_only" -eq 0 ]]; then
    pass "base template free of copy-only wiring (SNAPSHOT_DIR, named sandbox volume)"
  else
    fail "base template still carries copy-only wiring"
  fi
}

# The copy overlay carries the named volume and copy delivery type, and no
# snapshot mount (content is host-side seeded via docker cp).
test_copy_overlay_carries_volume_no_snapshot_mount() {
  local overlay="$REPO_ROOT/src/build/docker-compose.copy.yml"

  if grep -q 'sandbox-data' "$overlay" \
      && grep -q 'SANDBOX_TYPE=copy' "$overlay" \
      && ! grep -q 'SNAPSHOT_DIR' "$overlay" \
      && ! grep -q '/home/agentuser/.snapshot' "$overlay"; then
    pass "copy overlay carries named volume + SANDBOX_TYPE=copy, no snapshot mount"
  else
    fail "copy overlay missing volume wiring, carries stale snapshot mount, or missing SANDBOX_TYPE=copy"
  fi
}

# The mount overlay carries the worktree bind mount and no copy wiring.
test_mount_overlay_carries_worktree_not_copy_wiring() {
  local overlay="$REPO_ROOT/src/build/docker-compose.mount.yml"
  local copy_only=0
  if ! grep -q 'WORKTREE_DIR' "$overlay" || ! grep -q '/home/agentuser/sandbox' "$overlay"; then
    copy_only=1
  fi
  grep -q 'SNAPSHOT_DIR' "$overlay" && copy_only=1
  grep -q 'sandbox-data' "$overlay" && copy_only=1
  grep -q 'SANDBOX_TYPE=mount' "$overlay" || copy_only=1

  if [[ "$copy_only" -eq 0 ]]; then
    pass "mount overlay carries worktree mount + SANDBOX_TYPE=mount only"
  else
    fail "mount overlay missing worktree mount/SANDBOX_TYPE=mount or carries copy wiring"
  fi
}

# The mount-mode merged output (stub-limited) still contains no copy wiring.
test_mount_output_has_no_snapshot_dir() {
  local FIXTURE_DIR="$FIXTURE_DIR/mountoutput"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  local out="$FIXTURE_DIR/compose-mount-output.yml"
  run_compose_generate "$out" mount

  if [[ ! -f "$out" ]]; then
    fail "compose_generate (mount) did not produce output file"
    return
  fi

  local copy_only=0
  grep -q 'SNAPSHOT_DIR' "$out" && copy_only=1
  grep -q 'sandbox-data' "$out" && copy_only=1

  if [[ "$copy_only" -eq 0 ]]; then
    pass "mount-mode merged output free of copy-only wiring"
  else
    fail "mount-mode merged output contains copy-only wiring"
  fi
}

# compose_generate stamps the built images' ID digests into the record's
# `agent-sandbox.agent-image-digest` / `agent-sandbox.sandbox-image-digest`
# labels (read via docker inspect post-build), which the dry-run roundtrip
# gate and resume identity checks consume docker-free.
test_record_bakes_image_digests() {
  local FIXTURE_DIR="$FIXTURE_DIR/imagesig"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  local out="$FIXTURE_DIR/compose-output.yml"
  DOCKER_STUB_IMAGE_DIGESTS="pi-agent-test-project:sha256:agentdigest sandbox-test-project:sha256:sandboxdigest" \
    run_compose_generate "$out"

  if [[ ! -f "$out" ]]; then
    fail "compose_generate (digests) did not produce output file"
    return
  fi
  if grep -q 'agent-sandbox.agent-image-digest: sha256:agentdigest' "$out" \
     && grep -q 'agent-sandbox.sandbox-image-digest: sha256:sandboxdigest' "$out"; then
    pass "compose_generate stamps both image digest labels into the record"
  else
    fail "compose_generate did not stamp image digest labels, got:"
    grep 'image-digest' "$out" >&2 || true
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_no_name_lines_in_output
run_test test_output_is_valid_yaml
run_test test_stub_docker_config_preserves_structure
run_test test_base_template_has_no_copy_only_wiring
run_test test_copy_overlay_carries_volume_no_snapshot_mount
run_test test_mount_overlay_carries_worktree_not_copy_wiring
run_test test_mount_output_has_no_snapshot_dir
run_test test_record_bakes_image_digests

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
