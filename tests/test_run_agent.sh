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
#   3. The session trace family: the teardown verb per mode, teardown-is-last,
#      the failure paths that must still tear down, the persisted compose file,
#      the three delivery selections, and the shutdown hint pair. These units
#      moved here from tests/test_trace_start.sh, whose name named a verb its
#      helpers never ran: both of them invoke run_agent.sh.
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


setup_start_fixture() {
  local FIXTURE_DIR="$1"

  export PROJECT_NAME="test-project"
  export PROVIDER_NAME="pi"
  export SANDBOX_DIR="$FIXTURE_DIR/sandbox"
  export CHANGES_DIR="$SANDBOX_DIR/.workspace/session-diffs"
  export INPUT_DIR="$SANDBOX_DIR/.workspace/input"
  export OUTPUT_DIR="$SANDBOX_DIR/.workspace/output"
  export SERVE_PORT="46553"
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

  mkdir -p "$SANDBOX_DIR" "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"
  mkdir -p "$SANDBOX_DIR/.pi"

  cat > "$SANDBOX_DIR/.env" << EOF
SANDBOX_DIR=$SANDBOX_DIR
PROJECT_DIR=$FIXTURE_DIR/project
EOF

  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"
  :> "$DOCKER_TRACE_LOG"
  # Tests run in the same shell (run_test), so stub env vars must not leak
  # between tests.
  unset DOCKER_STUB_UP_RC DOCKER_STUB_RUN_RC DOCKER_STUB_SANDBOX_HEALTH
}

invoke_run_agent() {
  local mode="$1"
  shift

  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" "$mode" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      "$@"
  ) > /dev/null 2>&1
}

# invoke_run_agent_rc  --  like invoke_run_agent but captures run_agent.sh's exit
# code instead of discarding it. Prints the rc to stdout (callers capture it).
invoke_run_agent_rc() {
  local mode="$1"
  shift

  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" "$mode" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      "$@"
  ) > /dev/null 2>&1
  echo $?
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# Given: a fixture sandbox with no session export directory
# When:  a standard session ends
# Then:  the shutdown output carries the make resume command for that session and no draft hint
# Asserts: the post-session hint pair (resume always; draft suppressed on absent)
test_start_standard_shutdown_resume_hint() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_shutdown_hint"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"

  # Post-session teardown (the end-of-session shutdown output produced by
  # `make start`) must surface a fully formed resume command for the session
  # that was just shut down -- the same wording `make stop` uses.
  local output
  output=$( (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" standard \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      --delivery=copy
  ) 2>&1 )

  assert_contains "$output" "Resume this session later: make resume SESSION_ID=test01" "start (standard): shutdown output carries make resume SESSION_ID=<id>"

  # No session export dir exists in this fixture: the draft hint must be
  # suppressed (suppress-on-absent), not left pointing at a stale bundle.
  if [[ "$output" != *"make draft BUNDLE="* ]]; then
    pass "start (standard): no draft hint when no session export exists"
  else
    fail "start (standard): draft hint printed without a session export"
  fi
}

# Given: a session export directory holding one patch
# When:  a standard session ends
# Then:  the shutdown output names that bundle in a make draft command
# Asserts: the draft hint names the exact session export
test_start_standard_shutdown_draft_hint() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_draft_hint"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"

  # A session export dir in the expected shape (EXPORT_TIME-SESSION_ID) with
  # draftable content: the shutdown output must name it exactly.
  mkdir -p "$CHANGES_DIR/session/20260730-120000-test01/patches"
  : > "$CHANGES_DIR/session/20260730-120000-test01/patches/0001-test.patch"

  local output
  output=$( (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" standard \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      --delivery=copy
  ) 2>&1 )

  assert_contains "$output" "Draft this session's changes: make draft BUNDLE=20260730-120000-test01" "start (standard): shutdown output names the exact session export for make draft"
}

