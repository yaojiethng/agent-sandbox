#!/usr/bin/env bash
# tests/test_trace_build.sh
# Trace tests for agent-sandbox build subcommand.
# Pins cite: docs/architecture/tool_interface.md naming table (l.15, l.28).


set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup
# build.sh's main() is guarded, so sourcing is safe and exposes only its
# library functions (build_image, _check_interface_contract, preflight).
source "$REPO_ROOT/scripts/build.sh"
# record_image / record_provider live in session_inventory.sh (pure lib).
source "$REPO_ROOT/src/libs/session_inventory.sh"

STUB_DIR="$TEST_DIR/../tests/stubs"

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
      --targets="$PROVIDER_NAME"
  ) > /dev/null 2>&1 || true
}

# invoke_build_err  --  like invoke_build but captures combined stdout+stderr and
# the exit code, so tests can assert on build failure messages and semantics.
invoke_build_err() {
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/build.sh" \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      --targets="$PROVIDER_NAME"
  ) 2>&1
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

# The (string-as-list -> array) refactor is behavior-preserving at the LIST
# level: for path sets whose entries are all whitespace-free, the old unquoted
# word-split call and the new array call produce the SAME argument list. So a
# content-hash pin would NOT detect a regression to the old string-as-list
# form (identical arrays -> identical hash) and would spurious-fail on any
# legitimate edit to a source file. The correct lock is the list construction
# itself: exact ordered membership. A hash test below only checks the plumbing
# runs end-to-end, not the hash's value.
# build's default --targets (omitted) resolves to "all": sandbox + every
# provider with a base.dockerfile. Deterministic count in this repo (3
# providers) locks the default-target routing (the behavior a dangling
# test_dispatch run_test previously claimed to cover but never did).
test_build_default_targets_all() {
  local FIXTURE_DIR="$FIXTURE_DIR/bld_default"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  ( export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/build.sh" \
      --name="$PROJECT_NAME" --project="$PROJECT_DIR" --sandbox="$SANDBOX_DIR"
  ) > /dev/null 2>&1 || true
  local expected actual
  expected="$(( 1 + $(ls "$REPO_ROOT"/src/reasoning/providers/*/base.dockerfile | wc -l) ))"
  actual="$(grep -c " build " "$DOCKER_TRACE_LOG" || true)"
  if [[ "$actual" -eq "$expected" ]]; then
    pass "build (default no --targets): sandbox + all providers ($expected docker builds)"
  else
    fail "build (default no --targets): expected $expected 'docker build', got $actual"
  fi
}

# Interface-contract preflight check (build.sh -> _check_interface_contract,
# ADR interface_contract_compatibility.md): the image's baked
# agent-sandbox.interface-contract-version label is compared against the
# current host-side constant; a mismatch refuses preflight, an aligned label
# passes silently.
test_check_interface_contract_refuses_and_passes_via_stub() {

  local out rc=0
  out="$(PATH="$STUB_DIR:$PATH" DOCKER_STUB_IMAGE_CONTRACT_VERSION="9" \
        _check_interface_contract "pi-agent-test-project" 2>&1)" || rc=$?
  assert_eq "$rc" "1" "interface-contract: differing baked version refuses"
  assert_contains "$out" "interface-contract version 9 differs from current source" \
      "interface-contract: refusal names the drifted surface"

  local current; current="$(interface_contract_version)"
  rc=0
  out="$(PATH="$STUB_DIR:$PATH" DOCKER_STUB_IMAGE_CONTRACT_VERSION="$current" \
        _check_interface_contract "pi-agent-test-project" 2>&1)" || rc=$?
  assert_eq "$rc" "0" "interface-contract: matching baked version passes"
  assert_empty "$out" "interface-contract: matching baked version stays silent"
}
# shadow the service's own image, and the provider is recovered from the agent
# image. Locks the one-parser contract (F2: no divergent -agent- grep).
test_record_image_service_scoped() {
  local dir="$FIXTURE_DIR/recimg"
  mkdir -p "$dir"
  cat > "$dir/r.yml" <<'EOF'
# image: fake-shadow-comment must be ignored
x-session-labels:
  agent-sandbox.host-head-sha: deadbeef
services:
  sandbox:
    image: sandbox-test-project
  agent:
    image: hermes-agent-test-project
  extra:
    image: some-other-image
EOF
  local agent sandbox provider extra
  agent="$(record_image "$dir/r.yml" agent)"
  sandbox="$(record_image "$dir/r.yml" sandbox)"
  extra="$(record_image "$dir/r.yml" extra)"
  provider="$(record_provider "$dir/r.yml")"
  if [[ "$agent" == "hermes-agent-test-project" \
     && "$sandbox" == "sandbox-test-project" \
     && "$extra" == "some-other-image" \
     && "$provider" == "hermes" ]]; then
    pass "record_image/record_provider: service-scoped, anchored, provider from agent image"
  else
    fail "record_image/record_provider: got agent=[$agent] sandbox=[$sandbox] extra=[$extra] provider=[$provider]"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_check_interface_contract_refuses_and_passes_via_stub
run_test test_record_image_service_scoped
run_test test_build_inspects_images
run_test test_build_no_compose
run_test test_build_has_build_command
run_test test_build_image_failure_surfaces_descriptive_error_under_e
run_test test_build_default_targets_all
test_done test_trace_build
