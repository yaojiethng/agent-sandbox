#!/usr/bin/env bash
# tests/test_capability_entrypoint_mount.sh
# Behavioral tests for the mount-delivery branch of src/capability/entrypoint.sh.
#
# Covers:
#   mount fail-closed      --  worktree without .git aborts (rc=1, remediation text)
#   first mount run        --  writes SESSION_STATE init marker (init_sha, session_ts,
#                              session_id, host_head_sha) + workspace path fields
#   attach re-run          --  pre-existing SESSION_STATE identity fields not overwritten
#   flatten first run      --  FLATTEN=true records the root commit as init_sha
#   export skip            --  a clean first run writes no session export
#   empty HEAD abort       --  a worktree with no commits fails closed
#   start-up command       --  a supplied command runs before the container stays up
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

# EP_FLATTEN overrides the entrypoint's FLATTEN env for one invocation.
# EP_ARGS carries the optional start-up command argv.
# EP_CHANGES_DIR overrides the session-diffs path for the preflight-failure unit.
EP_FLATTEN=""
EP_ARGS=()
EP_CHANGES_DIR=""

# invoke_entrypoint_mount DIR
#   Runs DIR/entrypoint.sh (a sed-patched copy -- ROOT rewritten to DIR) in
#   the background with mount env, waits for preflight to pass, SIGTERMs it
#   (docker stop's signal), and collects the exit code. Globals set: EP_RC,
#   EP_OUT.
invoke_entrypoint_mount() {
  local dir="$1"
  ( cd "$dir" && HOME="${EP_HOME:-$HOME}" \
    AGENT_HOME='' \
    SANDBOX_LIB_DIR="$STUB_LIB_DIR" \
    SANDBOX_TYPE=mount \
    SANDBOX_DIR_NAME=worktree \
    FLATTEN="${EP_FLATTEN:-false}" \
    CHANGES_DIR="${EP_CHANGES_DIR:-$dir/.workspace/session-diffs}" \
    INPUT_DIR="$dir/.workspace/input" \
    OUTPUT_DIR="$dir/.workspace/output" \
    SESSION_TS="20260912-120000" SESSION_ID="mnt000" \
    HOST_HEAD_SHA="cafebabe" HOST_UID="$(id -u)" HOST_GID="$(id -g)" \
    AUTOSAVE_INTERVAL=0 \
    exec bash "$dir/entrypoint.sh" ${EP_ARGS[@]+"${EP_ARGS[@]}"} ) >"$dir/log" 2>&1 &
  local pid=$!
  for _ in $(seq 1 100); do
    grep -q "ALL CHECKS PASSED" "$dir/log" 2>/dev/null && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  sleep 0.2
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

  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"
  invoke_entrypoint_mount "$dir"
}

# Given: a mount-delivery entrypoint copy and a worktree directory carrying no .git
# When:  the entrypoint runs
# Then:  it exits non-zero and the message names the missing .git
# Asserts: a failed host materialization fails closed
test_mount_fail_closed_no_git() {
  local dir="$FIXTURE_DIR/mount_nogit"
  mkdir -p "$dir/worktree" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  # Worktree without .git -- host materialization did not run.
  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"
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
  assert_contains "$EP_OUT" "no .git" "mount without .git: remediation message names the missing .git"
}