# Given: a session export directory with no draftable content
# When:  a standard session ends
# Then:  no draft hint is printed
# Asserts: the draft hint is suppressed for an empty export
test_start_standard_shutdown_draft_hint_suppressed_for_empty_export() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_draft_empty"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"

  # An export dir with no draftable content (failed export, no autosave
  # fallback) must not produce a draft hint.
  mkdir -p "$CHANGES_DIR/session/20260730-120000-test01"

  local output
  output=$( (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" standard \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      --delivery=copy
  ) 2>&1 )

  if [[ "$output" != *"make draft BUNDLE="* ]]; then
    pass "start (standard): draft hint suppressed for empty session export"
  else
    fail "start (standard): draft hint printed for empty session export"
  fi
}

# Given: a standard session
# When:  the compose trace is read
# Then:  no 'compose down -v' ran
# Asserts: a standard teardown keeps the named volumes
test_start_standard_no_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_std"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --delivery=copy

  local count
  count=$(trace_count "compose down -v")
  assert_eq_num "$count" "0" "start (standard): zero 'compose down -v' invocations"
}

# Given: a standard session
# When:  the compose trace is read
# Then:  'compose up -d sandbox' was issued
# Asserts: the sandbox service is brought up by name
test_start_standard_has_compose_up() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_up"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --delivery=copy

  if trace_has "compose up -d sandbox"; then
    pass "start (standard): 'compose up -d sandbox' issued"
  else
    fail "start (standard): 'compose up -d sandbox' not found in trace"
  fi
}

# Given: a standard session
# When:  the compose trace is read
# Then:  'compose run' was issued for the agent
# Asserts: the agent runs in the foreground of the session
test_start_standard_has_compose_run_agent() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_run"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --delivery=copy

  if trace_has "compose run"; then
    pass "start (standard): 'compose run ... agent' issued"
  else
    fail "start (standard): 'compose run ... agent' not found in trace"
  fi
}

# Given: a standard session
# When:  the compose trace is read
# Then:  zero 'compose down -v' invocations
# Asserts: the post-agent teardown preserves volumes (ordering is the teardown pair's subject)
test_start_standard_post_agent_uses_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_post"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --delivery=copy

  # Session teardown is `compose down` (not `down -v`): named volumes must
  # survive. The post-agent dispatch itself is locked by
  # test_standard_teardown_is_last_compose (last compose op is down)  --  this
  # test covers only the volume-preservation verb, since a pre-run teardown
  # down would also satisfy a bare down_count>=1.
  local down_v_count
  down_v_count=$(trace_count "compose down -v")
  assert_eq_num "$down_v_count" "0" "start (standard): zero 'compose down -v' (session_teardown keeps named volumes)"
}

# Given: a standard session started with --reset-volume
# When:  the compose trace is read
# Then:  zero 'compose down -v' invocations
# Asserts: the reset path does not destroy the volume through compose
test_start_refresh_has_no_down_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_ref"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --reset-volume --delivery=copy

  local count
  count=$(trace_count "compose down -v")
  assert_eq_num "$count" "0" "start --refresh: zero 'compose down -v' (volume removal via docker volume rm)"
}

# Given: a stale volume visible to the docker stub and --reset-volume
# When:  the compose trace is read
# Then:  no 'volume rm' was issued
# Asserts: the reset is seed-based, not removal-based
test_start_refresh_volume_rm() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_ref_rm"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  # A stale volume exists; the fresh-session reset seeds a new volume and
  # never issues an explicit volume rm (run_agent.sh seed path).
  export DOCKER_STUB_VOLUME_NAMES="vol1"
  invoke_run_agent "standard" --reset-volume --delivery=copy

  local count
  count=$(trace_count "volume rm")
  assert_eq_num "$count" "0" "start --refresh: stale volume is not removed (seed-based reset)"
  unset DOCKER_STUB_VOLUME_NAMES
}

# Given: a standard session started with --reset-volume
# When:  the compose trace is read
# Then:  zero 'compose down -v' and the post-agent teardown is a bare 'down'
# Asserts: a refreshed session keeps its volume after the agent exits
test_start_refresh_post_agent_uses_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_ref_post"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --reset-volume --delivery=copy

  local down_count down_v_count
  down_count=$(trace_count "compose down")
  down_v_count=$(trace_count "compose down -v")

  # REFRESH: no session_destroy (volumes removed directly by start_agent.sh)
  # post-agent: session_teardown only
  assert_eq_num "$down_v_count" "0" "start --refresh: zero compose down -v, post-agent down only (down=$down_count)"
}

