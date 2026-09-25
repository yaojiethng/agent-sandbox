#!/usr/bin/env bash
# tests/test_run_agent.sh  --  Behavioural tests for scripts/run_agent.sh
# provider hook + provider overlay selection.
# Pins cite: docs/architecture/tool_interface.md l.41, l.225 (SERVE_PORT contract);
#             code-owner: scripts/run_agent.sh SERVE_PORT_DEFAULT.

#
# Replaces the former source-grep suite (extract_path_expr string checks +
# provider-file existence loop). That suite asserted the exact source text a
# change would touch and never executed run_agent.sh; coverage for the paths
# it nominally guarded is now behavioural:
#
#   1. Provider setup hook (scripts/run_agent.sh "Provider setup hook"):
#      - absent setup.sh          -> hook is a no-op, session proceeds
#      - present + rc 0 (pi)      -> hook runs, session proceeds to compose
#      - present + non-zero rc    -> abort with attribution, BEFORE compose
#   2. Provider overlay merge: docker-compose.<provider>.yml reaches the
#      compose file set passed to `docker compose config` (asserted on the
#      docker-stub trace, which logs every -f argument).
#
# The provider setup hook is a documented contract (run_agent.sh header: "If
# setup.sh exits non-zero, the session aborts with a clear error attributing
# the failure to the provider setup hook") that previously had zero tests.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"

# make_run_agent_fixture FIXTURE_DIR PROVIDER [READONLY_SANDBOX]
#   Builds the minimal environment run_agent.sh expects from its caller
#   (start_agent.sh normally exports these). Sets DOCKER_TRACE_LOG.
#   READONLY_SANDBOX=1 strips write permission from the sandbox dir so the
#   pi setup hook's `mkdir -p $SANDBOX_DIR/.pi` fails (the hook's only
#   side effect) without touching any file under src/.
make_run_agent_fixture() {
  local FIX="$1" provider="$2" readonly="${3:-0}"

  export PROJECT_NAME="test-project"
  export PROVIDER_NAME="$provider"
  export SANDBOX_DIR="$FIX/sandbox"
  export SERVE_PORT="46553"
  export HOST_UID="1000"
  export HOST_GID="1000"

  export SESSION_TS="20260730-000000"
  export HOST_HEAD_SHA="abc123def456"
  export SESSION_ID="test01"
  export SANITIZED_HOST_BRANCH="master"
  export SANDBOX_CONTAINER_NAME="sandbox-test-project-${SESSION_ID}"
  export AGENT_CONTAINER_NAME="${provider}-test-project-${SESSION_ID}"

  mkdir -p "$SANDBOX_DIR"
  cat > "$SANDBOX_DIR/.env" <<EOF
SANDBOX_DIR=$SANDBOX_DIR
PROJECT_DIR=$FIX/project
EOF

  if [[ "$readonly" == "1" ]]; then
    chmod 555 "$SANDBOX_DIR"
  fi

  export DOCKER_TRACE_LOG="$FIX/docker-trace.log"
  :> "$DOCKER_TRACE_LOG"
}

# invoke_run_agent OUT_FILE MODE [FLATTEN]
#   Runs run_agent.sh (standard mode) with the docker stub shadowing PATH.
#   Captures stdout+stderr into OUT_FILE; the function's rc is returned.
#   Optional FLATTEN="--flatten" appends the flag.
invoke_run_agent() {
  local out_file="$1" mode="${2:-standard}" flatten="${3:-}"
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" "$mode" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      --delivery=copy \
      $flatten < /dev/null
  ) > "$out_file" 2>&1
}

# ---------------------------------------------------------------------------
# Provider setup hook
# ---------------------------------------------------------------------------

# A provider without src/reasoning/providers/<n>/setup.sh: the hook is a
# no-op and the session must reach compose generation (rc 0, compose called).
# Given: a provider directory with no setup.sh (the ghost fixture)
# When:  run_agent.sh runs a standard session
# Then:  the session reaches compose generation and prints no failure attribution
# Asserts: the provider setup hook is a no-op when the file is absent
test_setup_hook_absent_is_noop() {
  local FIX="$FIXTURE_DIR/hook_absent"
  make_run_agent_fixture "$FIX" ghost

  local out="$FIX/out.txt" rc=0
  invoke_run_agent "$out" || rc=$?

  if [[ $rc -eq 0 ]] && [[ "$(trace_count 'compose config')" -gt 0 ]]; then
    pass "setup hook absent (ghost provider): session proceeds to compose, rc 0"
  else
    fail "setup hook absent: expected rc 0 + compose config, got rc=$rc out='$(cat "$out")'"
  fi
  if grep -q "setup hook failed" "$out"; then
    fail "setup hook absent: spurious failure attribution"
  else
    pass "setup hook absent: no failure attribution"
  fi
}

