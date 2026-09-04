#!/usr/bin/env bash
# -------------------------
# Host-side start_agent.sh behavioral tests  --  start policy flags
# (default/--rebuild/--refresh), rendered-compose contract (full substitution,
# container naming, session labels), removed-flag rejection, help/usage surface,
# WSL path validation, and the interactive config wizard.
#
# All fixtures created under a temp dir  --  no repos created inside the harness repo.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"

# ---------------------------------------------------------------------------
# Behavioral start tests: run start_agent.sh end-to-end under docker stubs and
# assert on observable outcomes (docker trace, persisted compose file).
# ---------------------------------------------------------------------------

# run_start_session DIR ARGS...
#   Builds a minimal start fixture under DIR (sandbox tree + .env + committed
#   project repo), runs `start_agent.sh ARGS...` with docker stubs shadowing
#   PATH, and captures results in globals:
#     START_RC       --  exit code
#     START_OUT      --  combined stdout+stderr
#     START_TRACE    --  path to the docker trace log
#     START_COMPOSE  --  path to the persisted compose file (empty if none)
run_start_session() {
  local dir="$1"; shift
  mkdir -p "$dir/sandbox/.workspace/session-diffs" \
           "$dir/sandbox/.workspace/input" "$dir/sandbox/.workspace/output"
  cat > "$dir/sandbox/.env" <<EOF
SANDBOX_DIR=$dir/sandbox
PROJECT_DIR=$dir/project
EOF
  make_committed_repo "$dir/project"
  START_TRACE="$dir/docker-trace.log"
  : > "$START_TRACE"
  START_OUT="$(cd "$dir" && \
    PATH="$REPO_ROOT/tests/stubs:$PATH" \
    DOCKER_TRACE_LOG="$START_TRACE" \
    bash "$REPO_ROOT/scripts/start_agent.sh" "$@" 2>&1)"
  START_RC=$?
  START_COMPOSE="$(ls "$dir/sandbox/.compose"/*.yml 2>/dev/null | head -1)"
}

# Default policy (no --refresh/--rebuild) starts from existing images;
# building is an explicit opt-in.
test_default_policy_starts_without_building() {
  local dir="$FIXTURE_DIR/start_default_nobuild"
  run_start_session "$dir" standard \
    --name=stest --project="$dir/project" --sandbox="$dir/sandbox" --provider=pi
  if [[ "$START_RC" -ne 0 ]]; then
    fail "default start failed rc=$START_RC: $START_OUT"; return
  fi
  if grep -q "\] build " "$START_TRACE"; then
    fail "default policy issued docker build (trace: $(cat "$START_TRACE"))"
  else
    pass "default policy starts a session without building images"
  fi
}

# --rebuild forces a full rebuild: the agent image build carries --no-cache.
test_rebuild_flag_builds_agent_with_no_cache() {
  local dir="$FIXTURE_DIR/start_rebuild_flag"
  run_start_session "$dir" standard \
    --name=rtest --project="$dir/project" --sandbox="$dir/sandbox" --provider=pi --rebuild
  if [[ "$START_RC" -ne 0 ]]; then
    fail "--rebuild start failed rc=$START_RC: $START_OUT"; return
  fi
  if grep -q "\] build .*--no-cache" "$START_TRACE"; then
    pass "--rebuild builds images with --no-cache"
  else
    fail "--rebuild produced no --no-cache build; trace: $(cat "$START_TRACE")"
  fi
}

