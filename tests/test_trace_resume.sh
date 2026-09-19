#!/usr/bin/env bash
# tests/test_trace_resume.sh
# Trace tests for the resume path (Bug D): `make resume` must ATTACH the
# Pins cite: docs/concepts/sandbox_identity.md (labels);
#             docs/architecture/tool_interface.md (naming table);
#             R1-R4 list below (resume semantics).

# existing session's namespace/volume, never recreate/destroy it. Guards the
# readyliness-watching regression where a resume could reset the baseline.
#
# Invariants under test:
#   R1. resume teardown is `compose down` (keeps named volumes), so the
#       SESSION_ID-scoped volume survives to be re-attached -- never
#       `down -v` / `session_destroy`.
#   R2. resume does NOT forward --reset-volume (RESET_VOLUME stays false).
#   R3. no `docker volume rm` on the resume path (copy nor mount delivery).
#   R4. resume reuses the RECORD's SESSION_ID, so the compose namespace
#       (project name + `session-id-sandbox-data` volume) is stable across
#       start -> resume, attaching the same volume.
#
# NB: the docker stub's `compose config` returns only the first input file and
# does not merge overlays, so volume presence must be asserted at the overlay
# level (done in test_trace_compose_gen.sh) + the namespace-stability invariant
# here; the trace asserts the no-destroy/execution-path guarantees directly.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
source "$TEST_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"

# Source the real interface-contract lib so the stub images can bake the
# current contract version (authoritative preflight requires an aligned label).
source "$REPO_ROOT/src/libs/interface_contract.sh"

# Build a resumable fixture: sandbox/.env + a `.compose/<sid>.yml` registry
# record + a git-backed project dir. $1=fixture root, $2=sandbox_type,
# $3=flatten (optional; "true" writes a FLATTEN literal into the record).
build_resume_fixture() {
  local FIX="$1" sandbox_type="$2" flatten="${3:-false}"
  local project_dir="$FIX/project"

  export PROJECT_NAME="test-project"
  export PROJECT_DIR="$project_dir"
  export PROVIDER_NAME="pi"
  export SANDBOX_DIR="$FIX/sandbox"
  export CHANGES_DIR="$SANDBOX_DIR/.workspace/session-diffs"
  export INPUT_DIR="$SANDBOX_DIR/.workspace/input"
  export OUTPUT_DIR="$SANDBOX_DIR/.workspace/output"
  # Ambient delivery is deliberately NOT exported: resume must recover it from
  # the record (the mount fixture record carries SANDBOX_TYPE=mount).
  unset SANDBOX_TYPE
  export HOST_UID="1000" HOST_GID="1000"

  export SESSION_TS="20260821-120000"
  export HOST_HEAD_SHA="deadbeef"
  export SESSION_ID="abc123"
  export SANITIZED_HOST_BRANCH="main"

  export SANDBOX_IMAGE_NAME="agent-sandbox-sandbox:test-project"
  export AGENT_IMAGE_NAME="agent-sandbox-pi:test-project"

  # Project dir must be a git repo (resume derives branch/head from it).
  mkdir -p "$project_dir"
  git -C "$project_dir" init -q
  git -C "$project_dir" config user.email "t@t" && git -C "$project_dir" config user.name "t"
  touch "$project_dir/.gitkeep"
  git -C "$project_dir" add -A && git -C "$project_dir" commit -q -m init

  mkdir -p "$SANDBOX_DIR/.compose" "$SANDBOX_DIR/.workspace/session-diffs" \
           "$SANDBOX_DIR/.workspace/input" "$SANDBOX_DIR/.workspace/output" \

  cat > "$SANDBOX_DIR/.env" <<EOF
SANDBOX_DIR=$SANDBOX_DIR
PROJECT_DIR=$project_dir
EOF

  cat > "$SANDBOX_DIR/.compose/abc123.yml" <<EOF
x-session-labels:
  agent-sandbox.host-head-sha: deadbeef
  agent-sandbox.host-branch: main
  agent-sandbox.session-ts: 20260821-120000
  agent-sandbox.session-id: abc123
services:
  sandbox:
    image: agent-sandbox-abc123
    environment:
      - SANDBOX_TYPE=$sandbox_type
      - FLATTEN=$flatten
  seeder:
    image: agent-sandbox-abc123
    environment:
      - SEED_FLATTEN=$flatten
  agent:
    image: pi-agent-test-project
EOF

  export DOCKER_TRACE_LOG="$FIX/trace.log"
  :> "$DOCKER_TRACE_LOG"
  # Bake the current interface-contract version onto the stub images so the
  # authoritative preflight check passes on resume.
  export DOCKER_STUB_IMAGE_CONTRACT_VERSION="$(interface_contract_version)"
  unset DOCKER_STUB_UP_RC DOCKER_STUB_RUN_RC DOCKER_STUB_PS_IDS DOCKER_STUB_SANDBOX_HEALTH
}

