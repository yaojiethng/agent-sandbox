#!/usr/bin/env bash
# tests/test_capability_entrypoint_mount.sh
# Behavioral tests for the mount-delivery branch of src/capability/entrypoint.sh.
#
# Covers:
#   mount fail-closed      --  worktree without .git aborts (rc=1, remediation text)
#   first mount run        --  writes SESSION_STATE init marker (init_sha, session_ts,
#                              session_id, host_head_sha) + workspace path fields
#   attach re-run          --  pre-existing SESSION_STATE identity fields not overwritten
#
# Runs the real entrypoint with SANDBOX_LIB_DIR pointing at the stub lib dir
# (tests/stubs/libs). That dir carries a no-op snapshot.sh -- the entrypoint
# lists it CRITICAL and sources it unconditionally, but no test path here
# invokes it.
#
# Run:   bash tests/test_capability_entrypoint_mount.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

ENTRYPOINT="$REPO_ROOT/src/capability/entrypoint.sh"
STUB_LIB_DIR="$TEST_DIR/stubs/libs"

# invoke_entrypoint_mount DIR
#   Runs DIR/entrypoint.sh (a sed-patched copy -- ROOT rewritten to DIR) in
#   the background with mount env, waits for preflight to pass, SIGTERMs it
#   (docker stop's signal), and collects the exit code. Globals set: EP_RC,
#   EP_OUT.
invoke_entrypoint_mount() {
  local dir="$1"
  ( cd "$dir" && SANDBOX_LIB_DIR="$STUB_LIB_DIR" \
    SANDBOX_TYPE=mount \
    SANDBOX_DIR_NAME=worktree \
    CHANGES_DIR="$dir/.workspace/session-diffs" \
    INPUT_DIR="$dir/.workspace/input" \
    OUTPUT_DIR="$dir/.workspace/output" \
    SESSION_TS="20260912-120000" SESSION_ID="mnt000" \
    HOST_HEAD_SHA="cafebabe" HOST_UID="$(id -u)" HOST_GID="$(id -g)" \
    AUTOSAVE_INTERVAL=0 \
    bash "$dir/entrypoint.sh" ) >"$dir/log" 2>&1 &
  local pid=$!
  for _ in $(seq 1 100); do
    grep -q "ALL CHECKS PASSED" "$dir/log" 2>/dev/null && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  kill -TERM "$pid" 2>/dev/null
  wait "$pid"
  EP_RC=$?
  EP_OUT=$(cat "$dir/log")
}

# run_entrypoint DIR
#   Builds a worktree fixture (git repo + .git) under DIR, patches the
#   entrypoint copy, and invokes it. The source hardcodes the container
#   convention ROOT=/home/agentuser, which must not be created on the host.
#   Globals set: EP_RC, EP_OUT, EP_STATE.
run_entrypoint() {
  local dir="$1"
  local worktree="$dir/worktree"
  mkdir -p "$worktree" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  git -C "$worktree" init -q
  git -C "$worktree" config user.email "t@t" && git -C "$worktree" config user.name "t"
  echo "worktree content" > "$worktree/file.txt"
  git -C "$worktree" add -A && git -C "$worktree" commit -q -m baseline
  EP_STATE="$worktree/.git/SESSION_STATE"

  sed "s|^ROOT=.*$|ROOT="$dir"|" "$ENTRYPOINT" > "$dir/entrypoint.sh"
  invoke_entrypoint_mount "$dir"
}

test_mount_fail_closed_no_git() {
  local dir="$FIXTURE_DIR/mount_nogit"
  mkdir -p "$dir/worktree" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  # Worktree without .git -- host materialization did not run.
  sed "s|^ROOT=.*$|ROOT="$dir"|" "$ENTRYPOINT" > "$dir/entrypoint.sh"
  EP_OUT="$(cd "$dir" && SANDBOX_LIB_DIR="$STUB_LIB_DIR" \
    SANDBOX_TYPE=mount \
    SANDBOX_DIR_NAME=worktree \
    CHANGES_DIR="$dir/.workspace/session-diffs" \
    INPUT_DIR="$dir/.workspace/input" \
    OUTPUT_DIR="$dir/.workspace/output" \
    AUTOSAVE_INTERVAL=0 \
    timeout 10 bash "$dir/entrypoint.sh" 2>&1)"
  EP_RC=$?
  if [[ "$EP_RC" -ne 0 ]]; then
    pass "mount without .git: entrypoint fails closed (rc=$EP_RC)"
  else
    fail "mount without .git: entrypoint exited 0, expected failure"
  fi
  if [[ "$EP_OUT" == *"no .git"* ]]; then
    pass "mount without .git: remediation message names the missing .git"
  else
    fail "mount without .git: remediation message missing (got: $EP_OUT)"
  fi
}

