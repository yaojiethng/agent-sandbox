#!/usr/bin/env bash
# scripts/onboard.sh end-to-end behavioural tests.
#
# Tests the directory tree and files produced by a fresh onboard,
# the guard check that prevents clobbering, and refresh mode behaviour.
#
# These are behavioural tests — they assert the contract (what files exist,
# what .env contains) not the internal implementation. They should pass
# regardless of how onboard.sh is structured internally.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/libs/test_common.sh"

ONBOARD_SCRIPT="$REPO_ROOT/scripts/onboard.sh"
FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# UID Mapping handles permissions — no ACL prerequisite needed.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

make_project_dir() {
  local DIR="$1"
  mkdir -p "$DIR"
  touch "$DIR/.gitkeep"
}

# Run a full fresh onboard and return the exit code + output.
# Run a full fresh onboard and return the exit code + output.
run_full_onboard() {
  local PROJECT_DIR="$1"
  local SANDBOX_DIR="$2"
  make_project_dir "$PROJECT_DIR"

  bash "$ONBOARD_SCRIPT" \
    --name="testproj" \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1
  local EXIT_CODE=$?
  if [[ "$EXIT_CODE" -ne 0 ]]; then
    fail "onboard.sh exited with code $EXIT_CODE"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Test: fresh onboard creates the expected directory structure
# ---------------------------------------------------------------------------
test_fresh_onboard_creates_structure() {
  local PROJECT_DIR="$FIXTURE_DIR/fresh_project"
  local SANDBOX_DIR="$FIXTURE_DIR/fresh_sandbox"

  run_full_onboard "$PROJECT_DIR" "$SANDBOX_DIR" || return 0

  [[ -f "$SANDBOX_DIR/Makefile" ]] || { fail "Makefile not created"; return; }
  [[ -f "$SANDBOX_DIR/AGENTS.md" ]] || { fail "AGENTS.md not created"; return; }
  [[ -f "$SANDBOX_DIR/.env" ]] || { fail ".env not created"; return; }
  [[ -d "$SANDBOX_DIR/.workspace/input" ]] || { fail ".workspace/input/ not created"; return; }
  [[ -d "$SANDBOX_DIR/.workspace/output" ]] || { fail ".workspace/output/ not created"; return; }
  [[ -d "$SANDBOX_DIR/.workspace/session-diffs" ]] || { fail ".workspace/session-diffs/ not created"; return; }

  pass "Fresh onboard creates all expected files and directories"
}

# ---------------------------------------------------------------------------
# Test: .env contains required keys
# ---------------------------------------------------------------------------
test_fresh_onboard_env_has_required_keys() {
  local PROJECT_DIR="$FIXTURE_DIR/env_project"
  local SANDBOX_DIR="$FIXTURE_DIR/env_sandbox"

  run_full_onboard "$PROJECT_DIR" "$SANDBOX_DIR" || return 0

  local ENV_FILE="$SANDBOX_DIR/.env"

  grep -q "^PROJECT_DIR=" "$ENV_FILE" || { fail ".env missing PROJECT_DIR"; return; }
  grep -q "^SANDBOX_DIR=" "$ENV_FILE" || { fail ".env missing SANDBOX_DIR"; return; }
  grep -q "^MAKEFILE_VERSION=" "$ENV_FILE" || { fail ".env missing MAKEFILE_VERSION"; return; }
  grep -q "^INSTALL_DIR=" "$ENV_FILE" || { fail ".env missing INSTALL_DIR"; return; }
  grep -q "^SERVE_PORT=" "$ENV_FILE" || { fail ".env missing SERVE_PORT"; return; }
  grep -q "^AUTOSAVE_INTERVAL=" "$ENV_FILE" || { fail ".env missing AUTOSAVE_INTERVAL"; return; }

  pass ".env contains all required keys"
}

# ---------------------------------------------------------------------------
# Test: provider config directories are created
# ---------------------------------------------------------------------------
test_fresh_onboard_creates_provider_configs() {
  local PROJECT_DIR="$FIXTURE_DIR/provider_project"
  local SANDBOX_DIR="$FIXTURE_DIR/provider_sandbox"

  run_full_onboard "$PROJECT_DIR" "$SANDBOX_DIR" || return 0

  local PROVIDERS_FOUND=0
  for PROVIDER_CONFIG_DIR in "$REPO_ROOT/src/reasoning/providers/"*/config; do
    [[ -d "$PROVIDER_CONFIG_DIR" ]] || continue
    [[ -n "$(ls -A "$PROVIDER_CONFIG_DIR" 2>/dev/null)" ]] || continue
    local PROVIDER_NAME
    PROVIDER_NAME="$(basename "$(dirname "$PROVIDER_CONFIG_DIR")")"
    if [[ -d "$SANDBOX_DIR/.$PROVIDER_NAME" ]]; then
      PROVIDERS_FOUND=$((PROVIDERS_FOUND + 1))
    else
      fail "Provider config dir not created: .$PROVIDER_NAME"
      return
    fi
  done

  if [[ "$PROVIDERS_FOUND" -gt 0 ]]; then
    pass "Provider config directories created ($PROVIDERS_FOUND providers)"
  else
    skip "No provider config directories in repo — skipping provider assertion"
  fi
}

# ---------------------------------------------------------------------------
# Test: AGENTS.md contains project name
# ---------------------------------------------------------------------------
test_fresh_onboard_agents_md_contains_project_name() {
  local PROJECT_DIR="$FIXTURE_DIR/agents_project"
  local SANDBOX_DIR="$FIXTURE_DIR/agents_sandbox"

  run_full_onboard "$PROJECT_DIR" "$SANDBOX_DIR" || return 0

  grep -q "testproj" "$SANDBOX_DIR/AGENTS.md" \
    || { fail "AGENTS.md does not contain project name"; return; }

  pass "AGENTS.md contains project name"
}

# ---------------------------------------------------------------------------
# Test: fresh onboard aborts if SANDBOX_DIR already has outputs
# ---------------------------------------------------------------------------
test_onboard_aborts_if_sandbox_exists() {
  local PROJECT_DIR="$FIXTURE_DIR/guard_project"
  local SANDBOX_DIR="$FIXTURE_DIR/guard_sandbox"
  make_project_dir "$PROJECT_DIR"
  mkdir -p "$SANDBOX_DIR"
  touch "$SANDBOX_DIR/Makefile"

  set +e
  OUTPUT=$(bash "$ONBOARD_SCRIPT" \
    --name="testproj" \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" 2>&1)
  local EXIT_CODE=$?
  set -e

  if [[ "$EXIT_CODE" -eq 0 ]]; then
    fail "Onboard should have aborted (exit 0) but expected non-zero"
    return
  fi

  echo "$OUTPUT" | grep -q "already contains" \
    || { fail "Abort message not found"; return; }

  pass "Onboard aborts when SANDBOX_DIR already has outputs"
}

# ---------------------------------------------------------------------------
# Test: refresh mode updates Makefile
# ---------------------------------------------------------------------------
test_refresh_updates_makefile() {
  local PROJECT_DIR="$FIXTURE_DIR/refresh_project"
  local SANDBOX_DIR="$FIXTURE_DIR/refresh_sandbox"

  run_full_onboard "$PROJECT_DIR" "$SANDBOX_DIR" || return 0

  rm "$SANDBOX_DIR/Makefile"

  bash "$ONBOARD_SCRIPT" --refresh \
    --name="testproj" \
    --sandbox="$SANDBOX_DIR" 2>&1

  [[ -f "$SANDBOX_DIR/Makefile" ]] || { fail "Makefile not recreated by refresh"; return; }
  [[ -f "$SANDBOX_DIR/AGENTS.md" ]] || { fail "AGENTS.md was removed by refresh"; return; }

  pass "Refresh recreates Makefile without clobbering AGENTS.md"
}

# ---------------------------------------------------------------------------
# Test: refresh does not clobber .env operator values
# ---------------------------------------------------------------------------
test_refresh_preserves_env_values() {
  local PROJECT_DIR="$FIXTURE_DIR/preserve_project"
  local SANDBOX_DIR="$FIXTURE_DIR/preserve_sandbox"

  run_full_onboard "$PROJECT_DIR" "$SANDBOX_DIR" || return 0

  sed -i 's/^SERVE_PORT=.*/SERVE_PORT=99999/' "$SANDBOX_DIR/.env"

  bash "$ONBOARD_SCRIPT" --refresh \
    --name="testproj" \
    --sandbox="$SANDBOX_DIR" 2>&1

  grep -q "^SERVE_PORT=99999" "$SANDBOX_DIR/.env" \
    || { fail "SERVE_PORT was overwritten by refresh"; return; }

  pass "Refresh preserves operator .env values"
}

# ---------------------------------------------------------------------------
# Test: refresh requires --name and --sandbox
# ---------------------------------------------------------------------------
test_refresh_aborts_without_minimal_args() {
  local SANDBOX_DIR="$FIXTURE_DIR/minargs_sandbox"
  mkdir -p "$SANDBOX_DIR"

  set +e
  # Use </dev/null to prevent 'read' inside onboard.sh from consuming
  # stdin data inherited from the test runner (causes flaky failures
  # when the suite runs with a pipe or harness stdin).
  OUTPUT=$(bash "$ONBOARD_SCRIPT" --refresh --sandbox="$SANDBOX_DIR" </dev/null 2>&1)
  local EXIT_CODE=$?
  set -e

  if [[ "$EXIT_CODE" -eq 0 ]]; then
    fail "Refresh should have aborted without --name"
    return
  fi

  pass "Refresh aborts without --name"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
run_test test_fresh_onboard_creates_structure
run_test test_fresh_onboard_env_has_required_keys
run_test test_fresh_onboard_creates_provider_configs
run_test test_fresh_onboard_agents_md_contains_project_name
run_test test_onboard_aborts_if_sandbox_exists
run_test test_refresh_updates_makefile
run_test test_refresh_preserves_env_values
run_test test_refresh_aborts_without_minimal_args

test_done "scripts/onboard.sh"