# --refresh rebuilds while preserving the layer cache: builds happen,
# none of them with --no-cache.
test_refresh_flag_builds_without_no_cache() {
  local dir="$FIXTURE_DIR/start_refresh_flag"
  run_start_session "$dir" standard \
    --name=rtest --project="$dir/project" --sandbox="$dir/sandbox" --provider=pi --refresh
  if [[ "$START_RC" -ne 0 ]]; then
    fail "--refresh start failed rc=$START_RC: $START_OUT"; return
  fi
  if ! grep -q "\] build " "$START_TRACE"; then
    fail "--refresh produced no builds at all; trace: $(cat "$START_TRACE")"; return
  fi
  if grep -q "\] build .*--no-cache" "$START_TRACE"; then
    fail "--refresh must not pass --no-cache (it is the cache-preserving path)"
  else
    pass "--refresh builds sandbox+agent without --no-cache"
  fi
}

# The generated compose file is the container runtime's input: every {{VAR}}
# placeholder must be substituted and both containers must be named from
# project + provider + session.
test_rendered_compose_fully_substituted_and_names_both_containers() {
  local dir="$FIXTURE_DIR/start_render_compose"
  run_start_session "$dir" standard \
    --name=ctest --project="$dir/project" --sandbox="$dir/sandbox" --provider=pi
  if [[ "$START_RC" -ne 0 || -z "$START_COMPOSE" ]]; then
    fail "start did not persist a compose file: rc=$START_RC out=$START_OUT"; return
  fi
  local placeholders names
  # Comments may legitimately mention the {{VAR}} syntax; only unsubstituted
  # placeholders on active lines are defects.
  placeholders=$(grep -v "^[[:space:]]*#" "$START_COMPOSE" | grep -c "{{") || placeholders=0
  names=$(grep -c "container_name:" "$START_COMPOSE") || names=0
  if [[ "$placeholders" -eq 0 && "$names" -ge 2 ]] \
     && grep -q "container_name: sandbox-ctest-" "$START_COMPOSE" \
     && grep -q "container_name: pi-ctest-" "$START_COMPOSE"; then
    pass "persisted compose fully substituted; sandbox and agent containers named"
  else
    fail "persisted compose bad: placeholders=$placeholders names=$names file=$START_COMPOSE"
  fi
}

# Session labels are how prune/resume find a session's resources later, so the
# generated compose must stamp concrete session identity onto the labels block.
test_rendered_compose_labels_carry_concrete_session_identity() {
  local dir="$FIXTURE_DIR/start_render_labels"
  run_start_session "$dir" standard \
    --name=ltest --project="$dir/project" --sandbox="$dir/sandbox" --provider=pi
  if [[ "$START_RC" -ne 0 || -z "$START_COMPOSE" ]]; then
    fail "start did not persist a compose file: rc=$START_RC out=$START_OUT"; return
  fi
  if grep -q "agent-sandbox.project-name: ltest" "$START_COMPOSE" \
     && grep -Eq "agent-sandbox.session-id: [[:alnum:]]+" "$START_COMPOSE" \
     && grep -Eq "agent-sandbox.host-branch: [[:alnum:]]+" "$START_COMPOSE"; then
    pass "session labels carry concrete project, session id and branch"
  else
    fail "session labels missing or unsubstituted in $START_COMPOSE"
  fi
}

# Removed flags stay removed: --rebuild-base must be rejected as unknown,
# not silently accepted or half-recognized.
test_removed_rebuild_base_flag_is_rejected() {
  local out rc
  out=$(bash "$REPO_ROOT/scripts/start_agent.sh" standard \
        --name=x --project="$FIXTURE_DIR" --rebuild-base 2>&1); rc=$?
  if [[ $rc -ne 0 && "$out" == *"Unknown flag: --rebuild-base"* ]]; then
    pass "removed --rebuild-base flag rejected as unknown"
  else
    fail "--rebuild-base not rejected cleanly: rc=$rc out=$out"
  fi
}

