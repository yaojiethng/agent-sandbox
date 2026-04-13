#!/usr/bin/env bash
# libs/provider-entrypoint.sh
# Harness-owned wrapper entrypoint for all reasoning layer provider containers.
# Copied into the image via the build context — a change to this file triggers
# a Docker layer cache miss on the COPY step in provider.Dockerfile.
#
# Responsibilities:
#   1. Copy provider config from PROVIDER_CONFIG_DIR (bind-mounted from the host)
#      into AGENT_HOME before the agent starts.
#   2. Run the provider's real entrypoint as a synchronous foreground child so
#      that TUI input works correctly.
#   3. After the agent exits, copy AGENT_HOME back to PROVIDER_CONFIG_DIR.
#
# Required environment variables (set via ENV in provider.Dockerfile):
#   AGENT_HOME          — provider config dir inside the container
#   PROVIDER_NAME       — provider identifier
#   PROVIDER_CONFIG_DIR — bind-mount path for host-side provider config
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
# paths (user quits TUI, agent exits cleanly), copy-out runs as expected.
# If copy-out on docker stop is required, implement it at the harness level:
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
_require_var PROVIDER_CONFIG_DIR

# ---------------------------------------------------------------------------
# Copy-in
# ---------------------------------------------------------------------------
# Copy provider config from the host bind-mount into AGENT_HOME before the
# agent starts. Skipped silently if the source is absent or empty.

_copy_in() {
  if [[ -d "$PROVIDER_CONFIG_DIR" ]] && [[ -n "$(ls -A "$PROVIDER_CONFIG_DIR" 2>/dev/null)" ]]; then
    mkdir -p "$AGENT_HOME"
    cp -r "$PROVIDER_CONFIG_DIR/." "$AGENT_HOME/"
  fi
}

# ---------------------------------------------------------------------------
# Copy-out
# ---------------------------------------------------------------------------
# Copy AGENT_HOME back to the host bind-mount after the agent exits.
# Skipped silently if AGENT_HOME is absent or empty.

_copy_out() {
  if [[ -d "$AGENT_HOME" ]] && [[ -n "$(ls -A "$AGENT_HOME" 2>/dev/null)" ]]; then
    mkdir -p "$PROVIDER_CONFIG_DIR"
    cp -r "$AGENT_HOME/." "$PROVIDER_CONFIG_DIR/"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

_copy_in

# Run the agent as a synchronous foreground child.
# stdin, stdout, and stderr are inherited from the shell (PTY in Docker).
# The agent is in the shell's process group = terminal foreground group.
set +e
"$@"
EXIT_CODE=$?
set -e

_copy_out

exit "$EXIT_CODE"
