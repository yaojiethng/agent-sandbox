#!/usr/bin/env bash
# libs/provider-entrypoint.sh
# Harness-owned wrapper entrypoint for all reasoning layer provider containers.
# Copied into the image via the build context — a change to this file triggers
# a Docker layer cache miss on the COPY step in provider.Dockerfile.
#
# Responsibilities:
#   1. Run generic pre-flight checks (env vars, container libs).
#   2. Source provider-specific pre-flight script if present
#      (/opt/sandbox/bin/provider-preflight.sh).
#   3. Run the provider's real entrypoint as a synchronous foreground child so
#      that TUI input works correctly.
#
# Provider-specific logic (settings.json merge, path overrides, custom checks)
# belongs in providers/<n>/preflight.sh, staged as provider-preflight.sh in
# the build context. The shared entrypoint stays generic.
#
# The config directory ($AGENT_HOME) is bind-mounted directly — no copy-in or
# copy-out needed. See docs/devlog/discussions/design_provider_config_ownership_and_loading.md
# for the design rationale.
#
# Required environment variables (set via ENV in provider.Dockerfile):
#   AGENT_HOME          — provider config dir inside the container
#   PROVIDER_NAME       — provider identifier
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
# paths (user quits TUI, agent exits cleanly), state is preserved because the
# config directory is bind-mounted directly — no copy-out needed.
# If cleanup on docker stop is required, implement it at the harness level:
# run_agent.sh can copy provider config out via "docker cp" after the container
# exits, independent of the entrypoint.

set -euo pipefail

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
# Preflight: verify container libs
# ---------------------------------------------------------------------------
# /opt/sandbox/lib/ is baked into the image at build time. If files are
# missing, the image is stale and must be rebuilt with `make build`.
#
# session.sh is CRITICAL — sourced unconditionally by dry_run_reasoning.sh.
# The remaining files are WARN — fine to start but certain diagnostics or
# session operations will fail at runtime.
LIB_DIR="/opt/sandbox/lib"
for entry in "session.sh:CRITICAL" "dirs.sh:WARN" "routing.sh:WARN" \
             "package_diff.sh:WARN"; do
  lib="${entry%%:*}"
  severity="${entry##*:}"
  if [[ ! -f "$LIB_DIR/$lib" ]]; then
    if [[ "$severity" == "CRITICAL" ]]; then
      echo "FATAL: $LIB_DIR/$lib is missing — image is stale, rebuild with 'make build'" >&2
      exit 1
    else
      echo "WARN: $LIB_DIR/$lib is missing — image may be stale" >&2
    fi
  fi
done
unset LIB_DIR

# ---------------------------------------------------------------------------
# Preflight: source provider-specific checks
# ---------------------------------------------------------------------------
# Provider-specific pre-flight scripts are staged by build_context_agent
# from providers/<n>/preflight.sh and baked into the image at
# /opt/sandbox/bin/provider-preflight.sh. If the provider has no preflight
# script, this file does not exist and the hook is a no-op.
#
# Provider-specific responsibilities (e.g. for Pi):
#   - Verify provider-specific AGENTS.md path
#   - Merge harness-owned settings.json keys (skills, prompts, packages)
#   - Add custom warnings or validation

_provider_preflight="/opt/sandbox/bin/provider-preflight.sh"
if [[ -f "$_provider_preflight" ]]; then
  source "$_provider_preflight"
fi
unset _provider_preflight

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

# Run the agent as a synchronous foreground child.
# stdin, stdout, and stderr are inherited from the shell (PTY in Docker).
# The agent is in the shell's process group = terminal foreground group.
set +e
"$@"
EXIT_CODE=$?
set -e

exit "$EXIT_CODE"