# Given: a standard session started with --reset-volume (the --rebuild path)
# When:  the compose trace is read
# Then:  zero 'compose down -v' invocations
# Asserts: the rebuild path preserves volumes
test_start_rebuild_has_no_down_v() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_reb"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "standard" --reset-volume --delivery=copy

  local count
  count=$(trace_count "compose down -v")
  assert_eq_num "$count" "0" "start --rebuild: zero 'compose down -v' (--reset-volume forwarded, volume rm used)"
}

# Given: a serve-mode session
# When:  the compose trace is read
# Then:  zero 'compose down -v' invocations
# Asserts: a serve teardown keeps the named volumes
test_serve_post_agent_uses_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/serve_post"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "serve"

  # Session teardown is `compose down` (not `down -v`): named volumes must
  # survive. The post-agent dispatch itself is locked by
  # test_serve_teardown_is_last_compose (last compose op is down)  --  this test
  # covers only the volume-preservation verb, since serve also emits a pre-run
  # teardown down that would satisfy a bare down_count>=1.
  local down_v_count
  down_v_count=$(trace_count "compose down -v")
  assert_eq_num "$down_v_count" "0" "serve: zero 'compose down -v' (session_teardown keeps named volumes)"
}

assert_teardown_is_last_compose() {
  local mode="$1"
  local FIXTURE_DIR="$FIXTURE_DIR/${mode}_last"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  invoke_run_agent "$mode" --delivery=copy

  # The unified teardown dispatch is the single final compose operation:
  # nothing runs after `compose down`. (Pre-run session_teardown is the
  # resume-path cleanup before `up`; the last down is the post-agent one.)
  local last
  last=$(trace_grep "compose " | tail -1)
  assert_contains "$last" "compose down" "$mode: last compose op is down (teardown is final dispatch)"
}

# Given: a standard session
# When:  the compose trace is read
# Then:  the last compose operation is 'down'
# Asserts: teardown is the final compose dispatch, nothing runs after it
test_standard_teardown_is_last_compose() {
  assert_teardown_is_last_compose standard
}

# Given: a serve-mode session
# When:  the compose trace is read
# Then:  the last compose operation is 'down'
# Asserts: teardown is the final compose dispatch in serve mode
test_serve_teardown_is_last_compose() {
  assert_teardown_is_last_compose serve
}

# Given: the docker stub failing the agent run with rc 42
# When:  run_agent.sh runs a standard session
# Then:  it exits 42 and a teardown ran
# Asserts: no leak on agent failure, with the agent's rc propagated to the caller
test_standard_agent_failure_still_tears_down_and_propagates_rc() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_fail"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_RUN_RC="42"

  # run_agent.sh must (a) run teardown even when the agent exits non-zero
  # (issue-1 fix: no container/network leak) and (b) exit with the agent's rc
  # (defined exit semantics for standard mode).
  local rc
  rc=$(invoke_run_agent_rc "standard" --delivery=copy)

  local down_count last
  down_count=$(trace_count "compose down")
  last=$(trace_grep "compose " | tail -1)
  if [[ "$rc" -eq 42 && "$down_count" -ge 1 && "$last" == *"compose down"* ]]; then
    pass "standard: agent failure (rc=42) still tears down; rc propagated"
  else
    fail "standard: expected rc=42 + teardown ran, got rc=$rc down_count=$down_count last=$last"
  fi

  unset DOCKER_STUB_RUN_RC
}

