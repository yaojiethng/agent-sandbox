#!/usr/bin/env bash
# tests/test_provider_entrypoint.sh
# Regression tests for libs/provider-entrypoint.sh
#
# Tests generic shared entrypoint behaviour:
#   - env var validation (AGENT_HOME, PROVIDER_NAME)
#   - exit code forwarding
#   - stdin preservation
#
# The Pi-specific harness key merge (_ensure_harness_keys) was moved to
# providers/pi/preflight.sh. Those tests now live in:
#   tests/test_providers_pi_preflight.sh
#
# Run:   bash tests/test_provider_entrypoint.sh
# Exit:  0 = all passed, non-zero = failure count

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTRYPOINT="${SCRIPT_DIR}/../libs/provider-entrypoint.sh"

source "$SCRIPT_DIR/libs/test_common.sh"

_run() {
  local agent_home="$1"; shift
  AGENT_HOME="$agent_home" \
  PROVIDER_NAME="test-provider" \
  bash "$ENTRYPOINT" "$@"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_missing_agent_home() {
  local out
  out=$(unset AGENT_HOME; PROVIDER_NAME=test bash "$ENTRYPOINT" true 2>&1) && {
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
  local tmpdir; tmpdir=$(mktemp -d)
  local out rc=0
  out=$(unset PROVIDER_NAME; AGENT_HOME="$tmpdir/ah" bash "$ENTRYPOINT" true 2>&1) || rc=$?
  rm -rf "$tmpdir"
  if [[ $rc -ne 0 && "$out" == *"PROVIDER_NAME is not set"* ]]; then
    pass "missing PROVIDER_NAME env var"
  else
    fail "missing PROVIDER_NAME env var"
  fi
}

# -- Exit code --

test_exit_code_zero() {
  local tmpdir; tmpdir=$(mktemp -d)
  local rc=0
  _run "$tmpdir/ah" bash -c "exit 0" || rc=$?
  rm -rf "$tmpdir"
  if [[ $rc -eq 0 ]]; then
    pass "exit code 0 preserved"
  else
    fail "exit code 0 preserved"
  fi
}

test_exit_code_nonzero() {
  local tmpdir; tmpdir=$(mktemp -d)
  local rc=0
  _run "$tmpdir/ah" bash -c "exit 42" || rc=$?
  rm -rf "$tmpdir"
  if [[ $rc -eq 42 ]]; then
    pass "exit code 42 preserved"
  else
    fail "exit code 42 preserved"
  fi
}

# -- stdin regression guard --

test_stdin_not_devnull() {
  local tmpdir; tmpdir=$(mktemp -d)
  local stdin_content="$tmpdir/stdin_content"

  echo "test-input-42" | _run "$tmpdir/ah" \
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
run_test test_exit_code_zero
run_test test_exit_code_nonzero
run_test test_stdin_not_devnull

test_done