# Functional check: start_agent.sh --help prints the full usage (all modes, all
# required flags, provider required with no default) and exits 0.
test_help_flag_prints_full_usage() {
  local output rc
  output=$(bash "$REPO_ROOT/scripts/start_agent.sh" --help 2>&1) && rc=$? || rc=$?

  if [[ "$rc" -eq 0 && "$output" == *"Usage: start_agent.sh"* \
      && "$output" == *"--provider"* \
      && "$output" == *"standard"* && "$output" == *"--serve"* \
      && "$output" == *"dry-run"* ]]; then
    pass "start_agent.sh --help prints full usage and exits 0"
  else
    fail "start_agent.sh --help: expected full usage, rc=$rc output=$output"
  fi
}

test_help_short_flag_prints_usage() {
  local output rc
  output=$(bash "$REPO_ROOT/scripts/start_agent.sh" -h 2>&1) && rc=$? || rc=$?

  if [[ "$rc" -eq 0 && "$output" == *"Usage: start_agent.sh"* ]]; then
    pass "start_agent.sh -h prints usage and exits 0"
  else
    fail "start_agent.sh -h: expected usage, rc=$rc output=$output"
  fi
}

# --provider has no default: omitting it must fail fast with a clear
# diagnostic instead of a cryptic image-naming error downstream.
test_missing_provider_fails_fast_with_clear_error() {
  local out rc
  out=$(bash "$REPO_ROOT/scripts/start_agent.sh" standard \
        --name=x --project="$FIXTURE_DIR" 2>&1); rc=$?
  if [[ $rc -ne 0 && "$out" == *"--provider is required"* ]]; then
    pass "missing --provider fails fast with a clear diagnostic"
  else
    fail "missing --provider: expected clear failure, got rc=$rc out=$out"
  fi
}

# ---------------------------------------------------------------------------
# WSL path validation
# ---------------------------------------------------------------------------
# validate_wsl_path rejects Windows drive paths with a WSL conversion hint.
# start_agent.sh is now dual-use (rule 1.11 guard) and validate_wsl_path returns
# (rule 3.1), so it can be sourced and called in-process.
source "$REPO_ROOT/scripts/start_agent.sh"

test_wsl_path_accepts_linux_paths() {
  local out rc
  out=$(validate_wsl_path "PROJECT_DIR" "/mnt/c/Users/proj" 2>&1); rc=$?
  if [[ $rc -eq 0 && -z "$out" ]]; then
    pass "validate_wsl_path accepts Linux paths silently"
  else
    fail "validate_wsl_path rejected a valid Linux path: rc=$rc out=$out"
  fi
}

test_wsl_path_rejects_windows_drive_paths() {
  local out rc
  out=$(validate_wsl_path "PROJECT_DIR" 'C:\Users\proj' 2>&1); rc=$?
  if [[ $rc -ne 0 && "$out" == *"must be a WSL/Linux path"* && "$out" == *"wslpath"* ]]; then
    pass "validate_wsl_path rejects Windows drive path with conversion hint"
  else
    fail "validate_wsl_path C:\\... : rc=$rc out=$out"
  fi
}

# ---------------------------------------------------------------------------
# Interactive config wizard tests (F2 design D11)
# ---------------------------------------------------------------------------

# Help surface: --interactive is described as the config wizard.
test_wizard_help_describes_interactive() {
  local out
  out="$(bash "$REPO_ROOT/scripts/start_agent.sh" --help 2>&1)"
  if echo "$out" | grep -q -- "--interactive  interactive config wizard"; then
    pass "start --help: --interactive documented as config wizard"
  else
    fail "start --help: --interactive not documented as config wizard; out=$out"
  fi
}

# --interactive with no --provider: provider picker shown, build policy picker,
# then confirm. Abort on 'n' -> non-zero and no session record created (the
# clean-abort gate  --  no partial start).
test_wizard_picker_abort() {
  local dir="$FIXTURE_DIR/wizard_pick_abort"
  mkdir -p "$dir/project" "$dir/sandbox"
  local out rc
  out="$(printf '1\n\nn\n' | bash "$REPO_ROOT/scripts/start_agent.sh" standard \
      --name=wtest --project="$dir/project" --sandbox="$dir/sandbox" \
      --interactive 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] \
     && echo "$out" | grep -q "Select a provider" \
     && echo "$out" | grep -iq "aborted" \
     && ! ls "$dir/sandbox/.compose"/*.yml >/dev/null 2>&1; then
    pass "start --interactive: picker + confirm, abort on 'n' -> non-zero, no session record"
  else
    fail "start --interactive: expected picker+abort+no record, got rc=$rc: $out"
  fi
}

