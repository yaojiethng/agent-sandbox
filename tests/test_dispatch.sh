#!/usr/bin/env bash
# tests/test_dispatch.sh  (exec-based dispatch oracle)
#
# Dispatch oracle tests for the exec-based dispatch model. Asserts that
# agent-sandbox.sh main() routes flags and subcommands to the correct
# exec'd scripts with the correct arguments.
#
# Uses mock scripts on a temp SCRIPTS dir to capture invocations.
# No Docker, no git, no filesystem fixtures needed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/libs/test_common.sh"

# =============================================================================
# Mock infrastructure
# =============================================================================

CAPTURED=()

# mock_exec — capture exec calls without executing
mock_exec() { echo "capture: exec $*"; }

# =============================================================================
# Setup: source agent-sandbox.sh with mocks
# =============================================================================

setup() {
  CAPTURED=()
}

MOCK_SCRIPTS_DIR=""
setup_mocks() {
  MOCK_SCRIPTS_DIR=$(mktemp -d /tmp/test_dispatch_mocks_XXXXXX)

  # Create mock scripts for every subcommand that gets exec'd
  local scripts=(
    "onboard.sh"
    "stop.sh"
    "start_agent.sh"
  )
  local workflows=(
    "apply.sh"
    "draft.sh"
    "confirm.sh"
    "reject.sh"
  )
  local libs=(
    "package_diff.sh"
    "package_branch.sh"
  )

  for s in "${scripts[@]}"; do
    cat > "$MOCK_SCRIPTS_DIR/$s" << SCRIPT
echo "capture: MOCK $s \$@"
SCRIPT
    chmod +x "$MOCK_SCRIPTS_DIR/$s"
  done

  for s in "${workflows[@]}"; do
    mkdir -p "$MOCK_SCRIPTS_DIR/workflows"
    cat > "$MOCK_SCRIPTS_DIR/workflows/$s" << SCRIPT
echo "capture: MOCK workflows/$s \$@"
SCRIPT
    chmod +x "$MOCK_SCRIPTS_DIR/workflows/$s"
  done

  for s in "${libs[@]}"; do
    mkdir -p "$MOCK_SCRIPTS_DIR/libs"
    cat > "$MOCK_SCRIPTS_DIR/libs/$s" << SCRIPT
echo "capture: MOCK libs/$s \$@"
SCRIPT
    chmod +x "$MOCK_SCRIPTS_DIR/libs/$s"
  done

  # build.sh gets a mock too — it will be exec'd by agent-sandbox build
  cat > "$MOCK_SCRIPTS_DIR/build.sh" << SCRIPT
echo "capture: MOCK build.sh \$@"
SCRIPT
  chmod +x "$MOCK_SCRIPTS_DIR/build.sh"

  # Point SCRIPTS at mock dir for all exec'd subcommands
  SCRIPTS="$MOCK_SCRIPTS_DIR"
}

source_harness() {
  local resolved
  resolved=$(mktemp /tmp/test_dispatch_src_XXXXXX)
  sed "s|@@AGENT_SANDBOX_REPO@@|$REPO_ROOT|g" "$REPO_ROOT/scripts/agent-sandbox.sh" > "$resolved"

  # Override exec to capture
  exec() { mock_exec "$@"; }

  # Override SCRIPTS to point at mock dir AFTER top-level sources are done
  # We need the real build.sh sourced at top level for now.
  # Actually — after refactor, agent-sandbox.sh only sources build.sh and routing.sh
  # at top level. We want build.sh sourced for real (it defines build_sandbox etc.),
  # but we DON'T want it to execute.
  # We DO want the SCRIPTS dir to point at mocks for the exec calls.
  # Solution: source the harness with real AGENT_SANDBOX_REPO, then swap SCRIPTS.

  # Source the harness (no top-level sources after refactor — pure dispatch table)
  source "$resolved"
  rm -f "$resolved"
}

# =============================================================================
# Helper: run main and capture
# =============================================================================

dispatch_and_capture() {
  CAPTURED=()
  local stdout
  stdout=$(main "$@" 2>/dev/null) || true
  while IFS= read -r line; do
    if [[ "$line" == capture:* ]]; then
      CAPTURED+=("${line#capture: }")
    fi
  done <<< "$stdout"
}

