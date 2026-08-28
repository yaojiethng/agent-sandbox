#!/usr/bin/env bash
# tests/test_trace_build.sh
# Trace tests for agent-sandbox build subcommand.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup
# For container_sig / *_sig_sources behavior-lock tests. build.sh's main() is
# guarded, so sourcing is safe and exposes only its library functions.
source "$REPO_ROOT/scripts/build.sh"
# record_image / record_provider live in session_inventory.sh (pure lib).
source "$REPO_ROOT/src/libs/session_inventory.sh"

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
# 64-hex hash (NOT pinned to a value  --  content is environmental and shifts on
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

# The preflight warning  --  start's staleness surface (start_agent.sh -> preflight
# -> _check_container_sig)  --  delegates the decision to the shared image_is_stale
# predicate: a baked container-sig differing from the recomputed source sig
# warns, a matching one stays silent. Locks the one-criterion-two-consumers
# contract (20260821-09/10).
test_check_container_sig_warns_via_shared_predicate() {

  local out
  out="$(PATH="$STUB_DIR:$PATH" DOCKER_STUB_IMAGE_SIG_LABEL="stale-baked-sig" \
        _check_container_sig "pi-agent-test-project" agent "pi" "$REPO_ROOT" 2>&1)"
  if [[ "$out" == *"container-sig mismatch (image is stale)"* ]]; then
    pass "preflight: differing baked sig warns via shared image_is_stale"
  else
    fail "preflight: expected stale warning via shared predicate, got: $out"
  fi

  # Fresh: both images carry their own recomputed sig -> no warning.
  local -a s=(); mapfile -t s < <(_agent_sig_sources "$REPO_ROOT" "pi")
  local agent_sig; agent_sig="$(container_sig "$REPO_ROOT" "${s[@]}")"
  local -a ss=(); mapfile -t ss < <(_sandbox_sig_sources)
  local sandbox_sig; sandbox_sig="$(container_sig "$REPO_ROOT" "${ss[@]}")"
  out="$(PATH="$STUB_DIR:$PATH" \
        DOCKER_STUB_IMAGE_SIG_LABELS="pi-agent-test-project:$agent_sig sandbox-test-project:$sandbox_sig" \
        _check_container_sig "pi-agent-test-project" agent "pi" "$REPO_ROOT" 2>&1)"
  if [[ -z "$out" ]]; then
    pass "preflight: matching recomputed sig stays silent"
  else
    fail "preflight: expected no warning for fresh image, got: $out"
  fi
}

# record_image / record_provider are service-scoped and anchored: a comment
# or stray `image:` outside the service block (or another service) must not
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

# current_sig is deterministic per (type, repo_root, provider) and distinct
# across types  --  a pure recomputation on every call (the former memoization was
# removed as inert; see handover 20260823-09).
test_current_sig_deterministic() {
  local a1 a2 s1 s2
  a1="$(current_sig agent "$REPO_ROOT" pi)"
  a2="$(current_sig agent "$REPO_ROOT" pi)"
  s1="$(current_sig sandbox "$REPO_ROOT")"
  s2="$(current_sig sandbox "$REPO_ROOT")"
  if [[ -n "$a1" && "$a1" == "$a2" && -n "$s1" && "$s1" == "$s2" && "$a1" != "$s1" ]]; then
    pass "current_sig: deterministic and distinct per type"
  else
    fail "current_sig: expected deterministic distinct per type, got agent=$a1 sandbox=$s1"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_container_sig_sources_list
run_test test_container_sig_hashes_real_sources
run_test test_container_sig_missing_path_fails_with_diagnostic
run_test test_check_container_sig_warns_via_shared_predicate
run_test test_record_image_service_scoped
run_test test_current_sig_deterministic
run_test test_build_inspects_images
run_test test_build_no_compose
run_test test_build_has_build_command
run_test test_build_image_failure_surfaces_descriptive_error_under_e
run_test test_build_default_targets_all

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
