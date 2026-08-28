#!/usr/bin/env bash
# tests/test_trace_stop.sh
# Trace tests for agent-sandbox stop / prune subcommands.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../test/stubs"

setup_stop_fixture() {
  local FIXTURE_DIR="$1"
  export PROJECT_NAME="test-project"
  export SANDBOX_DIR="$FIXTURE_DIR/sandbox"
  export PROJECT_DIR="$FIXTURE_DIR/project"
  mkdir -p "$SANDBOX_DIR" "$PROJECT_DIR"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"
  :> "$DOCKER_TRACE_LOG"
  # Tests run in the same shell (run_test), so stub-ID vars must not leak
  # between tests.
  unset DOCKER_STUB_PS_IDS DOCKER_STUB_NETWORK_IDS DOCKER_STUB_FAIL_PS
  unset DOCKER_STUB_SESSION_ID_LABEL DOCKER_STUB_VOLUME_NAMES
  unset DOCKER_STUB_IMAGE_SIG_LABEL DOCKER_STUB_IMAGE_SIG_LABELS
}

make_committed_repo() {
  local dir="$1"
  git -C "$dir" init -q 2>/dev/null
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  : > "$dir/README"
  git -C "$dir" add -A
  git -C "$dir" commit -qm init
}

write_record() {
  # write_record SANDBOX_DIR SESSION_ID HOST_HEAD_SHA [SANDBOX_TYPE]
  local dir="$1" sid="$2" sha="$3" sbox_type="${4:-copy}"
  mkdir -p "$dir/.compose"
  cat > "$dir/.compose/$sid.yml" <<EOF
services:
  sandbox:
    image: sandbox-test-project
  agent:
    image: testprovider-agent-test-project
    labels:
      agent-sandbox.session-id: $sid
      agent-sandbox.session-ts: 20260801-000000
      agent-sandbox.host-head-sha: $sha
      agent-sandbox.host-branch: main
    environment:
      - SANDBOX_TYPE=$sbox_type
EOF
}

invoke_stop() {
  local FIXTURE_DIR="$1"; shift
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/stop.sh" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR" \
      --project="$PROJECT_DIR" \
      "$@"
  ) > /dev/null 2>&1 || true
}

invoke_prune() {
  local FIXTURE_DIR="$1"; shift
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/prune.sh" \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      "$@"
  )
}

trace_has() {
  grep -q "$1" "$DOCKER_TRACE_LOG" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_stop_no_compose() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_nc"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_stop "$FIXTURE_DIR"

  if trace_has "compose"; then
    fail "stop: docker compose should not be invoked"
  else
    pass "stop: no docker compose invocations"
  fi
}

test_stop_no_containers_does_not_teardown() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_none"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_stop "$FIXTURE_DIR"

  # Stub ps -aq returns nothing by default: no containers, no teardown.
  if trace_has "ps " && ! trace_has "rm "; then
    pass "stop: no containers -> ps only, no rm"
  else
    fail "stop: expected ps without rm when no containers"
  fi
}

test_stop_removes_containers() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_rm"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_PS_IDS="abc123def456 fedcba654321"
  invoke_stop "$FIXTURE_DIR"

  if trace_has "stop abc123def456" && trace_has "rm abc123def456"; then
    pass "stop: containers stopped and removed"
  else
    fail "stop: expected stop+rm for found containers"
  fi
}

test_stop_removes_networks() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_net"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_NETWORK_IDS="net1 net2"
  invoke_stop "$FIXTURE_DIR"

  if trace_has "network rm net1"; then
    pass "stop: session networks removed by label"
  else
    fail "stop: expected network rm for found networks"
  fi
}

test_stop_docker_failure_aborts() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_fail"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_FAIL_PS=1

  # stop.sh must abort when docker ps fails (set -e semantics), not
  # silently continue as if no containers exist.
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/stop.sh" \
      --name="$PROJECT_NAME" \
      --sandbox="$SANDBOX_DIR"
  ) > /dev/null 2>&1
  local rc=$?

  if [[ "$rc" -ne 0 ]]; then
    pass "stop: docker ps failure aborts the script (rc=$rc)"
  else
    fail "stop: expected nonzero rc on docker ps failure, got 0"
  fi
}

test_stop_prune_no_compose() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_pr_nc"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_stop "$FIXTURE_DIR" --prune

  if trace_has "compose"; then
    fail "stop --prune: docker compose should not be invoked"
  else
    pass "stop --prune: no docker compose invocations"
  fi
}

