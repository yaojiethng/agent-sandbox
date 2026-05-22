#!/usr/bin/env bash
# tests/test_providers_pi_preflight.sh
# Unit tests for providers/pi/preflight.sh
#
# Tests:
#   - _ensure_harness_keys injects skills/prompts/packages keys
#   - _ensure_harness_keys preserves existing user keys
#   - Warn when settings.json is missing
#   - Warn when AGENTS.md is missing (Pi-specific path)
#
# Run:   bash tests/test_providers_pi_preflight.sh
# Exit:  0 = all passed, non-zero = failure count

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="${SCRIPT_DIR}/../providers/pi/preflight.sh"

source "$SCRIPT_DIR/libs/test_common.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# _source_preflight sources the preflight script in a subshell with
# the given env vars. Captures stdout+stderr and exit code.
_source_preflight() {
  local ah="$1"
  (
    export AGENT_HOME="$ah"
    export PROVIDER_NAME="pi"
    source "$PREFLIGHT" 2>&1 || true
  )
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_merge_adds_harness_keys() {
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent"

  # Start with minimal Pi settings (no skills/prompts)
  echo '{"defaultModel":"deepseek-v4-flash"}' > "$ah/agent/settings.json"

  _source_preflight "$ah"

  local settings="$ah/agent/settings.json"
  if grep -q '"skills"' "$settings" && grep -q '"prompts"' "$settings" && grep -q '"packages"' "$settings"; then
    pass "merge adds skills, prompts, packages keys"
  else
    fail "merge missing one or more harness keys"
  fi

  if grep -q '/opt/workflow/agent/skills' "$settings"; then
    pass "skills path references /opt/workflow/agent/"
  else
    fail "skills path incorrect"
  fi

  rm -rf "$tmpdir"
}

test_merge_preserves_existing_keys() {
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent"

  # Settings with existing skills key (user-provided path)
  echo '{"defaultModel":"test","skills":["/custom/path"]}' > "$ah/agent/settings.json"

  _source_preflight "$ah"

  local settings="$ah/agent/settings.json"
  if grep -q '"defaultModel": "test"' "$settings"; then
    pass "merge preserves user model setting"
  else
    fail "merge lost user model setting"
  fi
  if grep -q '/custom/path' "$settings"; then
    pass "merge preserves user skills path"
  else
    fail "merge lost user skills path"
  fi

  rm -rf "$tmpdir"
}

test_merge_deduplicates_paths() {
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent"

  # Settings that already has /opt/workflow/agent/skills
  echo '{"skills":["/opt/workflow/agent/skills"]}' > "$ah/agent/settings.json"

  _source_preflight "$ah"

  local settings="$ah/agent/settings.json"
  local count
  count=$(grep -c '/opt/workflow/agent/skills' "$settings" || true)
  if [[ "$count" -eq 1 ]]; then
    pass "merge deduplicates existing paths"
  else
    fail "merge duplicated path (count=$count)"
  fi

  rm -rf "$tmpdir"
}

test_warn_on_missing_settings() {
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent"
  # Deliberately NOT creating settings.json

  local output
  output=$(_source_preflight "$ah")

  if echo "$output" | grep -q "settings.json not found"; then
    pass "warns when settings.json is missing"
  else
    fail "no warning for missing settings.json"
  fi

  rm -rf "$tmpdir"
}

test_warn_on_missing_agents_md() {
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent"
  # Deliberately NOT creating AGENTS.md
  # Need settings.json so _ensure_harness_keys doesn't fail first
  echo '{}' > "$ah/agent/settings.json"

  local output
  output=$(_source_preflight "$ah")

  if echo "$output" | grep -q "AGENTS.md is missing"; then
    pass "warns when AGENTS.md is missing at Pi path"
  else
    fail "no warning for missing AGENTS.md"
  fi

  rm -rf "$tmpdir"
}

test_merge_does_not_fail_on_missing_agents_md() {
  # Even without AGENTS.md, the merge should still succeed
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent"
  echo '{"defaultModel":"test"}' > "$ah/agent/settings.json"

  _source_preflight "$ah"

  local settings="$ah/agent/settings.json"
  if grep -q '"skills"' "$settings"; then
    pass "merge succeeds even when AGENTS.md is missing"
  else
    fail "merge failed when AGENTS.md was missing"
  fi

  rm -rf "$tmpdir"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo "Pi provider pre-flight tests"
echo "============================"

run_test test_merge_adds_harness_keys
run_test test_merge_preserves_existing_keys
run_test test_merge_deduplicates_paths
run_test test_warn_on_missing_settings
run_test test_warn_on_missing_agents_md
run_test test_merge_does_not_fail_on_missing_agents_md

test_done
