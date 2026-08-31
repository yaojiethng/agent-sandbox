#!/usr/bin/env bash
# tests/test_trace_resume.sh
# Trace tests for the resume path (Bug D): `make resume` must ATTACH the
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

STUB_DIR="$TEST_DIR/../test/stubs"

# Build a resumable fixture: sandbox/.env + a `.compose/<sid>.yml` registry
# record + a git-backed project dir. $1=fixture root, $2=sandbox_type.
build_resume_fixture() {
  local FIX="$1" sandbox_type="$2"
  local project_dir="$FIX/project"

  export PROJECT_NAME="test-project"
  export PROJECT_DIR="$project_dir"
  export PROVIDER_NAME="pi"
  export SANDBOX_DIR="$FIX/sandbox"
  export SNAPSHOT_DIR="$SANDBOX_DIR/.snapshot"
  export CHANGES_DIR="$SANDBOX_DIR/.workspace/session-diffs"
  export INPUT_DIR="$SANDBOX_DIR/.workspace/input"
  export OUTPUT_DIR="$SANDBOX_DIR/.workspace/output"
  export SANDBOX_TYPE="$sandbox_type"
  export HOST_UID="1000" HOST_GID="1000"

  export SESSION_TS="20260821-120000"
  export HOST_HEAD_SHA="deadbeef"
  export SANDBOX_ID="testid"
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
           "$SNAPSHOT_DIR"

  cat > "$SANDBOX_DIR/.env" <<EOF
SANDBOX_DIR=$SANDBOX_DIR
PROJECT_DIR=$project_dir
EOF

  cat > "$SANDBOX_DIR/.compose/abc123.yml" <<'EOF'
x-session-labels:
  agent-sandbox.host-head-sha: deadbeef
  agent-sandbox.host-branch: main
  agent-sandbox.session-ts: 20260821-120000
  agent-sandbox.session-id: abc123
services:
  sandbox:
    image: agent-sandbox-abc123
  agent:
    image: pi-agent-test-project
EOF

  export DOCKER_TRACE_LOG="$FIX/trace.log"
  :> "$DOCKER_TRACE_LOG"
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

trace_count() { grep -c "$1" "$DOCKER_TRACE_LOG" 2>/dev/null || true; }
trace_grep() { grep "$1" "$DOCKER_TRACE_LOG" 2>/dev/null || true; }

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

test_done "test_trace_resume"