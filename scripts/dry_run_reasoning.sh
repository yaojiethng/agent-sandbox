#!/usr/bin/env bash
# dry_run_reasoning.sh
# Bearer self-check run inside the reasoning layer (agent) container during a dry-run.
# Bind-mounted at /dry_run_reasoning.sh via the dry-run compose overlay.
#
# Responsibility (bearer): assert the reasoning container is complete/ready per
# the readiness model (design devlog/discussions/20260828-design-settled-dry_run_phase_split.md),
# then write a per-container diagnostics record to the output mount for
# orchestration to validate (correct-container check). Checks are listed in
# readiness-layer order: docker_image -> workspace_mounts -> session_state ->
# session_data -> container_network -> agent_runtime. The reasoning container
# reads the capability layer's state via the shared volume (volumes-from) and
# verifies cross-container link-up (container_network).
#
# Exit codes:
#   0 - all CRITICAL checks passed (warnings may exist)
#   1 - one or more CRITICAL checks failed

# Intentionally no set -e: all checks must run even when some fail.
# Intentionally no set -u: env vars are checked explicitly with guards.
set -o pipefail

# The two probes share one preamble: each locates the harness by its
# conventional lib path, then dry_run_bootstrap resolves the paths the compose
# template passes as absolute env vars, falling back to dirs.sh when a probe
# runs without them.
LIBS_DIR="${LIBS_DIR:-/opt/sandbox/lib}"
# shellcheck source=/dev/null
source "$LIBS_DIR/dry_run_harness.sh"
dry_run_bootstrap

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# True iff this process is running as the bash interpreter on the probe script
# (not as a bare argument handed to the provider agent). Guards the invocation
# interface: `command:` must run `bash <script>`, never feed the script to the
# agent binary as input.
_running_as_bash_script() {
  [[ -n "${BASH_VERSION:-}" && "${0##*/}" == "dry_run_reasoning.sh" ]]
}

# Map a provider id to its agent binary name for the readiness check. Empty if
# unknown (the container may set AGENT_CMD to disambiguate).
_agent_binary_for_provider() {
  case "${1:-}" in
    pi)       echo "pi" ;;
    hermes)   echo "hermes" ;;
    opencode) echo "opencode" ;;
    *)        echo "" ;;
  esac
}

# Write the per-container diagnostics record: dry_run_write_record in
# src/libs/dry_run_harness.sh.

# ---------------------------------------------------------------------------
# docker_image / workspace_mounts - link-up
# ---------------------------------------------------------------------------
# Baked-image presence is CP-owned (dedup). Here the reasoning container asserts
# its compose-injected environment and workspace mounts are wired.

section "workspace_mounts link-up (environment + workspace)"
critical "AGENT_HOME is set"          bash -c '[[ -n "${AGENT_HOME:-}" ]]'
critical "PROVIDER_NAME is set"       bash -c '[[ -n "${PROVIDER_NAME:-}" ]]'
critical "INPUT_DIR exists (input mount)"        test -d "$INPUT_DIR"
critical "INPUT_DIR is read-only"                _is_readonly "$INPUT_DIR"
critical "OUTPUT_DIR exists (output mount)"      test -d "$OUTPUT_DIR"
critical "OUTPUT_DIR is writable"                _is_writable "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# session_state - state (via shared .git, written by capability layer)
# ---------------------------------------------------------------------------

section "session_state identity (via shared .git)"
critical "sandbox/.git/SESSION_STATE exists"     test -f "$SANDBOX_DIR/.git/SESSION_STATE"

check_init_sha_readable() {
  local sha
  sha=$(session_state_read "$SANDBOX_DIR" "init_sha" 2>/dev/null) || return 1
  [[ -n "$sha" ]]
}
critical "SESSION_STATE.init_sha readable" check_init_sha_readable

check_session_ts() {
  local ts
  ts=$(session_state_read "$SANDBOX_DIR" "session_ts" 2>/dev/null) || return 1
  [[ -n "$ts" ]]
}
warn_check "SESSION_STATE.session_ts readable" check_session_ts

# ---------------------------------------------------------------------------
# container_network - cross-component
# ---------------------------------------------------------------------------