test_mount_first_run_writes_init_marker() {
  local dir="$FIXTURE_DIR/mount_first"
  run_entrypoint "$dir"
  if [[ "$EP_RC" -ne 0 ]]; then
    fail "first mount run: entrypoint rc=$EP_RC: $EP_OUT"; return
  fi
  pass "first mount run: entrypoint completes and exports (rc=0)"

  if [[ -f "$EP_STATE" ]]; then
    pass "first mount run: SESSION_STATE written into worktree .git"
  else
    fail "first mount run: SESSION_STATE missing at $EP_STATE"; return
  fi

  local init_sha session_ts session_id host_sha
  init_sha=$(grep '^init_sha=' "$EP_STATE" | cut -d= -f2-)
  session_ts=$(grep '^session_ts=' "$EP_STATE" | cut -d= -f2-)
  session_id=$(grep '^session_id=' "$EP_STATE" | cut -d= -f2-)
  host_sha=$(grep '^host_head_sha=' "$EP_STATE" | cut -d= -f2-)

  if git -C "$(dirname "$(dirname "$EP_STATE")")" cat-file -e "$init_sha^{commit}" 2>/dev/null; then
    pass "first mount run: init_sha is a valid commit in the worktree"
  else
    fail "first mount run: init_sha '$init_sha' not a valid commit"
  fi
  if [[ "$session_ts" == "20260912-120000" && "$session_id" == "mnt000" && "$host_sha" == "cafebabe" ]]; then
    pass "first mount run: identity fields match start env"
  else
    fail "first mount run: identity fields wrong (ts=$session_ts id=$session_id host=$host_sha)"
  fi

  grep -q '^changes_dir=' "$EP_STATE" && grep -q '^input_dir=' "$EP_STATE" \
    && grep -q '^output_dir=' "$EP_STATE" \
    && pass "first mount run: workspace path fields written" \
    || fail "first mount run: workspace path fields missing"
}

test_mount_attach_preserves_existing_state() {
  local dir="$FIXTURE_DIR/mount_attach"
  mkdir -p "$dir/worktree" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  git -C "$dir/worktree" init -q
  git -C "$dir/worktree" config user.email "t@t" && git -C "$dir/worktree" config user.name "t"
  echo x > "$dir/worktree/f" && git -C "$dir/worktree" add -A
  git -C "$dir/worktree" commit -q -m baseline
  # Pre-existing marker from an earlier session: identity must survive attach.
  printf 'init_sha=older\nsession_ts=OLD\nsession_id=oldses\nhost_head_sha=old\n' \
    > "$dir/worktree/.git/SESSION_STATE"
  EP_STATE="$dir/worktree/.git/SESSION_STATE"

  sed "s|^ROOT=.*$|ROOT="$dir"|" "$ENTRYPOINT" > "$dir/entrypoint.sh"
  invoke_entrypoint_mount "$dir"

  if [[ "$EP_RC" -ne 0 ]]; then
    fail "attach re-run: entrypoint rc=$EP_RC: $EP_OUT"; return
  fi
  if grep -q '^session_id=oldses$' "$EP_STATE" && grep -q '^session_ts=OLD$' "$EP_STATE"; then
    pass "attach re-run: pre-existing identity not overwritten"
  else
    fail "attach re-run: identity fields were overwritten"
  fi
  if grep -q '^changes_dir=' "$EP_STATE"; then
    pass "attach re-run: workspace path fields refreshed"
  else
    fail "attach re-run: workspace path fields missing"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_mount_fail_closed_no_git
run_test test_mount_first_run_writes_init_marker
run_test test_mount_attach_preserves_existing_state

test_done