# --interactive with --provider supplied: no provider re-prompt (D1  --  supplied
# args override the wizard's suggestions); the confirm shows the supplied
# provider; abort on 'n'.
test_wizard_provider_supplied_no_reprompt() {
  local dir="$FIXTURE_DIR/wizard_provider_arg"
  mkdir -p "$dir/project" "$dir/sandbox"
  local out rc
  out="$(printf '\nn\n' | bash "$REPO_ROOT/scripts/start_agent.sh" standard \
      --name=wtest --project="$dir/project" --sandbox="$dir/sandbox" \
      --provider=pi --interactive 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] \
     && ! echo "$out" | grep -q "Select a provider" \
     && echo "$out" | grep -q "provider: pi" \
     && echo "$out" | grep -iq "aborted"; then
    pass "start --interactive: supplied --provider not re-prompted; confirm shows provider, abort"
  else
    fail "start --interactive: expected no provider re-prompt, got rc=$rc: $out"
  fi
}

# --interactive accept path: the wizard's selections flow through to a real
# session under the docker stub  --  run completes, the .compose record is
# written, and compose up is issued. Proves the wizard integrates with the
# existing non-interactive start pipeline.
test_wizard_accept_runs_to_completion() {
  local dir="$FIXTURE_DIR/wizard_accept"
  mkdir -p "$dir/sandbox/.workspace/session-diffs" \
           "$dir/sandbox/.workspace/input" "$dir/sandbox/.workspace/output"
  cat > "$dir/sandbox/.env" <<EOF
SANDBOX_DIR=$dir/sandbox
PROJECT_DIR=$dir/project
EOF
  make_committed_repo "$dir/project"

  local out rc trace
  trace="$dir/trace.log"
  out="$(cd "$dir" && printf '1\n2\ny\n' | \
    PATH="$REPO_ROOT/tests/stubs:$PATH" \
    DOCKER_TRACE_LOG="$trace" \
    bash "$REPO_ROOT/scripts/start_agent.sh" standard \
      --name=wtest --project="$dir/project" --sandbox="$dir/sandbox" \
      --interactive) 2>&1"; rc=$?
  local rec
  rec=$(ls "$dir/sandbox/.compose"/*.yml 2>/dev/null | head -1)
  if [[ $rc -eq 0 && -n "$rec" && -f "$rec" ]] \
     && grep -q "compose up" "$trace"; then
    pass "start --interactive: accept path runs to completion (compose record + up)"
  else
    fail "start --interactive: accept path failed, rc=$rc record=$rec: $out"
  fi
}

# -------------------------
# Run all tests
# -------------------------

run_test test_default_policy_starts_without_building
run_test test_rebuild_flag_builds_agent_with_no_cache
run_test test_refresh_flag_builds_without_no_cache
run_test test_rendered_compose_fully_substituted_and_names_both_containers
run_test test_rendered_compose_labels_carry_concrete_session_identity
run_test test_removed_rebuild_base_flag_is_rejected
run_test test_help_flag_prints_full_usage
run_test test_help_short_flag_prints_usage
run_test test_missing_provider_fails_fast_with_clear_error
run_test test_wsl_path_accepts_linux_paths
run_test test_wsl_path_rejects_windows_drive_paths
run_test test_wizard_help_describes_interactive
run_test test_wizard_picker_abort
run_test test_wizard_provider_supplied_no_reprompt
run_test test_wizard_accept_runs_to_completion

test_done