section "container_network cross-component"
critical "SANDBOX_DIR exists (volumes-from)"     test -d "$SANDBOX_DIR"

# Capability-layer marker written in Phase 1 (dry_run_capability.sh) must be
# visible from the reasoning layer. Both probes resolve the marker from
# CHANGES_DIR, the shared mount, so the check tests the contract rather than a
# coincidence of two separately derived paths. An absent or wrong marker is a
# critical failure: the cross-container channel is dead.
_cap_marker="$CHANGES_DIR/.dryrun_capability_marker"
if test -f "$_cap_marker"; then
  _content=$(cat "$_cap_marker" 2>/dev/null)
  if [[ "$_content" == "CAPABILITY_LAYER_OK" ]]; then
    _pass "capability layer marker: readable from reasoning layer"
    # The marker is a handshake token, not channel content. The reader
    # consumes it, so a later probe cannot read a stale marker and pass this
    # check without a live capability layer in front of it. A wrong or
    # unreadable marker stays in place for diagnosis.
    rm -f "$_cap_marker"
  else
    _fail "capability layer marker: unexpected content: $_content"
  fi
else
  _fail "capability layer marker: not found under CHANGES_DIR (Phase 1 may not have run)"
fi

section "container_network session-diffs round-trip"
check_changes_dir_matches_mount_target() {
  local expected="${EXPECTED_MOUNT_TARGET:-/home/agentuser/workspace/session-diffs}"
  [[ "$CHANGES_DIR" == "$expected" ]]
}
critical "CHANGES_DIR resolves to bind mount target" check_changes_dir_matches_mount_target

_marker="$CHANGES_DIR/.dryrun_seam_test"
if mkdir -p "$CHANGES_DIR" 2>/dev/null && echo "REASONING_OK" > "$_marker" 2>/dev/null; then
  _readback=$(cat "$_marker" 2>/dev/null) || _readback=""
  if [[ "$_readback" == "REASONING_OK" ]]; then
    _pass "reasoning layer round-trip: wrote and read back marker"
    rm -f "$_marker"
  else
    _fail "reasoning layer round-trip: marker empty or unreadable"
  fi
else
  _fail "reasoning layer round-trip: could not write to $CHANGES_DIR"
fi

# ---------------------------------------------------------------------------
# agent_runtime - process
# ---------------------------------------------------------------------------

section "agent_runtime process"
warn_check "running as non-root" bash -c '[[ "$(id -u)" -ne 0 ]]'

section "agent_runtime probe invocation"
critical "probe runs as a bash script, not as agent input" _running_as_bash_script
warn_check "probe interpreter is bash (STDIN not fed to the agent)" bash -c '[[ -n "${BASH_VERSION:-}" ]]'

section "agent_runtime agent readiness"
# The agent is NOT launched during dry-run (launching would start a real
# session / consume the probe args as agent input). Readiness-to-take-input is
# asserted by: provider preflight env (workspace_mounts/AGENT_HOME), agent
# binary present + executable, and a writable output channel (liveness).
_agent_command="${AGENT_CMD:-$(_agent_binary_for_provider "$PROVIDER_NAME")}"
if [[ -n "$_agent_command" ]] && command -v "$_agent_command" >/dev/null 2>&1; then
  _pass "agent binary present and executable ($_agent_command)"
else
  if [[ -z "$_agent_command" ]]; then
    _fail "agent binary unknown for provider '$PROVIDER_NAME' (set AGENT_CMD)"
  else
    _fail "agent binary not executable: $_agent_command"
  fi
fi

section "agent_runtime liveness"
printf "\n=== liveness write ===\n"
if echo "PASS" > "$OUTPUT_DIR/liveness.txt" 2>/dev/null; then
  _pass "liveness.txt written to workspace/output"
else
  _fail "liveness.txt written to workspace/output"
fi

# ---------------------------------------------------------------------------
# Summary + diagnostics record
# ---------------------------------------------------------------------------

dry_run_write_record "${OUTPUT_DIR}/dryrun.reasoning.record" \
  "docker_image workspace_mounts session_state session_data container_network agent_runtime"
dry_run_summary

[[ $CRITICAL_FAILS -eq 0 ]]