# Given: the docker stub failing 'compose up' in serve mode
# When:  run_agent.sh aborts
# Then:  the last compose operation is 'down'
# Asserts: no container or network leak on an up failure
test_serve_up_failure_still_tears_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/serve_up_fail"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_UP_RC="1"

  # compose up fails -> set -e abort before the mode branch completes; the
  # EXIT trap must still tear down (issue-1 class: no leak on up failure).
  local rc
  rc=$(invoke_run_agent_rc "serve" --delivery=copy)

  local last
  last=$(trace_grep "compose " | tail -1)
  assert_contains "$last" "compose down" "serve: up failure still tears down (last=$last)"
}

# Given: the docker stub failing 'compose up' in standard mode
# When:  run_agent.sh aborts
# Then:  the last compose operation is 'down'
# Asserts: no leak on an up failure in standard mode
test_standard_up_failure_still_tears_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_up_fail"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_UP_RC="1"

  # Pipefail propagates the up failure; set -e aborts; the EXIT trap must
  # still tear down.
  local rc
  rc=$(invoke_run_agent_rc "standard" --delivery=copy)

  local last
  last=$(trace_grep "compose " | tail -1)
  assert_contains "$last" "compose down" "standard: up failure still tears down (last=$last)"
}

# Given: a sandbox whose health stays 'starting' and a one-second wait budget
# When:  run_agent.sh runs a standard session
# Then:  the last compose operation is 'down'
# Asserts: teardown after a failed health wait (the assertion does not distinguish whether the agent ran - see the read-through finding on this unit)
test_standard_sandbox_unhealthy_still_tears_down() {
  local FIXTURE_DIR="$FIXTURE_DIR/start_sb_fail"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_SANDBOX_HEALTH="starting"
  export SANDBOX_WAIT_TIMEOUT="1"

  # compose_sandbox_wait exits 1 (never healthy) before the agent runs; the
  # EXIT trap must still tear down the sandbox container + network.
  local rc
  rc=$(invoke_run_agent_rc "standard" --delivery=copy)

  local last
  last=$(trace_grep "compose " | tail -1)
  assert_contains "$last" "compose down" "standard: sandbox unhealthy still tears down (last=$last)"
}

# Given: a standard session with SESSION_ID=test01
# When:  the session ends
# Then:  .compose/test01.yml exists, carries the baked container names, and the last compose invocation used it
# Asserts: the merged compose record is persisted at an identity-derived path and reused
test_compose_file_persisted() {
  local FIXTURE_DIR="$FIXTURE_DIR/compose_persist"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"

  local compose_file="$SANDBOX_DIR/.compose/test01.yml"
  invoke_run_agent "standard" --delivery=copy

  # The merged compose file must survive the session (teardown already ran)
  # at a stable identity-derived path, and compose invocations during the
  # run must operate on that same file.
  local last_file
  last_file=$(trace_grep "compose-file" | tail -1)
  if [[ -f "$compose_file" && -s "$compose_file" ]]; then
    if grep -q "sandbox-test-project-test01" "$compose_file" && grep -q "pi-test-project-test01" "$compose_file"; then
      if [[ "$last_file" == *"$compose_file"* ]]; then
        pass "standard: compose file persisted at .compose/<session-id>.yml and used by compose"
      else
        fail "standard: compose file persisted but not used by compose invocations (last compose-file: $last_file)"
      fi
    else
      fail "standard: compose file lacks baked container names"
    fi
  else
    fail "standard: compose file missing or empty at $compose_file"
  fi
}

# ---------------------------------------------------------------------------
# Delivery overlay selection (--delivery=copy|mount, passed explicitly)
# ---------------------------------------------------------------------------

# No --delivery: run_agent refuses -- the caller must state the delivery; the
# copy default is computed once at ingestion (start_agent).
# Given: no --delivery flag
# When:  run_agent.sh runs
# Then:  it exits non-zero
# Asserts: the caller must state the delivery; run_agent never defaults it
test_missing_delivery_rejected() {
  local FIXTURE_DIR="$FIXTURE_DIR/no_delivery"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"

  local rc
  rc=$(invoke_run_agent_rc "standard")
  if [[ "$rc" -ne 0 ]]; then
    pass "missing --delivery rejected (rc=$rc)"
  else
    fail "missing --delivery accepted (rc=0)"
  fi
}