# The pi provider ships setup.sh (mkdir -p .pi). A run that reaches compose
# proves the hook was sourced and exited 0 (a failing hook aborts first).
# Given: the pi provider, which ships setup.sh
# When:  run_agent.sh runs a standard session
# Then:  the hook is sourced, exits 0, and the session reaches compose generation
# Asserts: a present hook runs and its success is accepted
test_setup_hook_present_runs_and_proceeds() {
  local FIX="$FIXTURE_DIR/hook_present"
  make_run_agent_fixture "$FIX" pi

  local out="$FIX/out.txt" rc=0
  invoke_run_agent "$out" || rc=$?

  if [[ $rc -eq 0 ]] && [[ "$(trace_count 'compose config')" -gt 0 ]]; then
    pass "setup hook present (pi): hook sourced, session proceeds to compose"
  else
    fail "setup hook present: expected rc 0 + compose config, got rc=$rc out='$(cat "$out")'"
  fi
}

# A failing setup hook must abort the session with an attribution message
# naming the hook file, BEFORE any docker/compose invocation (documented
# contract in run_agent.sh: "the session aborts with a clear error
# attributing the failure to the provider setup hook").
# Given: the pi setup hook forced to fail (the sandbox dir stripped of write permission)
# When:  run_agent.sh runs a standard session
# Then:  it aborts non-zero with a message naming providers/pi/setup.sh and calls no compose command
# Asserts: the documented abort contract - a failing hook is attributed and aborts before any side effect
test_setup_hook_failure_aborts_with_attribution() {
  local FIX="$FIXTURE_DIR/hook_fails"
  make_run_agent_fixture "$FIX" pi 1

  local out="$FIX/out.txt" rc=0
  invoke_run_agent "$out" || rc=$?
  chmod -R u+w "$SANDBOX_DIR" 2>/dev/null || true  # let the trap clean up

  if [[ $rc -ne 0 ]] && grep -q "provider setup hook failed" "$out" \
     && grep -q "providers/pi/setup.sh" "$out"; then
    pass "failing setup hook: aborts with attribution naming providers/pi/setup.sh"
  else
    fail "failing setup hook: expected non-zero rc + attribution, got rc=$rc out='$(cat "$out")'"
  fi
  if [[ "$(trace_count 'compose')" -eq 0 ]]; then
    pass "failing setup hook: aborts before any compose invocation"
  else
    fail "failing setup hook: compose was invoked despite hook failure"
  fi
}

# --flatten is accepted and the session proceeds to compose (default is full;
# the flag is the flatten opt-out, so its acceptance is the contract).
# Given: --flatten on the command line
# When:  run_agent.sh runs a standard session
# Then:  the flag is accepted and the session reaches compose generation
# Asserts: the flatten opt-out is accepted (full history is the default)
test_flatten_flag_accepted() {
  local FIX="$FIXTURE_DIR/flatten"
  make_run_agent_fixture "$FIX" pi

  local out="$FIX/out.txt" rc=0
  invoke_run_agent "$out" standard --flatten || rc=$?

  if [[ $rc -eq 0 ]] && [[ "$(trace_count 'compose config')" -gt 0 ]]; then
    pass "flatten flag: --flatten accepted, session proceeds to compose"
  else
    fail "flatten flag: expected rc 0 + compose config, got rc=$rc out='$(cat "$out")'"
  fi
}

# ---------------------------------------------------------------------------
# Provider overlay selection
# ---------------------------------------------------------------------------
# The provider overlay (src/reasoning/providers/pi/docker-compose.pi.yml) must
# be part of the compose file set: the docker-stub trace logs every -f argument
# of `docker compose config`, and compose_generate preserves input basenames in
# its staging filenames (01-docker-compose.pi.yml).
# Given: the pi provider, which ships docker-compose.pi.yml
# When:  the session generates its compose file set
# Then:  docker-compose.pi.yml is among the -f arguments (the stub trace logs them)
# Asserts: provider overlay inclusion in the compose file set
test_provider_overlay_reaches_compose_file_set() {
  local FIX="$FIXTURE_DIR/overlay_merged"
  make_run_agent_fixture "$FIX" pi

  local out="$FIX/out.txt" rc=0
  invoke_run_agent "$out" || rc=$?

  if [[ "$(trace_count 'compose config')" -eq 0 ]]; then
    fail "provider overlay: run did not reach compose generation (rc=$rc)"
    return
  fi
  if grep -q 'docker-compose\.pi\.yml' "$DOCKER_TRACE_LOG"; then
    pass "provider overlay: docker-compose.pi.yml included in compose file set"
  else
    fail "provider overlay: pi overlay missing from compose file set: $(grep 'compose config' "$DOCKER_TRACE_LOG")"
  fi
}

# A provider without an overlay file: the merge must still succeed (the
# overlay is optional by contract) and no ghost overlay may appear.
# Given: a provider with no overlay file
# When:  the session generates its compose file set
# Then:  the merge succeeds and no ghost overlay name appears in the trace
# Asserts: the provider overlay is optional
test_provider_overlay_absent_is_optional() {
  local FIX="$FIXTURE_DIR/overlay_absent"
  make_run_agent_fixture "$FIX" ghost

  local out="$FIX/out.txt" rc=0
  invoke_run_agent "$out" || rc=$?

  if [[ $rc -eq 0 && "$(trace_count 'compose config')" -gt 0 ]] \
     && ! grep -q 'docker-compose\.ghost\.yml' "$DOCKER_TRACE_LOG"; then
    pass "provider overlay absent (ghost): merge succeeds without it"
  else
    fail "provider overlay absent: expected rc 0 + config without ghost overlay, got rc=$rc"
  fi
}

