#!/usr/bin/env bash
# tests/test_trace_dry_run.sh
# Trace tests for agent-sandbox dry-run subcommand.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"

setup_dry_run_fixture() {
  local FIXTURE_DIR="$1"

  export PROJECT_NAME="test-project"
  export PROVIDER_NAME="pi"
  export SANDBOX_DIR="$FIXTURE_DIR/sandbox"
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

  mkdir -p "$SANDBOX_DIR" "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"
  mkdir -p "$SANDBOX_DIR/.pi"

  # Seedable project fixture: the dry-run path seeds the sandbox volume from
  # PROJECT_DIR (git-enumerated seed), so the trace fixture needs a real git
  # repo with at least one commit.
  mkdir -p "$FIXTURE_DIR/project"
  git -C "$FIXTURE_DIR/project" init --quiet
  git -C "$FIXTURE_DIR/project" config user.email "trace@sandbox"
  git -C "$FIXTURE_DIR/project" config user.name "trace"
  echo "trace fixture" > "$FIXTURE_DIR/project/file.txt"
  git -C "$FIXTURE_DIR/project" add -A
  git -C "$FIXTURE_DIR/project" commit --quiet -m "trace fixture"
  export PROJECT_DIR="$FIXTURE_DIR/project"

  cat > "$SANDBOX_DIR/.env" << EOF
SANDBOX_DIR=$SANDBOX_DIR
PROJECT_DIR=$FIXTURE_DIR/project
EOF

  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"
  :> "$DOCKER_TRACE_LOG"
}