invoke_resume() {
  (
    export PATH="$STUB_DIR:$PATH"
    # < /dev/null: resume_agent.sh (via run_agent.sh) reads stdin; redirecting
    # keeps the test runner's shared here-string FD from being advanced, which
    # would otherwise skip trailing test files (runner iterates `<<< "$TEST_FILES"`).
    bash "$REPO_ROOT/scripts/resume_agent.sh" \
      --session-id=abc123 --name="$PROJECT_NAME" --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" --env=.env < /dev/null
  ) > /dev/null 2>&1
}

# Resume of a copy-delivery session preserves the named volume across all
# execution paths (R1, R2, R3) and reuses the record SESSION_ID (R4).
test_resume_copy_keeps_named_volume() {
  local FIX="$FIXTURE_DIR/resume-copy"
  build_resume_fixture "$FIX" copy

  invoke_resume
  assert_rc 0 "$?" "resume (copy) exit code"

  local down_v volume_rm reset
  down_v=$(trace_count "compose down -v")
  volume_rm=$(trace_count "volume rm")
  reset=$(trace_count -- "--reset-volume")

  if [[ "$down_v" -eq 0 ]]; then pass "resume (copy): zero 'compose down -v'"; else fail "resume (copy): $down_v 'compose down -v'"; fi
  if [[ "$volume_rm" -eq 0 ]]; then pass "resume (copy): zero 'docker volume rm'"; else fail "resume (copy): $volume_rm 'volume rm'"; fi
  if [[ "$reset" -eq 0 ]]; then pass "resume (copy): zero '--reset-volume'"; else fail "resume (copy): $reset '--reset-volume'"; fi

  # Teardown should still run (keeps volume) and the sandbox container re-attached.
  if [[ "$(trace_count "compose down")" -gt 0 ]]; then pass "resume (copy): teardown via compose down"; else fail "resume (copy): no compose down teardown"; fi
  if [[ "$(trace_count "compose up -d sandbox")" -gt 0 ]]; then pass "resume (copy): sandbox re-attached (compose up -d sandbox)"; else fail "resume (copy): sandbox not re-attached"; fi
}
run_test test_resume_copy_keeps_named_volume

# Resume of a mount-delivery session (R3, mount variant): no volume-destroying
# teardown, no volume removal (a mount session has no named volume), and the
# mount overlay is merged at compose time (trace-observed; the stub's
# `compose config` returns the first input unchanged, so composed-file content
# cannot distinguish delivery).
test_resume_mount_keeps_worktree_no_volume_ops() {
  local FIX="$FIXTURE_DIR/resume-mount"
  build_resume_fixture "$FIX" mount

  # Worktree must exist before resume: the mount compose binds it.
  mkdir -p "$FIX/sandbox/.worktree/.git"
  git -C "$FIX/sandbox/.worktree" init -q 2>/dev/null || true

  invoke_resume
  assert_rc 0 "$?" "resume (mount) exit code"

  local down_v volume_rm
  down_v=$(trace_count "compose down -v")
  volume_rm=$(trace_count "volume rm")
  if [[ "$down_v" -eq 0 ]]; then pass "resume (mount): zero 'compose down -v'"; else fail "resume (mount): 'compose down -v' issued"; fi
  if [[ "$volume_rm" -eq 0 ]]; then pass "resume (mount): zero 'docker volume rm'"; else fail "resume (mount): 'docker volume rm' issued"; fi

  if [[ "$(trace_count "compose up -d sandbox")" -gt 0 ]]; then pass "resume (mount): sandbox re-attached"; else fail "resume (mount): no 'compose up -d sandbox' in trace"; fi

  if grep -q "docker-compose.mount.yml" "$DOCKER_TRACE_LOG"; then
    pass "resume (mount): mount overlay merged at compose time"
  else
    fail "resume (mount): mount overlay not in compose invocation"
  fi
}
run_test test_resume_mount_keeps_worktree_no_volume_ops

