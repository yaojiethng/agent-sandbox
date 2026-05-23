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
  mkdir -p "$agent_home"
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

# -- _provision_agent_home --
#
# Note: these tests inline the function definition rather than sourcing
# the entrypoint, because sourcing runs the full top-level code including
# an `exit` at the end, which would kill the subshell.

_provision_agent_home() {
  local template="${1:?provision_agent_home requires template_dir}"
  local target="${2:?provision_agent_home requires target_dir}"

  if [[ ! -d "$template" ]]; then
    echo "FATAL: Config template $template not found" >&2
    return 1
  fi

  mkdir -p "$target"
  cp -RT --no-preserve=all "$template/" "$target/"
}

test_provision_copies_config_files() {
  local tmpdir; tmpdir=$(mktemp -d)
  local tpl="$tmpdir/tpl"
  mkdir -p "$tpl"
  echo '{"model":"test"}' > "$tpl/settings.json"
  echo 'auth-value' > "$tpl/auth.json"

  local ah="$tmpdir/ah"
  _provision_agent_home "$tpl" "$ah"

  if [[ -f "$ah/settings.json" ]] && grep -q '"model":"test"' "$ah/settings.json"; then
    pass "copies settings.json"
  else
    fail "settings.json missing or wrong content"
  fi
  if [[ -f "$ah/auth.json" ]]; then
    pass "copies auth.json"
  else
    fail "auth.json missing"
  fi

  rm -rf "$tmpdir"
}

test_provision_copies_all_items() {
  local tmpdir; tmpdir=$(mktemp -d)
  local tpl="$tmpdir/tpl"
  mkdir -p "$tpl/prompts" "$tpl/sessions" "$tpl/skills"
  echo 'prompt-content' > "$tpl/prompts/test.md"
  echo 'session-data' > "$tpl/sessions/session.json"
  echo 'skill-content' > "$tpl/skills/test.md"
  echo 'config-data' > "$tpl/settings.json"

  local ah="$tmpdir/ah"
  _provision_agent_home "$tpl" "$ah"

  if [[ -f "$ah/settings.json" ]]; then
    pass "copies top-level files"
  else
    fail "settings.json not copied"
  fi
  if [[ -d "$ah/prompts" && -f "$ah/prompts/test.md" ]]; then
    pass "copies prompts/ subtree"
  else
    fail "prompts/ subtree not copied"
  fi
  if [[ -d "$ah/sessions" && -f "$ah/sessions/session.json" ]]; then
    pass "copies sessions/ subtree"
  else
    fail "sessions/ subtree not copied"
  fi
  if [[ -d "$ah/skills" && -f "$ah/skills/test.md" ]]; then
    pass "copies skills/ subtree"
  else
    fail "skills/ subtree not copied"
  fi

  rm -rf "$tmpdir"
}

test_provision_fails_on_missing_template() {
  local tmpdir; tmpdir=$(mktemp -d)
  local tpl="$tmpdir/nonexistent"
  local ah="$tmpdir/ah"
  local rc=0

  _provision_agent_home "$tpl" "$ah" 2>/dev/null || rc=$?

  if [[ $rc -ne 0 ]]; then
    pass "returns non-zero when template is missing"
  else
    fail "should return non-zero for missing template"
  fi

  rm -rf "$tmpdir"
}

test_provision_no_double_nesting() {
  # Simulate Pi's scenario: template has agent/ dir, target already has
  # agent/ subdir (created by Docker for bind mount targets). The copy
  # must not produce agent/agent/ double-nesting.
  local tmpdir; tmpdir=$(mktemp -d)

  # Template mirrors providers/pi/config/ structure
  local tpl="$tmpdir/tpl"
  mkdir -p "$tpl/agent"
  echo '{"key":"template"}' > "$tpl/agent/settings.json"

  # Target already has agent/ (pre-created, simulating Docker's bind mount
  # parent dir creation and the Dockerfile mkdir)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent"

  _provision_agent_home "$tpl" "$ah"

  if [[ -f "$ah/agent/settings.json" ]]; then
    pass "no double nesting: settings.json at target/agent/"
  else
    fail "settings.json not found (or double-nested at target/agent/agent/)"
  fi
  if [[ ! -d "$ah/agent/agent" ]]; then
    pass "no agent/agent/ subdirectory"
  else
    fail "agent/agent/ double nesting detected"
  fi

  rm -rf "$tmpdir"
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
run_test test_provision_copies_config_files
run_test test_provision_copies_all_items
run_test test_provision_fails_on_missing_template
run_test test_provision_no_double_nesting

test_done