invoke_dry_run() {
  (
    exec() { echo "[exec overridden: $*]" >&2; return 0; }
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/run_agent.sh" "dry-run" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      "$@"
  ) > /dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_dry_run_has_compose_up() {
  local FIXTURE_DIR="$FIXTURE_DIR/dry_up"
  mkdir -p "$FIXTURE_DIR"
  setup_dry_run_fixture "$FIXTURE_DIR"
  DRY_RUN_RECORD_TIMEOUT=2 invoke_dry_run --delivery=copy

  if trace_has "compose up"; then
    pass "dry-run: 'compose up -d' issued"
  else
    fail "dry-run: 'compose up -d' not found in trace"
  fi
}

test_dry_run_no_compose_exec() {
  local FIXTURE_DIR="$FIXTURE_DIR/dry_noexec"
  mkdir -p "$FIXTURE_DIR"
  setup_dry_run_fixture "$FIXTURE_DIR"
  DRY_RUN_RECORD_TIMEOUT=2 invoke_dry_run --delivery=copy

  if trace_has "compose exec"; then
    fail "dry-run: 'compose exec' should NOT be issued (probes run at start-up)"
  else
    pass "dry-run: no 'compose exec' (probes run at start-up)"
  fi
}

# The dry-run always ends with a full teardown (down -v): the resume exercise
# completes and nothing is kept. The pass-1 stop (down, volume kept) is what
# makes the second pass a resume.
test_dry_run_always_tears_down_with_volumes() {
  local FIXTURE_DIR="$FIXTURE_DIR/dry_teardown"
  mkdir -p "$FIXTURE_DIR"
  setup_dry_run_fixture "$FIXTURE_DIR"
  DRY_RUN_RECORD_TIMEOUT=2 invoke_dry_run --delivery=copy

  if [[ $(trace_count "compose down -v") -eq 1 ]] \
     && [[ $(grep -cE "compose down *$" "$DOCKER_TRACE_LOG") -eq 1 ]]; then
    pass "dry-run: one stop (down, volume kept) + one final teardown (down -v)"
  else
    fail "dry-run teardown sequence wrong: down_count=$(trace_count 'compose down') down_v_count=$(trace_count 'compose down -v')"
  fi
}

# The resume testbed: the dry-run runs TWO passes -- up, verify, down (volume
# kept), up again (resume), verify, down -v. Both passes reuse one compose
# project (same session id), so the second up targets the kept volume.
test_dry_run_exercises_resume_pass() {
  local FIXTURE_DIR="$FIXTURE_DIR/dry_resume_pass"
  mkdir -p "$FIXTURE_DIR"
  setup_dry_run_fixture "$FIXTURE_DIR"
  DRY_RUN_RECORD_TIMEOUT=2 invoke_dry_run --delivery=copy

  local ups downs
  ups=$(trace_count "compose up")
  downs=$(trace_count "compose down")
  if [[ "$ups" -eq 2 && "$downs" -eq 2 ]] \
     && grep -q "compose down -v" "$DOCKER_TRACE_LOG"; then
    pass "dry-run: two passes (fresh + resume) with a kept-volume stop between"
  else
    fail "dry-run pass sequence wrong: ups=$ups downs=$downs"
  fi
}

# A failed `compose up` must still tear the dry-run project down (destroying
# the seeded volume -- nothing is kept from a failed dry-run) and exit nonzero.
# The test distinguishes down from down -v: a bare down would leave the volume.
test_dry_run_up_failure_tears_down_and_fails() {
  local FIXTURE_DIR="$FIXTURE_DIR/dry_upfail"
  mkdir -p "$FIXTURE_DIR"
  setup_dry_run_fixture "$FIXTURE_DIR"
  local RC=0
  (
    export PATH="$STUB_DIR:$PATH"
    DRY_RUN_RECORD_TIMEOUT=2 DOCKER_STUB_UP_RC=7 \
      bash "$REPO_ROOT/scripts/run_agent.sh" "dry-run" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" \
      --provider="$PROVIDER_NAME" \
      --delivery=copy
  ) >/dev/null 2>&1 || RC=$?
  if [[ "$RC" -ne 0 ]] && [[ $(trace_count "compose down -v") -ge 1 ]]; then
    pass "dry-run up-failure: volume-destroying teardown issued and exit code nonzero"
  else
    fail "dry-run up-failure: rc=$RC down_v_count=$(trace_count 'compose down -v')"
  fi
}

# Mount delivery dry-run: the mount overlay is stacked in dry-run mode too
# (delivery-agnostic readiness), binding the worktree. The probe write surface
# stays confined to workspace channels (CHANGES_DIR/OUTPUT_DIR) and .git
# metadata -- never tracked repo content (hygiene gate, handover 20260912-10).
test_dry_run_mount_overlay_stacked_and_probe_hygiene() {
  local FIXTURE_DIR="$FIXTURE_DIR/dry_mount"
  mkdir -p "$FIXTURE_DIR"
  setup_dry_run_fixture "$FIXTURE_DIR"
  DRY_RUN_RECORD_TIMEOUT=2 invoke_dry_run --delivery=mount

  if trace_has "docker-compose.mount.yml"; then
    pass "dry-run (mount): mount overlay stacked into compose invocation"
  else
    fail "dry-run (mount): mount overlay not in compose invocation"
  fi

  # Probe hygiene: no probe writes into the delivery target (SANDBOX_DIR).
  # Allowed write roots are CHANGES_DIR, OUTPUT_DIR, INPUT_DIR (channel
  # contract) and allocator dirs (get_fixture_dir). The one in-mount write, .git/SESSION_STATE,
  # belongs to the entrypoint, not the probes. Match write-shaped constructs
  # (redirection, touch/mkdir/tee/cp/mv/rm) referencing $SANDBOX_DIR; reads
  # (find/du/test/cat/session_state_read) are fine.
  local offenders
  offenders=$(grep -nE 'SANDBOX_DIR' \
    "$REPO_ROOT/scripts/dry_run_capability.sh" "$REPO_ROOT/scripts/dry_run_reasoning.sh" \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
    | grep -E '(>>?[^|]*\$SANDBOX_DIR|\b(touch|mkdir|tee|cp|mv|rm)\b.*\$SANDBOX_DIR)' \
    | grep -vE 'SESSION_STATE' || true)
  assert_empty "$offenders" "dry-run probes: no writes into the delivery target"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_dry_run_has_compose_up
run_test test_dry_run_no_compose_exec
run_test test_dry_run_always_tears_down_with_volumes
run_test test_dry_run_exercises_resume_pass
run_test test_dry_run_up_failure_tears_down_and_fails
run_test test_dry_run_mount_overlay_stacked_and_probe_hygiene

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

