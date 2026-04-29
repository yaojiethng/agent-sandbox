#!/usr/bin/env bash
# tests/test_provider_entrypoint.sh
# Regression tests for libs/provider-entrypoint.sh
#
# Run:   bash tests/test_provider_entrypoint.sh
# Exit:  0 = all passed, non-zero = failure count
#
# Design note — stdin test:
# The critical regression guard is that the agent's stdin is NOT /dev/null.
# Under any background-job approach (with or without job control), non-interactive
# bash redirects stdin to /dev/null for background children. The synchronous
# approach inherits stdin from the shell. The test verifies this by having the
# agent report its own stdin device path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTRYPOINT="${SCRIPT_DIR}/../libs/provider-entrypoint.sh"

source "$SCRIPT_DIR/libs/test_common.sh"

_run() {
  local agent_home="$1" provider_config="$2"; shift 2
  AGENT_HOME="$agent_home" \
  PROVIDER_NAME="test-provider" \
  PROVIDER_CONFIG_DIR="$provider_config" \
  bash "$ENTRYPOINT" "$@"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# -- Env var validation --

test_missing_agent_home() {
  local out
  out=$(unset AGENT_HOME; PROVIDER_NAME=test PROVIDER_CONFIG_DIR=/tmp bash "$ENTRYPOINT" true 2>&1) && {
    fail "missing AGENT_HOME env var"
    return
  }
  if [[ "$out" == *"AGENT_HOME is not set"* ]]; then
    pass "missing AGENT_HOME env var"
  else
    fail "missing AGENT_HOME env var"
  fi
}

test_missing_provider_name() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local out rc=0
  out=$(unset PROVIDER_NAME; AGENT_HOME="$tmpdir/ah" PROVIDER_CONFIG_DIR=/tmp bash "$ENTRYPOINT" true 2>&1) || rc=$?
  rm -rf "$tmpdir"
  if [[ $rc -ne 0 && "$out" == *"PROVIDER_NAME is not set"* ]]; then
    pass "missing PROVIDER_NAME env var"
  else
    fail "missing PROVIDER_NAME env var"
  fi
}

test_missing_provider_config_dir() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local out rc=0
  out=$(unset PROVIDER_CONFIG_DIR; AGENT_HOME="$tmpdir/ah" PROVIDER_NAME=test bash "$ENTRYPOINT" true 2>&1) || rc=$?
  rm -rf "$tmpdir"
  if [[ $rc -ne 0 && "$out" == *"PROVIDER_CONFIG_DIR is not set"* ]]; then
    pass "missing PROVIDER_CONFIG_DIR env var"
  else
    fail "missing PROVIDER_CONFIG_DIR env var"
  fi
}

# -- Copy-in --

test_copy_in_on_start() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local pc="$tmpdir/pc" ah="$tmpdir/ah"
  mkdir -p "$pc"
  echo "test-value" > "$pc/config.yaml"

  local rc=0
  _run "$ah" "$pc" \
    bash -c "test -f \"$ah/config.yaml\" && grep -q test-value \"$ah/config.yaml\"" \
    || rc=$?
  rm -rf "$tmpdir"
  if [[ $rc -eq 0 ]]; then
    pass "copy-in runs at session start"
  else
    fail "copy-in runs at session start"
  fi
}

test_copy_in_skipped_when_empty() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local pc="$tmpdir/pc" ah="$tmpdir/ah"
  mkdir -p "$pc"

  _run "$ah" "$pc" true
  local created=0; [[ -d "$ah" ]] && created=1
  rm -rf "$tmpdir"
  if [[ $created -eq 0 ]]; then
    pass "copy-in skipped when provider config empty"
  else
    fail "copy-in skipped when provider config empty"
  fi
}

test_copy_in_skipped_when_absent() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local rc=0
  _run "$tmpdir/ah" "$tmpdir/does_not_exist" true || rc=$?
  rm -rf "$tmpdir"
  if [[ $rc -eq 0 ]]; then
    pass "copy-in skipped when provider config absent"
  else
    fail "copy-in skipped when provider config absent"
  fi
}

# -- Copy-out --

test_copy_out_on_normal_exit() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local pc="$tmpdir/pc" ah="$tmpdir/ah"
  mkdir -p "$pc" "$ah"

  _run "$ah" "$pc" bash -c "echo session-output > \"$ah/session.log\""

  local rc=0
  { [[ -f "$pc/session.log" ]] && grep -q session-output "$pc/session.log"; } || rc=1
  rm -rf "$tmpdir"
  if [[ $rc -eq 0 ]]; then
    pass "copy-out runs on normal agent exit"
  else
    fail "copy-out runs on normal agent exit"
  fi
}

test_copy_out_on_nonzero_exit() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local pc="$tmpdir/pc" ah="$tmpdir/ah"
  mkdir -p "$pc" "$ah"

  _run "$ah" "$pc" bash -c "echo partial > \"$ah/partial.log\"; exit 1" || true

  local rc=0
  [[ -f "$pc/partial.log" ]] || rc=1
  rm -rf "$tmpdir"
  if [[ $rc -eq 0 ]]; then
    pass "copy-out runs on non-zero agent exit"
  else
    fail "copy-out runs on non-zero agent exit"
  fi
}

# -- Exit code --

test_exit_code_zero() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local rc=0
  _run "$tmpdir/ah" "$tmpdir/pc" bash -c "exit 0" || rc=$?
  rm -rf "$tmpdir"
  if [[ $rc -eq 0 ]]; then
    pass "exit code 0 preserved"
  else
    fail "exit code 0 preserved"
  fi
}

test_exit_code_nonzero() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local rc=0
  _run "$tmpdir/ah" "$tmpdir/pc" bash -c "exit 42" || rc=$?
  rm -rf "$tmpdir"
  if [[ $rc -eq 42 ]]; then
    pass "exit code 42 preserved"
  else
    fail "exit code 42 preserved"
  fi
}

# -- stdin regression guard --

test_stdin_not_devnull() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local stdin_content="$tmpdir/stdin_content"

  echo "test-input-42" | _run "$tmpdir/ah" "$tmpdir/pc" \
    bash -c "cat > \"$stdin_content\""

  local rc=0
  [[ -f "$stdin_content" ]] && grep -q "test-input-42" "$stdin_content" || rc=1
  rm -rf "$tmpdir"
  if [[ $rc -eq 0 ]]; then
    pass "agent stdin is not /dev/null"
  else
    fail "agent stdin is not /dev/null"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo "provider-entrypoint regression tests"
echo "====================================="

run_test test_missing_agent_home
run_test test_missing_provider_name
run_test test_missing_provider_config_dir
run_test test_copy_in_on_start
run_test test_copy_in_skipped_when_empty
run_test test_copy_in_skipped_when_absent
run_test test_copy_out_on_normal_exit
run_test test_copy_out_on_nonzero_exit
run_test test_exit_code_zero
run_test test_exit_code_nonzero
run_test test_stdin_not_devnull

test_done
