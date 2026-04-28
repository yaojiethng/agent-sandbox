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

# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

PASS=0
FAIL=0
_FAILURES=()

pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
fail() { FAIL=$((FAIL + 1)); _FAILURES+=("$1"); echo "  FAIL  $1"; }

run_test() {
  local name="$1" fn="$2"
  echo ""
  echo "[ $name ]"
  if "$fn"; then
    pass "$name"
  else
    fail "$name"
  fi
}

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
  out=$(unset AGENT_HOME; PROVIDER_NAME=test PROVIDER_CONFIG_DIR=/tmp bash "$ENTRYPOINT" true 2>&1) && return 1
  [[ "$out" == *"AGENT_HOME is not set"* ]]
}

test_missing_provider_name() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local out rc=0
  out=$(unset PROVIDER_NAME; AGENT_HOME="$tmpdir/ah" PROVIDER_CONFIG_DIR=/tmp bash "$ENTRYPOINT" true 2>&1) || rc=$?
  rm -rf "$tmpdir"
  [[ $rc -ne 0 ]] && [[ "$out" == *"PROVIDER_NAME is not set"* ]]
}

test_missing_provider_config_dir() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local out rc=0
  out=$(unset PROVIDER_CONFIG_DIR; AGENT_HOME="$tmpdir/ah" PROVIDER_NAME=test bash "$ENTRYPOINT" true 2>&1) || rc=$?
  rm -rf "$tmpdir"
  [[ $rc -ne 0 ]] && [[ "$out" == *"PROVIDER_CONFIG_DIR is not set"* ]]
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
  return $rc
}

test_copy_in_skipped_when_empty() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local pc="$tmpdir/pc" ah="$tmpdir/ah"
  mkdir -p "$pc"

  _run "$ah" "$pc" true
  local created=0; [[ -d "$ah" ]] && created=1
  rm -rf "$tmpdir"
  [[ $created -eq 0 ]]
}

test_copy_in_skipped_when_absent() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local rc=0
  _run "$tmpdir/ah" "$tmpdir/does_not_exist" true || rc=$?
  rm -rf "$tmpdir"
  [[ $rc -eq 0 ]]
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
  return $rc
}

test_copy_out_on_nonzero_exit() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local pc="$tmpdir/pc" ah="$tmpdir/ah"
  mkdir -p "$pc" "$ah"

  _run "$ah" "$pc" bash -c "echo partial > \"$ah/partial.log\"; exit 1" || true

  local rc=0
  [[ -f "$pc/partial.log" ]] || rc=1
  rm -rf "$tmpdir"
  return $rc
}

# -- Exit code --

test_exit_code_zero() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local rc=0
  _run "$tmpdir/ah" "$tmpdir/pc" bash -c "exit 0" || rc=$?
  rm -rf "$tmpdir"
  [[ $rc -eq 0 ]]
}

test_exit_code_nonzero() {
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local rc=0
  _run "$tmpdir/ah" "$tmpdir/pc" bash -c "exit 42" || rc=$?
  rm -rf "$tmpdir"
  [[ $rc -eq 42 ]]
}

# -- stdin regression guard --

test_stdin_not_devnull() {
  # Verifies that the agent's stdin is connected to the parent shell's stdin.
  # Under any background-job approach, bash redirects stdin to /dev/null for
  # background children. The synchronous approach inherits stdin from the shell.
  # This test pipes explicit input and verifies the agent receives it.
  local tmpdir; tmpdir=$(mktemp -d /tmp/XXXXXX)
  local stdin_content="$tmpdir/stdin_content"

  echo "test-input-42" | _run "$tmpdir/ah" "$tmpdir/pc" \
    bash -c "cat > \"$stdin_content\""

  local rc=0
  [[ -f "$stdin_content" ]] && grep -q "test-input-42" "$stdin_content" || rc=1
  rm -rf "$tmpdir"
  return $rc
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo "provider-entrypoint regression tests"
echo "====================================="

run_test "missing AGENT_HOME env var"                    test_missing_agent_home
run_test "missing PROVIDER_NAME env var"                 test_missing_provider_name
run_test "missing PROVIDER_CONFIG_DIR env var"           test_missing_provider_config_dir
run_test "copy-in runs at session start"                 test_copy_in_on_start
run_test "copy-in skipped when provider config empty"    test_copy_in_skipped_when_empty
run_test "copy-in skipped when provider config absent"   test_copy_in_skipped_when_absent
run_test "copy-out runs on normal agent exit"            test_copy_out_on_normal_exit
run_test "copy-out runs on non-zero agent exit"          test_copy_out_on_nonzero_exit
run_test "exit code 0 preserved"                         test_exit_code_zero
run_test "exit code 42 preserved"                        test_exit_code_nonzero
run_test "agent stdin is not /dev/null"                  test_stdin_not_devnull

echo ""
echo "====================================="
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"

if (( FAIL > 0 )); then
  echo ""
  echo "Failed:"
  for f in "${_FAILURES[@]}"; do echo "  - $f"; done
  exit 1
fi