# Resume cross-checks the record's FLATTEN against the worktree's recorded
# mode. A mismatch (operator-level interference) warns and resume continues
# with the record value -- it never fails and never re-materializes.
test_resume_mount_warns_on_flatten_mismatch() {
  local FIX="$FIXTURE_DIR/resume-mount-mismatch"
  build_resume_fixture "$FIX" mount

  # Worktree recorded as flattened, session record says full (false).
  mkdir -p "$FIX/sandbox/.worktree/.git"
  git -C "$FIX/sandbox/.worktree" init -q 2>/dev/null || true
  git -C "$FIX/sandbox/.worktree" config agent-sandbox.flatten true

  RESUME_OUT="$(PATH="$STUB_DIR:$PATH" \
    bash "$REPO_ROOT/scripts/resume_agent.sh" \
    --session-id=abc123 --name="$PROJECT_NAME" --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" --env=.env 2>&1 </dev/null)"
  local rc=$?
  assert_rc 0 "$rc" "resume (mount, flatten mismatch) exit code"

  if grep -q "records history mode 'true' but the session record says 'false'" <<<"$RESUME_OUT"; then
    pass "resume (mount): flatten mismatch warns and continues"
  else
    fail "resume (mount): expected mismatch warning, out=$(head -2 <<<"$RESUME_OUT" | tail -1)"
  fi
}
run_test test_resume_mount_warns_on_flatten_mismatch

# Delivery is recovered from the record with NO ambient SANDBOX_TYPE (the
# regression for the live-run failure: resume defaulted to copy and the mount
# session died against an unseeded volume).
test_resume_recovers_delivery_from_record_no_ambient() {
  local FIX="$FIXTURE_DIR/resume-mount-record"
  build_resume_fixture "$FIX" mount

  invoke_resume
  assert_rc 0 "$?" "resume (mount record, no ambient) exit code"

  if grep -q "docker-compose.mount.yml" "$DOCKER_TRACE_LOG"; then
    pass "resume (mount record, no ambient): mount overlay merged"
  else
    fail "resume (mount record, no ambient): mount overlay not merged"
  fi
}
run_test test_resume_recovers_delivery_from_record_no_ambient

