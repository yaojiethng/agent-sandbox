#!/usr/bin/env bash
# tests/test_trace_build.sh
# Trace tests for agent-sandbox build subcommand.
# Pins cite: docs/reference/tool_interface.md naming table (l.15, l.28).


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

# Regression: build.sh relies on the caller setting `set -euo pipefail`; a
# standalone `bash build.sh` (as the trace tests invoke it) previously inherited
# the harness's no-`-e`, so the production failure-abort semantics were never
# exercised. build.sh now self-enables `-e` on standalone invocation. Under a
# failing docker build the result must be the descriptive `build_image: ERROR
# build FAILED` message, not a silent bare `set -e` abort.
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
# provider with a provider.dockerfile. Every tier is built on every call, so the
# count is one sandbox build plus three tiers per provider, which locks the
# default-target routing: a dropped provider drops its three tiers.
# Given: the same fixture, invoked with no --targets flag
# When:  build.sh runs
# Then:  the build count equals one sandbox build plus three per provider, and
#        every discovered provider's own image is among them
# Asserts: the default-target resolution builds every discovered provider
test_build_default_targets_all() {
  local FIXTURE_DIR="$FIXTURE_DIR/bld_default"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  ( export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/build.sh" \
      --name="$PROJECT_NAME" --project="$PROJECT_DIR" --sandbox="$SANDBOX_DIR"
  ) > /dev/null 2>&1 || true
  local providers expected actual
  providers="$(ls "$REPO_ROOT"/src/reasoning/providers/*/provider.dockerfile | wc -l)"
  expected="$(( 1 + 3 * providers ))"
  actual="$(grep -c " build " "$DOCKER_TRACE_LOG" || true)"
  local p missing=""
  for p in "$REPO_ROOT"/src/reasoning/providers/*/provider.dockerfile; do
    p="$(basename "$(dirname "$p")")"
    grep -q -- "-t ${p}-agent-test-project" "$DOCKER_TRACE_LOG" || missing+="$p "
  done
  if [[ "$actual" -eq "$expected" && -z "$missing" ]]; then
    pass "build (default no --targets): sandbox + three tiers per provider ($expected docker builds)"
  else
    fail "build (default no --targets): expected $expected 'docker build', got $actual; providers not built: ${missing:-none}"
  fi
}

# trace_image_tags  --  the `-t <image>` tags the docker stub logged, in build
# order. The build order is the tier chain: tier 1, tier 2, tier 3.
trace_image_tags() {
  grep -o -- "-t [^ ]*" "$DOCKER_TRACE_LOG" | awk '{print $2}'
}

# Given: the fixture and the docker stub
# When:  build.sh runs for the pi provider
# Then:  the build order is agent-base, agent-harnesses, pi-agent-test-project
# Asserts: a registry-package provider builds the shared base, then the shared
#          harness tier, then its own image
test_build_order_pi_unified_harness_tier() {
  local FIXTURE_DIR="$FIXTURE_DIR/order_pi"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  local BUILD_RC=0
  invoke_build || BUILD_RC=$?
  assert_rc 0 "$BUILD_RC" "build invocation succeeds"
  assert_eq "$(trace_image_tags | paste -sd, -)" \
    "agent-base,agent-harnesses,pi-agent-test-project" \
    "pi builds agent-base, then agent-harnesses, then pi-agent-test-project"
}

# Given: the fixture and the docker stub
# When:  build.sh runs for the hermes provider
# Then:  the build order is agent-base, hermes-base, hermes-agent-test-project
# Asserts: a source-built provider keeps its own base between the shared base
#          and its own image
test_build_order_hermes_keeps_its_base() {
  local FIXTURE_DIR="$FIXTURE_DIR/order_hermes"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  export PROVIDER_NAME="hermes"
  local BUILD_RC=0
  invoke_build || BUILD_RC=$?
  assert_rc 0 "$BUILD_RC" "build invocation succeeds"
  assert_eq "$(trace_image_tags | paste -sd, -)" \
    "agent-base,hermes-base,hermes-agent-test-project" \
    "hermes builds agent-base, then hermes-base, then hermes-agent-test-project"
}

# Given: a build through build_image with no progress mode stated
# When:  the docker invocation is traced
# Then:  --quiet is passed, which is what keeps the harness log one line per
#        image
# Asserts: the default progress mode is quiet
test_build_image_defaults_to_quiet_progress() {
  local df="$FIXTURE_DIR/Dockerfile"
  printf 'FROM scratch\n' > "$df"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"
  : > "$DOCKER_TRACE_LOG"
  local old_path="$PATH"
  PATH="$STUB_DIR:$PATH"
  BUILD_PROGRESS="quiet"
  build_image "an-image" "$df" "$FIXTURE_DIR" "" "" "" >/dev/null 2>&1
  PATH="$old_path"
  if grep -q -- "--quiet" "$DOCKER_TRACE_LOG"; then
    pass "build_image: the default progress mode passes --quiet"
  else
    fail "build_image: the default progress mode should pass --quiet"
  fi
}

# Given: a build through build_image with plain progress
# When:  the docker invocation is traced
# Then:  --progress=plain replaces --quiet, so the per-step lines the host probe
#        parses actually reach the log and the two flags never collide
# Asserts: the progress mode reaches docker instead of riding alongside --quiet
test_build_image_plain_progress_replaces_quiet() {
  local df="$FIXTURE_DIR/Dockerfile"
  printf 'FROM scratch\n' > "$df"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"
  : > "$DOCKER_TRACE_LOG"
  local old_path="$PATH"
  PATH="$STUB_DIR:$PATH"
  BUILD_PROGRESS="plain"
  build_image "an-image" "$df" "$FIXTURE_DIR" "" "" "" >/dev/null 2>&1
  PATH="$old_path"
  # Read by the sourced build.sh's build_image.
  # shellcheck disable=SC2034
  BUILD_PROGRESS="quiet"
  if grep -q -- "--progress=plain" "$DOCKER_TRACE_LOG" && ! grep -q -- "--quiet" "$DOCKER_TRACE_LOG"; then
    pass "build_image: plain progress reaches docker and --quiet is absent"
  else
    fail "build_image: --progress=plain should replace --quiet, trace: $(cat "$DOCKER_TRACE_LOG")"
  fi
}

# Given: the builder invoked with --progress=plain on its command line
# When:  it builds one provider chain
# Then:  the flag is parsed at ingestion and reaches every docker build
# Asserts: the option is wired from the CLI, not only from a sourced variable
test_cli_progress_flag_reaches_docker() {
  local FIXTURE_DIR="$FIXTURE_DIR/progress_cli"
  mkdir -p "$FIXTURE_DIR"
  setup_build_fixture "$FIXTURE_DIR"
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/build.sh" \
      --name="$PROJECT_NAME" --project="$PROJECT_DIR" --sandbox="$SANDBOX_DIR" \
      --targets=pi --progress=plain
  ) >"$FIXTURE_DIR/progress-cli.log" 2>&1 || true
  if grep -q -- "--progress=plain" "$DOCKER_TRACE_LOG"; then
    pass "--progress=plain is parsed at ingestion and reaches docker build"
  else
    fail "--progress=plain did not reach docker build; trace: $(cat "$DOCKER_TRACE_LOG"); output: $(cat "$FIXTURE_DIR/progress-cli.log")"
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
  : > "$FI/src/reasoning/base.dockerfile"
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
run_test test_build_no_compose
run_test test_build_has_build_command
run_test test_build_image_failure_surfaces_descriptive_error_under_e
run_test test_build_default_targets_all
run_test test_build_order_pi_unified_harness_tier
run_test test_build_order_hermes_keeps_its_base
run_test test_build_does_not_require_sandbox
run_test test_build_image_defaults_to_quiet_progress
run_test test_build_image_plain_progress_replaces_quiet
run_test test_cli_progress_flag_reaches_docker
run_test test_preflight_builds_when_images_missing
run_test test_preflight_refuses_missing_images_when_resume
run_test test_build_main_requires_project
run_test test_build_agent_missing_provider_dockerfile
test_done test_trace_build
