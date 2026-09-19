#!/usr/bin/env bash
# libs/provider-entrypoint.sh
# Harness-owned wrapper entrypoint for all reasoning layer provider containers.
# Copied into the image via the build context  --  a change to this file triggers
# a Docker layer cache miss on the COPY step in provider.dockerfile.
#
# Responsibilities:
#   1. Provision AGENT_HOME from image template (copy-in config files not
#      provided by Docker bind mounts  --  prompts/, sessions/, skills/).
#   2. Run generic pre-flight checks (env vars, container libs, AGENT_HOME).
#   3. Source provider-specific pre-flight script if present
#      (/opt/sandbox/bin/provider-preflight.sh).
#   4. Run the provider's real entrypoint as a synchronous foreground child so
#      that TUI input works correctly.
#
# Provider-specific logic (settings.json merge, path overrides, custom checks)
# belongs in src/reasoning/providers/<n>/preflight.sh, staged as provider-preflight.sh in
# the build context. The shared entrypoint stays generic.
#
# Config files (settings.json, auth.json, models.json, AGENTS.md) are
# copy-in from the baked template (/opt/workflow/agent/config/) at startup.
# Subdirectories prompts/, sessions/, skills/ are Docker bind-mounted  -- 
# they shadow the template copies at runtime. See devlog/roadmap.md
# M2.4 for the design rationale.
#
# Required environment variables (set via ENV in provider.dockerfile):
#   AGENT_HOME           --  provider config dir inside the container
#   PROVIDER_NAME        --  provider identifier
#
# No filesystem paths are hardcoded in this script.
#
# Why synchronous foreground execution
# -------------------------------------
# TUI applications require:
#   - stdin connected to the TTY (isatty = true)
#   - membership in the terminal foreground process group (reads without SIGTTIN)
#   - SIGWINCH delivery for terminal resize
#
# Both background-job approaches tried during development failed these requirements:
#
#   "cmd &" without job control (set -m):
#     POSIX mandates stdin = /dev/null for background jobs in non-interactive
#     shells. The agent reads from /dev/null. No input reaches the TUI.
#
#   "cmd &" with job control (set -m) + fg:
#     stdin is the PTY, but the agent starts in its own process group (not the
#     terminal foreground group). The first terminal read generates SIGTTIN,
#     stopping the process mid-TUI-initialisation. fg resumes it, but the TUI
#     library is in an inconsistent state and exits.
#
# A synchronous foreground child avoids both problems: stdin is inherited
# directly from the shell (the PTY in Docker), and the child is in the shell's
# process group, which is the terminal foreground group.
#
# SIGTERM limitation
# ------------------
# When a TERM trap is set and a synchronous foreground child is running, bash
# defers the trap until the child exits. This means "docker stop" SIGTERM is
# not delivered promptly to the agent; after the 10s grace period Docker sends
# SIGKILL and copy-out does not run.
#
# This only affects the "docker stop mid-session" path. For all normal exit
# paths (user quits TUI, agent exits cleanly), session state is preserved
# because the sessions/ subdirectory is bind-mounted directly  --  no copy-out
# needed. Config files (settings.json, auth.json) are regenerated from the
# template on next startup (ephemeral by design, avoids utime/EPERM).
# If cleanup on docker stop is required, implement it at the harness level:
# run_agent.sh can copy provider config out via "docker cp" after the container
# exits, independent of the entrypoint.

set -euo pipefail

trap '' SIGTSTP

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

_require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "provider-entrypoint: $name is not set" >&2
    exit 1
  fi
}

_require_var AGENT_HOME
_require_var PROVIDER_NAME