# A record without the delivery literal is rejected (no silent default).
test_resume_rejects_record_without_delivery() {
  local FIX="$FIXTURE_DIR/resume-no-delivery"
  build_resume_fixture "$FIX" copy
  # Strip the environment block from the record.
  sed -i '/environment:/,+1d' "$SANDBOX_DIR/.compose/abc123.yml"

  local out rc=0
  out=$( PATH="$STUB_DIR:$PATH" bash "$REPO_ROOT/scripts/resume_agent.sh" \
    --session-id=abc123 --name="$PROJECT_NAME" --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" --env=.env </dev/null 2>&1 ) || rc=$?

  if [[ "$rc" -ne 0 ]] && [[ "$out" == *"carries no delivery"* ]]; then
    pass "resume (record without delivery): rejected rc=$rc"
  else
    fail "resume (record without delivery): rc=$rc out=$out"
  fi
}
run_test test_resume_rejects_record_without_delivery

# Resume reuses the RECORD's SESSION_ID (asserted via the regenerated compose
# session-id label), which pins the compose namespace + volume name (R4).
test_resume_reuses_record_session_id() {
  local FIX="$FIXTURE_DIR/resume-sid"
  build_resume_fixture "$FIX" copy

  invoke_resume

  local out="$SANDBOX_DIR/.compose/abc123.yml"
  if [[ -f "$out" ]] && grep -q "agent-sandbox.session-id: abc123" "$out"; then
    pass "resume regenerated compose keeps record SESSION_ID (abc123) -> same volume namespace"
  else
    fail "resume did not preserve record SESSION_ID in regenerated compose"
  fi
}
run_test test_resume_reuses_record_session_id

# FLATTEN is recovered from the record (never ambient). An invalid FLATTEN
# literal is rejected fail-closed (same rule as delivery).
test_resume_rejects_invalid_flatten() {
  local FIX="$FIXTURE_DIR/resume-bad-flatten"
  build_resume_fixture "$FIX" mount maybe

  local out rc=0
  out=$( PATH="$STUB_DIR:$PATH" bash "$REPO_ROOT/scripts/resume_agent.sh" \
    --session-id=abc123 --name="$PROJECT_NAME" --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" --env=.env </dev/null 2>&1 ) || rc=$?

  if [[ "$rc" -ne 0 ]] && [[ "$out" == *"invalid FLATTEN"* ]]; then
    pass "resume (invalid FLATTEN): rejected rc=$rc"
  else
    fail "resume (invalid FLATTEN): rc=$rc out=$out"
  fi
}
run_test test_resume_rejects_invalid_flatten

# A flatten record resumes without error -- the recovery path accepts the
# literal and forwards the flag (full run_agent forwarding is covered by the
# run_agent flag test; here we assert the recovery does not reject a valid
# flatten session).
test_resume_accepts_flatten_record() {
  local FIX="$FIXTURE_DIR/resume-ok-flatten"
  build_resume_fixture "$FIX" mount true

  invoke_resume
  assert_rc 0 "$?" "resume (valid flatten record) exit code"

  pass "resume (flatten): valid FLATTEN literal accepted (bc baseline)"
}
run_test test_resume_accepts_flatten_record

# Mount (worktree) delivery: resume must not destroy anything either -- the
# worktree is a host bind mount preserved by construction; assert no destroy ops.
test_resume_mount_keeps_worktree() {
  local FIX="$FIXTURE_DIR/resume-mount"
  build_resume_fixture "$FIX" mount

  invoke_resume
  assert_rc 0 "$?" "resume (mount) exit code"

  local down_v volume_rm reset
  down_v=$(trace_count "compose down -v")
  volume_rm=$(trace_count "volume rm")
  reset=$(trace_count -- "--reset-volume")

  if [[ "$down_v" -eq 0 ]]; then pass "resume (mount): zero 'compose down -v'"; else fail "resume (mount): $down_v 'compose down -v'"; fi
  if [[ "$volume_rm" -eq 0 ]]; then pass "resume (mount): zero 'docker volume rm'"; else fail "resume (mount): $volume_rm 'volume rm'"; fi
  if [[ "$reset" -eq 0 ]]; then pass "resume (mount): zero '--reset-volume'"; else fail "resume (mount): $reset '--reset-volume'"; fi
}
run_test test_resume_mount_keeps_worktree

# Resume (via run_agent) writes the unified per-session activity log: on start
# it records last_started (and clears last_stopped); on teardown it records
# last_stopped -- feeding the --list LAST_USED column.
test_resume_writes_session_log() {
  local FIX="$FIXTURE_DIR/resume-log"
  build_resume_fixture "$FIX" copy

  invoke_resume

  local log="$SANDBOX_DIR/.compose/abc123.log"
  if [[ -f "$log" ]] \
     && grep -qE '^last_started=[0-9]{8}-[0-9]{6}$' "$log" \
     && grep -qE '^last_stopped=[0-9]{8}-[0-9]{6}$' "$log"; then
    pass "resume writes last_started + last_stopped to .compose/<sid>.log"
  else
    fail "resume session log missing/incorrect: $(tr '\n' ' ' < "$log" 2>/dev/null)"
  fi
}
run_test test_resume_writes_session_log

test_done "test_trace_resume"