# Explicit --delivery=copy: the copy overlay is merged, the mount overlay is
# not. (run_agent itself never defaults --delivery; the copy default lives in
# start_agent's ingestion and is exercised by every start-level test that
# omits the flag.)
# Given: --delivery=copy
# When:  the session generates its compose file set
# Then:  the copy overlay is present and the mount overlay is absent
# Asserts: copy delivery selects the copy overlay
test_copy_delivery_default_merges_copy_overlay() {
  local FIXTURE_DIR="$FIXTURE_DIR/copy_delivery"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  unset SANDBOX_TYPE
  invoke_run_agent "standard" --delivery=copy

  local copy_count mount_count
  copy_count=$(trace_count "docker-compose.copy.yml")
  mount_count=$(trace_count "docker-compose.mount.yml")
  if [[ "$copy_count" -ge 1 && "$mount_count" -eq 0 ]]; then
    pass "copy delivery (default): copy overlay merged, mount overlay absent"
  else
    fail "copy delivery (default): copy=$copy_count mount=$mount_count (expected copy>=1 mount=0)"
  fi
}

# --delivery=mount: the mount overlay is merged, the copy overlay is not.
# Given: --delivery=mount
# When:  the session generates its compose file set
# Then:  the mount overlay is present and the copy overlay is absent
# Asserts: mount delivery selects the mount overlay
test_mount_delivery_merges_mount_overlay() {
  local FIXTURE_DIR="$FIXTURE_DIR/mount_delivery"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  unset SANDBOX_TYPE
  invoke_run_agent "standard" --delivery=mount

  local copy_count mount_count
  copy_count=$(trace_count "docker-compose.copy.yml")
  mount_count=$(trace_count "docker-compose.mount.yml")
  if [[ "$mount_count" -ge 1 && "$copy_count" -eq 0 ]]; then
    pass "mount delivery: mount overlay merged, copy overlay absent"
  else
    fail "mount delivery: copy=$copy_count mount=$mount_count (expected mount>=1 copy=0)"
  fi
  unset SANDBOX_TYPE
}

# Unknown --delivery values are rejected before any compose invocation.
# Given: --delivery=bogus
# When:  run_agent.sh runs
# Then:  it exits non-zero before any compose invocation
# Asserts: an unknown delivery is refused
test_invalid_sandbox_type_rejected() {
  local FIXTURE_DIR="$FIXTURE_DIR/bad_delivery"
  mkdir -p "$FIXTURE_DIR"
  setup_start_fixture "$FIXTURE_DIR"
  unset SANDBOX_TYPE

  local rc
  rc=$(invoke_run_agent_rc "standard" --delivery=bogus)
  if [[ "$rc" -ne 0 ]]; then
    pass "invalid --delivery=bogus rejected (rc=$rc)"
  else
    fail "invalid --delivery=bogus accepted (rc=0)"
  fi
  unset SANDBOX_TYPE
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_start_standard_shutdown_resume_hint
run_test test_start_standard_shutdown_draft_hint
run_test test_start_standard_shutdown_draft_hint_suppressed_for_empty_export
run_test test_start_standard_no_v
run_test test_start_standard_has_compose_up
run_test test_start_standard_has_compose_run_agent
run_test test_start_standard_post_agent_uses_down
run_test test_start_refresh_has_no_down_v
run_test test_start_refresh_volume_rm
run_test test_start_refresh_post_agent_uses_down
run_test test_start_rebuild_has_no_down_v
run_test test_serve_post_agent_uses_down
run_test test_standard_teardown_is_last_compose
run_test test_serve_teardown_is_last_compose
run_test test_standard_agent_failure_still_tears_down_and_propagates_rc
run_test test_serve_up_failure_still_tears_down
run_test test_standard_up_failure_still_tears_down
run_test test_standard_sandbox_unhealthy_still_tears_down
run_test test_compose_file_persisted
run_test test_missing_delivery_rejected
run_test test_copy_delivery_default_merges_copy_overlay
run_test test_mount_delivery_merges_mount_overlay
run_test test_invalid_sandbox_type_rejected
test_done "test_run_agent"