# SERVE_PORT unset: run_agent.sh still resolves the fallback default (46553,
# matching the provider serve overlays) so the session proceeds. The warning is
# serve-mode-only: in non-serve modes the port is irrelevant and would be
# noise. Warning originally added for the unset case (handover 20260325-01);
# mode gate pinned by handover 20260912-11.
# Given: SERVE_PORT unset and a standard-mode session
# When:  run_agent.sh resolves the port
# Then:  no warning is printed and the session proceeds on the default
# Asserts: the SERVE_PORT fallback warning is serve-mode-only
test_serve_port_unset_standard_is_quiet() {
  local FIX="$FIXTURE_DIR/serve_port_unset_std"
  make_run_agent_fixture "$FIX" pi
  unset SERVE_PORT

  local out="$FIX/out.txt" rc=0
  invoke_run_agent "$out" || rc=$?

  if [[ $rc -eq 0 ]] && ! grep -q "SERVE_PORT is not set" "$out"; then
    pass "SERVE_PORT unset, standard mode: no warning, session proceeds on the default"
  else
    fail "SERVE_PORT unset, standard mode: expected rc 0 without warning, got rc=$rc out='$(cat "$out")'"
  fi
  export SERVE_PORT="46553"
}

# Given: SERVE_PORT unset and a serve-mode session
# When:  run_agent.sh resolves the port
# Then:  the fallback warning names the default port and the session proceeds
# Asserts: the serve-mode fallback warning
test_serve_port_unset_serve_warns() {
  local FIX="$FIXTURE_DIR/serve_port_unset_serve"
  make_run_agent_fixture "$FIX" pi
  unset SERVE_PORT

  local out="$FIX/out.txt" rc=0
  invoke_run_agent "$out" serve || rc=$?

  if [[ $rc -eq 0 ]] && grep -q "SERVE_PORT is not set" "$out" \
     && grep -q "falling back to default (46553)" "$out"; then
    pass "SERVE_PORT unset, serve mode: warning emitted, session proceeds on the default port"
  else
    fail "SERVE_PORT unset, serve mode: expected warning + rc 0, got rc=$rc out='$(cat "$out")'"
  fi
  export SERVE_PORT="46553"
}

# Given: --help on the command line
# When:  run_agent.sh parses its flags
# Then:  it prints this script's usage, not the usage of a sourced sibling
# Asserts: run_agent.sh owns its help surface
test_help_prints_run_agent_usage() {
  local out rc=0
  out=$(bash "$REPO_ROOT/scripts/run_agent.sh" standard --help 2>&1) || rc=$?

  if [[ "$out" == *"agent-sandbox run"* ]] \
     && [[ "$out" == *"standard"* ]] \
     && [[ "$out" != *"agent-sandbox build"* ]]; then
    pass "run_agent --help prints its own usage, not build's"
  else
    fail "run_agent --help wrong usage (rc=$rc): $out"
  fi
}

# Given: a fresh copy session whose seeder exceeds a one-millisecond timeout
# When:  the seeder times out
# Then:  the start aborts and attributes the failure to the timeout
# Asserts: the timeout message, distinct from a seeder defect exit
test_seeder_timeout_names_the_timeout() {
  local FIX="$FIXTURE_DIR/seed_timeout"
  make_run_agent_fixture "$FIX" pi
  export PROJECT_DIR="$FIX/project"
  mkdir -p "$PROJECT_DIR"

  local out="$FIX/out.txt" rc=0
  (
    export PATH="$STUB_DIR:$PATH"
    export SEED_TIMEOUT=0.001
    bash "$REPO_ROOT/scripts/run_agent.sh" standard \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      --delivery=copy \
      --reset-volume < /dev/null
  ) > "$out" 2>&1 || rc=$?

  if [[ $rc -ne 0 ]] && grep -q "seeder timed out after 0.001s" "$out"; then
    pass "seeder timeout: aborts with the timeout attribution"
  else
    fail "seeder timeout: expected the timeout message, got rc=$rc out='$(cat "$out")'"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_setup_hook_absent_is_noop
run_test test_setup_hook_present_runs_and_proceeds
run_test test_setup_hook_failure_aborts_with_attribution
run_test test_flatten_flag_accepted
run_test test_help_prints_run_agent_usage
run_test test_seeder_timeout_names_the_timeout
run_test test_serve_port_unset_standard_is_quiet
run_test test_serve_port_unset_serve_warns
run_test test_provider_overlay_reaches_compose_file_set
run_test test_provider_overlay_absent_is_optional

test_done "test_run_agent"
