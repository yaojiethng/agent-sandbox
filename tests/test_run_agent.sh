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

# invoke_run_agent OUT_FILE MODE
#   Runs run_agent.sh (standard mode) with the docker stub shadowing PATH.
#   Captures stdout+stderr into OUT_FILE; the function's rc is returned.
invoke_run_agent() {
  local out_file="$1" mode="${2:-standard}"
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" "$mode" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      --delivery=copy < /dev/null
  ) > "$out_file" 2>&1
}

trace_count() { grep -c "$1" "$DOCKER_TRACE_LOG" 2>/dev/null || true; }

# ---------------------------------------------------------------------------
# Provider setup hook
# ---------------------------------------------------------------------------

# A provider without src/reasoning/providers/<n>/setup.sh: the hook is a
# no-op and the session must reach compose generation (rc 0, compose called).
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

# ---------------------------------------------------------------------------
# Provider overlay selection
# ---------------------------------------------------------------------------

# The provider overlay (src/reasoning/providers/pi/docker-compose.pi.yml) must
# be part of the compose file set: the docker-stub trace logs every -f argument
# of `docker compose config`, and compose_generate preserves input basenames in
# its staging filenames (01-docker-compose.pi.yml).
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

# SERVE_PORT unset: run_agent.sh falls back to the default port with a
# warning (documented in handover 20260325-01 -- "warning added for unset
# case"); the session must still proceed.
test_serve_port_unset_falls_back_with_warning() {
  local FIX="$FIXTURE_DIR/serve_port_unset"
  make_run_agent_fixture "$FIX" pi
  unset SERVE_PORT

  local out="$FIX/out.txt" rc=0
  invoke_run_agent "$out" || rc=$?

  if [[ $rc -eq 0 ]] && grep -q "SERVE_PORT is not set" "$out" \
     && grep -q "$REPO_ROOT/src/build/compose.sh SERVE_PORT_DEFAULT\|falling back to default (46553)" "$out"; then
    pass "SERVE_PORT unset: warning emitted, session proceeds on the default port"
  else
    fail "SERVE_PORT unset: expected warning + rc 0, got rc=$rc out='$(cat "$out")'"
  fi
  export SERVE_PORT="46553"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_setup_hook_absent_is_noop
run_test test_setup_hook_present_runs_and_proceeds
run_test test_setup_hook_failure_aborts_with_attribution
run_test test_serve_port_unset_falls_back_with_warning
run_test test_provider_overlay_reaches_compose_file_set
run_test test_provider_overlay_absent_is_optional

test_done "test_run_agent"
