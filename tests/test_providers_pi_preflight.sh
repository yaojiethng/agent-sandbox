#!/usr/bin/env bash
# tests/test_providers_pi_preflight.sh
# Unit tests for src/reasoning/providers/pi/preflight.sh
#
# Tests:
#   - _ensure_harness_keys injects skills/prompts/packages keys
#   - _ensure_harness_keys preserves existing user keys
#   - Warn when settings.json is missing
#   - Warn when AGENTS.md is missing (Pi-specific path)
#   - _preflight_check_bind_mounts validates prompts/, sessions/, skills/
#
# Run:   bash tests/test_providers_pi_preflight.sh
# Exit:  0 = all passed, non-zero = failure count

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="${SCRIPT_DIR}/../src/reasoning/providers/pi/preflight.sh"

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
# Tests: harness key merge
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
# Tests: bind mount checks
# ---------------------------------------------------------------------------

test_bind_mounts_ok_when_all_present() {
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent/prompts" "$ah/agent/sessions" "$ah/agent/skills"

  local output
  output=$(_source_preflight "$ah")

  if echo "$output" | grep -qv "missing"; then
    pass "no warnings when all bind mounts present"
  else
    fail "unexpected warning for present bind mounts"
  fi

  rm -rf "$tmpdir"
}

test_bind_mount_warns_on_missing_prompts() {
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent/sessions" "$ah/agent/skills"
  # No prompts/

  local output
  output=$(_source_preflight "$ah")

  if echo "$output" | grep -q "prompts.*missing"; then
    pass "warns when prompts/ is missing"
  else
    fail "no warning for missing prompts/"
  fi

  rm -rf "$tmpdir"
}

test_bind_mount_warns_on_missing_sessions() {
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent/prompts" "$ah/agent/skills"
  # No sessions/

  local output
  output=$(_source_preflight "$ah")

  if echo "$output" | grep -q "sessions.*missing"; then
    pass "warns when sessions/ is missing"
  else
    fail "no warning for missing sessions/"
  fi

  rm -rf "$tmpdir"
}

test_bind_mount_warns_on_not_writable() {
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  mkdir -p "$ah/agent/prompts" "$ah/agent/sessions" "$ah/agent/skills"
  chmod 000 "$ah/agent/skills"

  local output
  output=$(_source_preflight "$ah")

  if echo "$output" | grep -q "skills.*not writable"; then
    pass "warns when skills/ is not writable"
  else
    fail "no warning for non-writable skills/"
  fi

  chmod 755 "$ah/agent/skills" 2>/dev/null || true
  rm -rf "$tmpdir"
}

test_bind_mount_messages_on_all_missing() {
  local tmpdir; tmpdir=$(mktemp -d)
  local ah="$tmpdir/ah"
  # No bind-mounted dirs at all

  local output
  output=$(_source_preflight "$ah")

  local prompt_count
  prompt_count=$(echo "$output" | grep -c "prompts.*missing\|sessions.*missing\|skills.*missing" || true)
  if [[ "$prompt_count" -ge 3 ]]; then
    pass "reports all three missing bind mounts"
  else
    fail "expected 3 missing messages, got $prompt_count"
  fi

  if echo "$output" | grep -q "bind-mounted directories"; then
    pass "includes summary message about bind mounts"
  else
    fail "no summary message about bind mounts"
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
run_test test_bind_mounts_ok_when_all_present
run_test test_bind_mount_warns_on_missing_prompts
run_test test_bind_mount_warns_on_missing_sessions
run_test test_bind_mount_warns_on_not_writable
run_test test_bind_mount_messages_on_all_missing

test_done
