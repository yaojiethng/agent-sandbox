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
  ) > /dev/null 2>&1
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

# Given: a populated build fixture and the docker stub
# When:  build.sh runs with an explicit provider target
# Then:  it inspects images before deciding to build
# Asserts: the preflight probe runs on the explicit build path
test_build_inspects_images() {
  local FIXTURE_DIR="$FIXTURE_DIR/build_inspect"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  local BUILD_RC=0
  invoke_build || BUILD_RC=$?
  assert_rc 0 "$BUILD_RC" "build invocation succeeds"
  if trace_has "image inspect"; then
    pass "build: docker image inspect issued"
  else
    fail "build: docker image inspect not found in trace"
  fi
}

# Given: the same fixture and stub
# When:  build.sh runs
# Then:  no docker compose command is issued
# Asserts: the build subcommand stays independent of the compose path
test_build_no_compose() {
  local FIXTURE_DIR="$FIXTURE_DIR/build_noc"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  local BUILD_RC=0
  invoke_build || BUILD_RC=$?
  assert_rc 0 "$BUILD_RC" "build invocation succeeds"
  if trace_has "compose"; then
    fail "build: docker compose should not be invoked"
  else
    pass "build: no docker compose invocations"
  fi
}

# Given: the same fixture and stub
# When:  build.sh runs
# Then:  at least one docker build is issued
# Asserts: the build actually reaches docker
test_build_has_build_command() {
  local FIXTURE_DIR="$FIXTURE_DIR/build_cmd"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  local BUILD_RC=0
  invoke_build || BUILD_RC=$?
  assert_rc 0 "$BUILD_RC" "build invocation succeeds"
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
# Given: a stub whose docker build exits 42
# When:  build.sh runs standalone (its own set -euo pipefail is active)
# Then:  the output carries the descriptive build_image failure line
# Asserts: the failure surfaces a named message and the invocation exits non-zero
test_build_image_failure_surfaces_descriptive_error_under_e() {
  local FIXTURE_DIR="$FIXTURE_DIR/build_fail_e"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_BUILD_RC="42"

  local out rc=0
  out=$(invoke_build_err) || rc=$?

  unset DOCKER_STUB_BUILD_RC

  if echo "$out" | grep -q "build_image: ERROR build FAILED"; then
    pass "build: failing docker build under standalone set -e surfaces descriptive error"
  else
    fail "build: expected descriptive build_image ERROR under set -e; got: $(echo "$out" | tail -3)"
  fi
  assert_ne "$rc" "0" "build: a failed image build propagates a non-zero exit"
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
# Given: the same fixture, invoked with no --targets flag
# When:  build.sh runs
# Then:  the build count equals one sandbox build plus one per provider base.dockerfile
# Asserts: the default-target resolution builds every discovered provider
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

# Given: a fixture with --name and --project but no --sandbox
# When:  build.sh runs
# Then:  it succeeds instead of demanding the unused flag
# Asserts: the --sandbox requirement is dropped.
test_build_does_not_require_sandbox() {
  local FIXTURE_DIR="$FIXTURE_DIR/bld_nosandbox"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  local out rc=0
  out=$( ( export PATH="$STUB_DIR:$PATH"
    unset SANDBOX_DIR
    bash "$REPO_ROOT/scripts/build.sh" \
      --name="$PROJECT_NAME" --project="$PROJECT_DIR" --targets="$PROVIDER_NAME"
  ) 2>&1 ) || rc=$?
  assert_rc 0 "$rc" "build.sh succeeds without --sandbox"
  if [[ "$out" == *"Usage: agent-sandbox build"* ]]; then
    fail "build.sh still demands --sandbox"
  else
    pass "build.sh does not require --sandbox"
  fi
}

# Interface-contract preflight check (build.sh -> _check_interface_contract,
# ADR interface_contract_compatibility.md): the image's baked
# agent-sandbox.interface-contract-version label is compared against the
# current host-side constant; a mismatch refuses preflight, an aligned label
# passes silently.
# Given: a docker stub reporting a baked interface-contract version
# When:  _check_interface_contract runs against an image
# Then:  a differing version returns 1 and names the drifted surface; an aligned version returns 0 silently
# Asserts: the authoritative contract gate refuses drift and passes alignment
test_check_interface_contract_refuses_and_passes_via_stub() {

  local out rc=0
  out="$(PATH="$STUB_DIR:$PATH" DOCKER_STUB_IMAGE_CONTRACT_VERSION="9" \
        _check_interface_contract "pi-agent-test-project" 2>&1)" || rc=$?
  assert_eq "$rc" "1" "interface-contract: differing baked version refuses"
  assert_contains "$out" "ERROR" "interface-contract: refusal is marked an error"
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
# Given: a compose record with several services, a shadowing comment, and an extra service
# When:  record_image and record_provider run
# Then:  each service's image is read by its own key and the provider is recovered from the agent image
# Asserts: the service-scoped parser (this unit belongs to session_inventory.sh; it lives here because build.sh sources that library)
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

# Given: an image with no contract label
# When:  _check_interface_contract runs
# Then:  rc is 1 and the rebuild remedy is named
# Asserts: a pre-label image refuses preflight with the remedy.
test_check_interface_contract_refuses_missing_label() {
  local rc=0 out
  out="$(PATH="$STUB_DIR:$PATH" \
        _check_interface_contract "pre-label-image" 2>&1)" || rc=$?
  assert_eq "$rc" "1" "interface-contract: missing label refuses"
  assert_contains "$out" "has no interface-contract-version label" \
      "interface-contract: missing-label refusal names the cause"
  assert_contains "$out" "predates the interface contract" \
      "interface-contract: missing-label refusal names the rebuild remedy"
}

# A shim that reports every `docker image inspect` as missing while accepting
# `docker build`. It logs to DOCKER_TRACE_LOG in the stub's shape.
make_missing_image_shim() {
  local DIR="$1"
  mkdir -p "$DIR"
  cat > "$DIR/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s: %s\n' "$DOCKER_TRACE_LOG" "$*" >> "$DOCKER_TRACE_LOG"
case "${1:-}" in
  image) [[ "${2:-}" == "inspect" ]] && exit 1 ;;
esac
exit 0
EOF
  chmod +x "$DIR/docker"
}

# Given: a docker that reports both images missing
# When:  preflight runs with build_missing=true
# Then:  it builds the sandbox image and the provider's agent image
# Asserts: preflight's build-on-missing branch
test_preflight_builds_when_images_missing() {
  local FIXTURE_DIR="$FIXTURE_DIR/preflight_build"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  make_missing_image_shim "$FIXTURE_DIR/shim"

  local OUT RC=0
  OUT="$( PATH="$FIXTURE_DIR/shim:$STUB_DIR:$PATH" preflight pi test-project "$REPO_ROOT" true 2>&1 )" || RC=$?

  if [[ $RC -eq 0 ]] \
     && grep -q -- "-t sandbox-test-project" "$DOCKER_TRACE_LOG" \
     && grep -q -- "-t pi-agent-test-project" "$DOCKER_TRACE_LOG"; then
    pass "preflight: builds sandbox and agent images when both are missing"
  else
    fail "preflight build-on-missing: rc=$RC out='$OUT'"
  fi
}

# Given: a docker that reports both images missing
# When:  preflight runs with build_missing=false (a resume)
# Then:  it refuses without building
# Asserts: preflight's refuse path, which stops a resume from rebuilding
test_preflight_refuses_missing_images_when_resume() {
  local FIXTURE_DIR="$FIXTURE_DIR/preflight_refuse"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  make_missing_image_shim "$FIXTURE_DIR/shim"

  local OUT RC=0
  OUT="$( PATH="$FIXTURE_DIR/shim:$STUB_DIR:$PATH" preflight pi test-project "$REPO_ROOT" false 2>&1 )" || RC=$?

  if [[ $RC -ne 0 ]] && [[ "$OUT" == *"resume does not build"* ]] \
     && ! grep -q -- "-t sandbox-test-project" "$DOCKER_TRACE_LOG"; then
    pass "preflight: refuses missing images when resume must not build"
  else
    fail "preflight refuse path: rc=$RC out='$OUT'"
  fi
}

# Given: a build.sh invocation with --name but no --project
# When:  build.sh's main runs
# Then:  it prints usage and exits non-zero
# Asserts: main's required-flag check
test_build_main_requires_project() {
  local OUT RC=0
  OUT="$( (export PATH="$STUB_DIR:$PATH"; bash "$REPO_ROOT/scripts/build.sh" --name=test) 2>&1 )" || RC=$?

  if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "Usage: agent-sandbox build"; then
    pass "build main: missing --project refused with usage"
  else
    fail "build main: expected usage on missing --project (rc=$RC)"
  fi
}

# Given: a provider tree with a base.dockerfile but no provider.dockerfile
# When:  build_agent runs
# Then:  it refuses and names the missing provider Dockerfile
# Asserts: build_agent's provider-Dockerfile validation
test_build_agent_missing_provider_dockerfile() {
  local FI="$FIXTURE_DIR/fake_agent_repo"
  mkdir -p "$FI/src/reasoning/providers/fake"
  : > "$FI/src/reasoning/node.dockerfile"
  : > "$FI/src/reasoning/providers/fake/base.dockerfile"

  local OUT RC=0
  OUT="$( (export PATH="$STUB_DIR:$PATH"; build_agent fake test-project "$FI") 2>&1 )" || RC=$?

  if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "provider Dockerfile not found"; then
    pass "build_agent: missing provider Dockerfile refused"
  else
    fail "build_agent: expected provider Dockerfile validation (rc=$RC out='$OUT')"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_check_interface_contract_refuses_and_passes_via_stub
run_test test_check_interface_contract_refuses_missing_label
run_test test_record_image_service_scoped
run_test test_build_inspects_images
run_test test_build_no_compose
run_test test_build_has_build_command
run_test test_build_image_failure_surfaces_descriptive_error_under_e
run_test test_build_default_targets_all
run_test test_build_does_not_require_sandbox
run_test test_preflight_builds_when_images_missing
run_test test_preflight_refuses_missing_images_when_resume
run_test test_build_main_requires_project
run_test test_build_agent_missing_provider_dockerfile
test_done test_trace_build