# ---------------------------------------------------------------------------
# Provision AGENT_HOME from image template
# ---------------------------------------------------------------------------
# Provisions AGENT_HOME by copying files from the image template.
# Docker bind-mounted subdirs overlay the copied content  --  the copy-in
# seeds them on first run; subsequent runs use persisted host content.
_provision_agent_home() {
  local template="${1:?provision_agent_home requires template_dir}"
  local target="${2:?provision_agent_home requires target_dir}"

  if [[ ! -d "$template" ]]; then
    echo "FATAL: Config template $template not found  --  image may be stale" >&2
    exit 1
  fi

  mkdir -p "$target"

  # Metadata-agnostic provisioning: --no-preserve=all avoids EPERM
  # on cross-filesystem hosts (macOS virtiofs, Windows 9p) where
  # non-privileged users cannot set timestamps or ownership on
  # bind-mounted subdirs. -T treats target as the destination
  # directory (not a subdir inside it), preventing double-nesting
  # when $target already exists (Docker pre-creates bind mount
  # parent dirs at container start).
  cp -RT --no-preserve=all "$template/" "$target/"
}

PROVISION_TEMPLATE="/opt/workflow/agent/config"
if [[ -d "$PROVISION_TEMPLATE" ]]; then
  _provision_agent_home "$PROVISION_TEMPLATE" "$AGENT_HOME"
fi
unset PROVISION_TEMPLATE

# ---------------------------------------------------------------------------
# Preflight: verify container libs
# ---------------------------------------------------------------------------
# /opt/sandbox/lib/ is baked into the image at build time. If files are
# missing, the image is stale and must be rebuilt with `make build`.
#
# session_state.sh is CRITICAL  --  sourced unconditionally by dry_run_reasoning.sh.
# The remaining files are WARN  --  fine to start but certain diagnostics or
# session operations will fail at runtime.
LIB_DIR="/opt/sandbox/lib"
for entry in "session_state.sh:CRITICAL" "dirs.sh:WARN" "routing.sh:WARN" \
             "diff.sh:WARN" "diff_export.sh:WARN" \
             "package_branch.sh:WARN"; do
  lib="${entry%%:*}"
  severity="${entry##*:}"
  if [[ ! -f "$LIB_DIR/$lib" ]]; then
    if [[ "$severity" == "CRITICAL" ]]; then
      echo "FATAL: $LIB_DIR/$lib is missing  --  image is stale, rebuild with 'make build'" >&2
      exit 1
    else
      echo "WARN: $LIB_DIR/$lib is missing  --  image may be stale" >&2
    fi
  fi
done
unset LIB_DIR

# ---------------------------------------------------------------------------
# Preflight: container<->container interface contract
# ---------------------------------------------------------------------------
# The sandbox container starts and finishes initializing first, writing its
# own baked interface-contract version into SESSION_STATE at init. This agent
# entrypoint runs once both are up -- the first moment a container<->
# container comparison is possible (ADR interface_contract_compatibility.md).
#
# It compares this agent's baked version against the sandbox's recorded
# version (which reflects the sandbox image's bake). A definite mismatch means
# the two images were built from different contract revisions -- an
# orchestration error or corrupt session state, not ordinary drift -- and is
# surfaced as such. The check is expected to be superfluous when preflight
# passes; a failure therefore names the larger problem. Policy follows
# interface_contract_strict(): hard-stop on definite mismatch under strict;
# warn in the parallel phase.