# =============================================================================
# Tests — build subcommand (exec's build.sh with --targets)
# =============================================================================

test_build_default_all() {
  setup
  dispatch_and_capture build --name=test --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"build.sh"* ]] && [[ "$c" != *"MOCK"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "build (default): execs build.sh"
  else
    fail "build (default): expected exec build.sh, got: ${CAPTURED[*]}"
  fi
}

test_build_with_targets() {
  setup
  dispatch_and_capture build --name=test --project=/tmp/p --sandbox=/tmp/s --targets=pi

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"build.sh"* ]] && [[ "$c" == *"--targets"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "build --targets=pi: passes --targets flag through"
  else
    fail "build --targets=pi: expected --targets in exec, got: ${CAPTURED[*]}"
  fi
}

test_build_with_rebuild() {
  setup
  dispatch_and_capture build --name=test --project=/tmp/p --sandbox=/tmp/s --rebuild

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"build.sh"* ]] && [[ "$c" == *"--rebuild"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "build --rebuild: passes --rebuild flag through"
  else
    fail "build --rebuild: expected --rebuild in exec, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests — start / serve / dry-run (call start_agent.sh as subprocess)
# =============================================================================

test_start_default() {
  setup
  dispatch_and_capture start --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "MOCK start_agent.sh"* ]] && [[ "$c" == *"standard"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "start: calls start_agent.sh in standard mode"
  else
    fail "start: expected MOCK start_agent.sh standard, got: ${CAPTURED[*]}"
  fi
}

test_serve_mode() {
  setup
  dispatch_and_capture serve --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "MOCK start_agent.sh"* ]] && [[ "$c" == *"serve"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "serve: calls start_agent.sh in serve mode"
  else
    fail "serve: expected MOCK start_agent.sh serve, got: ${CAPTURED[*]}"
  fi
}

test_dry_run_mode() {
  setup
  dispatch_and_capture dry-run --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "MOCK start_agent.sh"* ]] && [[ "$c" == *"dry-run"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "dry-run: calls start_agent.sh in dry-run mode"
  else
    fail "dry-run: expected MOCK start_agent.sh dry-run, got: ${CAPTURED[*]}"
  fi
}

test_start_with_passthrough() {
  setup
  dispatch_and_capture start --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes --extra-flag

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "MOCK start_agent.sh"* ]] && [[ "$c" == *"extra-flag"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "start: passes through extra flags"
  else
    fail "start: expected extra-flag in passthrough, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests — apply subcommand (exec's workflows/apply.sh)
# =============================================================================

test_apply_with_diff() {
  setup
  dispatch_and_capture apply --project=/tmp/p --sandbox=/tmp/s --diff=/tmp/mydiff.diff

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/apply.sh"* ]] && [[ "$c" == *"--diff"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "apply --diff=<path>: execs apply.sh with --diff flag"
  else
    fail "apply --diff=<path>: expected exec apply.sh, got: ${CAPTURED[*]}"
  fi
}

test_apply_with_branch() {
  setup
  dispatch_and_capture apply --project=/tmp/p --sandbox=/tmp/s --diff=/tmp/mydiff.diff --branch=feature-x

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/apply.sh"* ]] && [[ "$c" == *"--branch=feature-x"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "apply --diff --branch: passes --branch flag through"
  else
    fail "apply --diff --branch: expected --branch in exec, got: ${CAPTURED[*]}"
  fi
}

test_apply_with_force() {
  setup
  dispatch_and_capture apply --project=/tmp/p --sandbox=/tmp/s --diff=/tmp/mydiff.diff --force

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/apply.sh"* ]] && [[ "$c" == *"--force"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "apply --diff --force: passes --force flag through"
  else
    fail "apply --diff --force: expected --force in exec, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests — draft subcommand (exec's workflows/draft.sh)
# =============================================================================

test_draft_noninteractive() {
  setup
  # Non-interactive draft resolves via router — will fail without session dirs.
  # We just verify it execs draft.sh rather than exploding.
  dispatch_and_capture draft --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/draft.sh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "draft: execs draft.sh"
  else
    fail "draft: expected exec draft.sh, got: ${CAPTURED[*]}"
  fi
}

test_draft_with_session() {
  setup
  dispatch_and_capture draft --project=/tmp/p --sandbox=/tmp/s --session=my-session

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/draft.sh"* ]] && [[ "$c" == *"--session"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "draft --session: passes --session flag through"
  else
    fail "draft --session: expected --session in exec, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests — confirm / reject (exec's workflows/confirm.sh, workflows/reject.sh)
# =============================================================================

test_confirm_default() {
  setup
  dispatch_and_capture confirm --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/confirm.sh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "confirm: execs confirm.sh"
  else
    fail "confirm: expected exec confirm.sh, got: ${CAPTURED[*]}"
  fi
}

test_confirm_with_target() {
  setup
  dispatch_and_capture confirm --project=/tmp/p --sandbox=/tmp/s --target=main

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/confirm.sh"* ]] && [[ "$c" == *"--target"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "confirm --target: passes --target flag through"
  else
    fail "confirm --target: expected --target in exec, got: ${CAPTURED[*]}"
  fi
}

test_reject_default() {
  setup
  dispatch_and_capture reject --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/reject.sh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "reject: execs reject.sh"
  else
    fail "reject: expected exec reject.sh, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests — stop / onboard / package-* (exec'd scripts)
# =============================================================================

test_stop() {
  setup
  dispatch_and_capture stop --name=test --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"stop.sh"* ]] && [[ "$c" == *"--name=test"* ]] && [[ "$c" == *"--sandbox=/tmp/s"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "stop: execs stop.sh with name and sandbox"
  else
    fail "stop: expected exec stop.sh, got: ${CAPTURED[*]}"
  fi
}

test_onboard() {
  setup
  dispatch_and_capture onboard --name=test --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"onboard.sh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "onboard: execs onboard.sh"
  else
    fail "onboard: expected exec onboard.sh, got: ${CAPTURED[*]}"
  fi
}

test_package_diff() {
  setup
  # package-diff checks for .env at SANDBOX_DIR/.env — create it
  mkdir -p /tmp/s
  touch /tmp/s/.env
  dispatch_and_capture package-diff --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"package_diff.sh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "package-diff: execs package_diff.sh"
  else
    fail "package-diff: expected exec package_diff.sh, got: ${CAPTURED[*]}"
  fi
  rm -rf /tmp/s
}

test_package_branch() {
  setup
  dispatch_and_capture package-branch --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"package_branch.sh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "package-branch: execs package_branch.sh"
  else
    fail "package-branch: expected exec package_branch.sh, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests — error handling
# =============================================================================

test_unknown_subcommand() {
  setup
  local output
  output=$(main unknown-command --sandbox=/tmp/s 2>&1) || true

  if [[ "$output" == *"Unknown subcommand"* ]] && [[ "$output" == *"Valid subcommands"* ]]; then
    pass "unknown subcommand: prints error with valid subcommands list"
  else
    fail "unknown subcommand: expected error message, got: $output"
  fi
}

test_missing_subcommand() {
  setup
  local output
  output=$(main 2>&1) || true

  if [[ "$output" == *"Usage: agent-sandbox"* ]]; then
    pass "missing subcommand: prints usage"
  else
    fail "missing subcommand: expected usage, got: $output"
  fi
}

test_build_missing_args() {
  setup
  local output
  output=$(main build 2>&1) || true

  # After refactor: build validates --name/--project/--sandbox before exec'ing
  if [[ "$output" == *"required"* ]]; then
    pass "build without required args: prints error (validation added in refactor)"
  else
    fail "build without required args: expected validation error, got: $output"
  fi
}

# =============================================================================
# Run
# =============================================================================

source_harness
setup_mocks

run_test test_build_default_all
run_test test_build_with_targets
run_test test_build_with_rebuild
run_test test_start_default
run_test test_serve_mode
run_test test_dry_run_mode
run_test test_start_with_passthrough
run_test test_apply_with_diff
run_test test_apply_with_branch
run_test test_apply_with_force
run_test test_draft_noninteractive
run_test test_draft_with_session
run_test test_confirm_default
run_test test_confirm_with_target
run_test test_reject_default
run_test test_stop
run_test test_onboard
run_test test_package_diff
run_test test_package_branch
run_test test_unknown_subcommand
run_test test_missing_subcommand
run_test test_build_missing_args

# Cleanup
rm -rf "$MOCK_SCRIPTS_DIR"

echo ""
echo "${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ "$FAIL" -eq 0 ]]