# Given: a mount-delivery worktree that is a git repo with no SESSION_STATE
# When:  the entrypoint runs to its readiness marker and then receives SIGTERM
# Then:  rc is 0 and SESSION_STATE carries init_sha (a real commit), the identity fields, and the workspace path fields
# Asserts: the first mount run writes the init marker and the path fields
# Note:  FLATTEN is unset here, so this unit covers the non-flatten init_sha branch; the
#        flatten branch is covered by test_mount_flatten_first_run_uses_root_commit.
#        The preflight's SESSION_STATE checks read the container's hardcoded path, not this fixture
test_mount_first_run_writes_init_marker() {
  local dir="$FIXTURE_DIR/mount_first"
  run_entrypoint "$dir"
  if [[ "$EP_RC" -ne 0 ]]; then
    fail "first mount run: entrypoint rc=$EP_RC: $EP_OUT"; return
  fi
  pass "first mount run: entrypoint completes and exports (rc=0)"

  assert_file_exists "$EP_STATE" "first mount run: SESSION_STATE written into worktree .git"

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

# Given: a worktree whose SESSION_STATE carries an earlier session's identity
# When:  the entrypoint runs and receives SIGTERM
# Then:  the existing session_id and session_ts survive and the workspace path fields are refreshed
# Asserts: an attach preserves identity while it re-writes the paths
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

  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"
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

# Given: an unset AGENT_HOME and a HOME whose .pi holds AGENTS.md
# When:  the entrypoint preflight runs
# Then:  the AGENT_HOME check resolves through HOME and passes
# Asserts: the tilde default is resolved, not tested as a literal path.
test_agents_md_default_expands_home() {
  local dir="$FIXTURE_DIR/mount_agenthome"
  local home="$dir/home"
  mkdir -p "$home/.pi"
  : > "$home/.pi/AGENTS.md"

  EP_HOME="$home" run_entrypoint "$dir"
  assert_contains "$EP_OUT" "PREFLIGHT PASS: AGENTS.md present at AGENT_HOME" \
    "AGENT_HOME default expands HOME before testing AGENTS.md"
}

# Given: a mount-delivery worktree with two commits and FLATTEN=true
# When:  the entrypoint writes the first-run init marker
# Then:  init_sha is the root commit, not HEAD
# Asserts: the FLATTEN branch chooses the flattened baseline as the session's diff baseline
test_mount_flatten_first_run_uses_root_commit() {
  local dir="$FIXTURE_DIR/mount_flatten"
  local worktree="$dir/worktree"
  mkdir -p "$worktree" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  git -C "$worktree" init -q
  git -C "$worktree" config user.email "t@t" && git -C "$worktree" config user.name "t"
  echo one > "$worktree/file.txt"
  git -C "$worktree" add -A && git -C "$worktree" commit -q -m first
  echo two >> "$worktree/file.txt"
  git -C "$worktree" add -A && git -C "$worktree" commit -q -m second
  EP_STATE="$worktree/.git/SESSION_STATE"
  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"
  EP_FLATTEN=true
  invoke_entrypoint_mount "$dir"

  if [[ "$EP_RC" -ne 0 ]]; then
    fail "flatten first run: entrypoint rc=$EP_RC: $EP_OUT"; return
  fi
  local init_sha root head
  init_sha=$(grep '^init_sha=' "$EP_STATE" | cut -d= -f2-)
  root=$(git -C "$worktree" rev-list --max-parents=0 HEAD)
  head=$(git -C "$worktree" rev-parse HEAD)
  assert_eq "$init_sha" "$root" "flatten first run: init_sha is the root commit"
  assert_ne "$init_sha" "$head" "flatten first run: init_sha is not HEAD with two commits"
}

# Given: a clean first mount run (baseline equals HEAD, no changes)
# When:  the entrypoint exits
# Then:  the export-needed decision skips and writes no session export dir
# Asserts: the exit-time export skip
test_mount_export_skipped_without_work() {
  local dir="$FIXTURE_DIR/mount_skip_export"
  run_entrypoint "$dir"
  if [[ "$EP_RC" -ne 0 ]]; then
    fail "export skip: entrypoint rc=$EP_RC: $EP_OUT"; return
  fi
  assert_run 1 "test -d '$dir/.workspace/session-diffs/session'" \
    "a clean first run writes no session export dir"
}

# Given: a mount worktree that is a git repo with no commits
# When:  the entrypoint writes the first-run init marker
# Then:  it exits non-zero and names the unresolvable HEAD
# Asserts: the empty-init_sha abort
test_mount_aborts_without_resolvable_head() {
  local dir="$FIXTURE_DIR/mount_unborn"
  local worktree="$dir/worktree"
  mkdir -p "$worktree" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  mkdir -p "$worktree/.git"
  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"
  invoke_entrypoint_mount "$dir"
  assert_ne "$EP_RC" "0" "mount entrypoint fails on an unresolvable HEAD"
  assert_contains "$EP_OUT" "no resolvable HEAD" "mount entrypoint names the unresolvable HEAD"
}

# Given: a CHANGES_DIR that resolves to a read-only directory
# When:  the entrypoint preflight runs
# Then:  it reports the failing check and exits non-zero at the verdict gate
# Asserts: the PREFLIGHT_FAILS greater-than-zero exit
test_mount_preflight_failure_exits_nonzero() {
  local dir="$FIXTURE_DIR/mount_preflight_fail"
  local worktree="$dir/worktree"
  local diffs="$dir/readonly-diffs"
  mkdir -p "$worktree" "$diffs" "$dir/.workspace/input" "$dir/.workspace/output"
  git -C "$worktree" init -q
  git -C "$worktree" config user.email "t@t" && git -C "$worktree" config user.name "t"
  echo x > "$worktree/f" && git -C "$worktree" add -A && git -C "$worktree" commit -q -m baseline
  chmod 555 "$diffs"
  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"
  EP_CHANGES_DIR="$diffs"
  invoke_entrypoint_mount "$dir"
  chmod 755 "$diffs"
  assert_ne "$EP_RC" "0" "preflight failure exits non-zero"
  assert_contains "$EP_OUT" "FAILURE(S)" "preflight gate reports the failure count"
}

# Given: a mount-delivery worktree and a start-up command that writes a marker
# When:  the entrypoint runs with the command as its argument
# Then:  it logs the command and runs it before staying alive
# Asserts: the compose command: override prelude block
test_mount_runs_startup_command() {
  local dir="$FIXTURE_DIR/mount_startup"
  local marker="$dir/probe-ran"
  mkdir -p "$dir"
  cat > "$dir/probe.sh" <<EOF
#!/usr/bin/env bash
echo probe > "$marker"
EOF
  chmod +x "$dir/probe.sh"
  EP_ARGS=("$dir/probe.sh")
  run_entrypoint "$dir"
  if [[ "$EP_RC" -ne 0 ]]; then
    fail "start-up command: entrypoint rc=$EP_RC: $EP_OUT"; return
  fi
  assert_contains "$EP_OUT" "running start-up command" "entrypoint logs the start-up command"
  assert_file_exists "$marker" "entrypoint ran the start-up command"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_mount_fail_closed_no_git
run_test test_mount_first_run_writes_init_marker
run_test test_mount_attach_preserves_existing_state
run_test test_agents_md_default_expands_home
run_test test_mount_flatten_first_run_uses_root_commit
run_test test_mount_export_skipped_without_work
run_test test_mount_aborts_without_resolvable_head
run_test test_mount_runs_startup_command
run_test test_mount_preflight_failure_exits_nonzero

test_done