# _check_container_contract
#   Compares the agent image's baked interface-contract version against the
#   sandbox's recorded version (SESSION_STATE.interface_contract_version,
#   written by the sandbox at init from its own bake).
#   Returns 1 only on a definite mismatch under strict policy. Warns (returns
#   0) on a missing record key (pre-record image -- upgrade path) and under
#   warn policy. Best-effort: skips silently when the lib or record is
#   unavailable so the entrypoint never hard-aborts on a missing check.
_check_container_contract() {
  # Test seams mirror the capability entrypoint (SANDBOX_LIB_DIR). Production
  # defaults resolve to the baked image paths.
  local lib="${CONTRACT_LIB:-/opt/sandbox/lib/interface_contract.sh}"
  [[ -f "$lib" ]] || return 0
  # shellcheck disable=SC1090
  source "$lib"

  local sandbox_root="${SANDBOX_ROOT:-/home/agentuser}"
  local sandbox_name="${SANDBOX_DIR_NAME:-sandbox}"
  local state_file="$sandbox_root/$sandbox_name/.git/SESSION_STATE"

  # Guard the read: a missing record file would abort under the entrypoint's
  # `set -euo pipefail` (the while-read redirection failure is a command
  # failure). A missing record means the sandbox did not initialize (or predates
  # the record) -- warn, never hard-abort the entrypoint on an unavailable check.
  if [[ ! -f "$state_file" ]]; then
    echo "WARN: container contract: no SESSION_STATE at $state_file" >&2
    echo "  (cannot compare container to container; the sandbox record is missing)" >&2
    return 0
  fi

  local agent_baked sandbox_recorded
  agent_baked="$(interface_contract_version)"
  sandbox_recorded="$(record_contract_version "$state_file")"

  if [[ -z "$sandbox_recorded" ]]; then
    echo "WARN: container contract: sandbox has no interface_contract_version in $state_file" >&2
    echo "  (image predates the interface-contract check; cannot compare container to container)" >&2
    return 0
  fi

  if [[ "$agent_baked" != "$sandbox_recorded" ]]; then
    local msg="container contract mismatch: agent baked version $agent_baked, sandbox recorded $sandbox_recorded"
    if [[ "$(interface_contract_strict)" == "1" ]]; then
      echo "FATAL: $msg" >&2
      echo "  The agent and sandbox images were built from different contract revisions (orchestration error)." >&2
      echo "  Rebuild both images from the same source, then restore the session from its record." >&2
      exit 1
    fi
    echo "WARN: $msg" >&2
    echo "  (parallel phase: rebuild both images from the same source to align)" >&2
  fi
}

_check_container_contract

# ---------------------------------------------------------------------------
# Preflight: generic AGENT_HOME validation
# ---------------------------------------------------------------------------
# AGENT_HOME is created by _provision_agent_home when the image template is
# present. If the template existed but AGENT_HOME is still missing, something
# went wrong during provisioning and the image is unusable.
#
# In test environments (no /opt/workflow/agent/config), the provision step
# is skipped by the guard above, so we don't FATAL  --  the test framework
# handles setup separately.
if [[ -d "/opt/workflow/agent/config" && ! -d "$AGENT_HOME" ]]; then
  echo "FATAL: $AGENT_HOME missing  --  provisioning failed" >&2
  exit 1
fi
if [[ -d "$AGENT_HOME" && ! -w "$AGENT_HOME" ]]; then
  echo "FATAL: $AGENT_HOME is not writable" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Preflight: source provider-specific checks
# ---------------------------------------------------------------------------
# Provider-specific pre-flight scripts are baked into the image from
# src/reasoning/providers/<n>/preflight.sh into /opt/sandbox/bin/provider-preflight.sh.
# If the provider has no preflight
# script, this file does not exist and the hook is a no-op.
#
# Provider-specific responsibilities (e.g. for Pi):
#   - Verify provider-specific AGENTS.md path
#   - Merge harness-owned settings.json keys (skills, prompts, packages)
#   - Add custom warnings or validation

_provider_preflight="/opt/sandbox/bin/provider-preflight.sh"
if [[ -f "$_provider_preflight" ]]; then
  # Container-provided path, validated above; not statically followable.
  # shellcheck disable=SC1090
  source "$_provider_preflight"
fi
unset _provider_preflight

# ---------------------------------------------------------------------------
# Preflight: validate the first command argument
# ---------------------------------------------------------------------------
# The first argument is the first token of the container `command:` (or the
# image CMD default): the provider's agent binary in standard/serve mode, or
# `bash` when a dry-run probe script is the command. If it is missing or not
# executable the image is misconfigured.

if [[ $# -eq 0 ]]; then
  echo "FATAL: No agent command specified  --  image misconfigured" >&2
  exit 1
fi

_agent_cmd="$1"
if ! command -v "$_agent_cmd" >/dev/null 2>&1; then
  echo "FATAL: Agent command not found: $_agent_cmd  --  image may be stale" >&2
  exit 1
fi
unset _agent_cmd

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

# Run the command as a synchronous foreground child. stdin, stdout, and stderr
# are inherited from the shell; the process is in the shell's process group
# (terminal foreground group). The command (agent binary or dry-run probe)
# therefore replaces the wrapper as the container's main process.
set +e
"$@"
EXIT_CODE=$?
set -e

exit "$EXIT_CODE"