test_stop_prune_has_registrybased_prune() {
  local FIXTURE_DIR="$FIXTURE_DIR/stop_pr_sp"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  invoke_stop "$FIXTURE_DIR" --prune

  # stop --prune delegates to prune.sh (now registry-based  --  no docker system prune).
  if trace_has "system prune"; then
    fail "stop --prune: docker system prune should not be invoked (registry-based prune)"
  else
    pass "stop --prune: registry-based prune, no docker system prune"
  fi
}

test_prune_standalone_nothing_to_prune() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_sa_nc"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  local OUT
  OUT="$(invoke_prune "$FIXTURE_DIR")"

  if trace_has "compose"; then
    fail "prune (standalone): docker compose should not be invoked"
  elif echo "$OUT" | grep -q "Nothing to prune"; then
    pass "prune (standalone): no records/orphans -> 'Nothing to prune'"
  else
    fail "prune (standalone): expected 'Nothing to prune' with empty registry"
  fi
}

test_prune_rule1_removes_stale_records() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_r1_stale"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  make_committed_repo "$PROJECT_DIR"
  local current_sha
  current_sha="$(git -C "$PROJECT_DIR" rev-parse HEAD)"
  write_record "$SANDBOX_DIR" "stale1" "aaaa1111aaaa"        # stale (differs)
  write_record "$SANDBOX_DIR" "fresh1" "$current_sha"          # fresh (matches)

  invoke_prune "$FIXTURE_DIR" > /dev/null 2>&1

  if [[ ! -f "$SANDBOX_DIR/.compose/stale1.yml" && -f "$SANDBOX_DIR/.compose/fresh1.yml" ]]; then
    pass "prune Rule 1: stale record removed, fresh record kept"
  else
    fail "prune Rule 1: expected stale removed + fresh kept"
  fi
}

test_prune_rule2_removes_orphan_container() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_r2_orphan"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_PS_IDS="abc123def456"
  export DOCKER_STUB_SESSION_ID_LABEL="orphan1"   # no orphan1.yml record

  invoke_prune "$FIXTURE_DIR" > /dev/null 2>&1

  if trace_has "rm abc123def456"; then
    pass "prune Rule 2: orphaned container removed"
  else
    fail "prune Rule 2: expected orphaned container rm in trace"
  fi
}

test_prune_stale_image_selects_image_stale_record() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_img_stale"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  make_committed_repo "$PROJECT_DIR"
  write_record "$SANDBOX_DIR" "imgstale" "aaaa1111aaaa"
  # Baked container-sig differs from the recomputed source sig -> image-stale.
  export DOCKER_STUB_IMAGE_SIG_LABEL="definitely-stale-sig"

  invoke_prune "$FIXTURE_DIR" --stale=image > /dev/null 2>&1

  if [[ ! -f "$SANDBOX_DIR/.compose/imgstale.yml" ]]; then
    pass "prune --stale=image: selects and removes an image-stale record"
  else
    fail "prune --stale=image: expected image-stale record removed"
  fi
}

test_prune_dry_run_removes_nothing() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_dryrun"
  mkdir -p "$FIXTURE_DIR"
  setup_stop_fixture "$FIXTURE_DIR"
  make_committed_repo "$PROJECT_DIR"
  write_record "$SANDBOX_DIR" "stale1" "aaaa1111aaaa"

  local OUT
  OUT="$(invoke_prune "$FIXTURE_DIR" --dry-run)"

  if echo "$OUT" | grep -q "rule 1" -i && [[ -f "$SANDBOX_DIR/.compose/stale1.yml" ]]; then
    pass "prune --dry-run: shows plan but leaves record in place"
  else
    fail "prune --dry-run: expected plan shown and no record removed"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_stop_no_compose
run_test test_stop_no_containers_does_not_teardown
run_test test_stop_removes_containers
run_test test_stop_removes_networks
run_test test_stop_docker_failure_aborts
run_test test_stop_prune_no_compose
run_test test_stop_prune_has_registrybased_prune
run_test test_prune_standalone_nothing_to_prune
run_test test_prune_rule1_removes_stale_records
run_test test_prune_rule2_removes_orphan_container
run_test test_prune_stale_image_selects_image_stale_record
run_test test_prune_dry_run_removes_nothing

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
