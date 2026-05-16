#!/usr/bin/env bash
# libs/provider-entrypoint.sh
# Harness-owned wrapper entrypoint for all reasoning layer provider containers.
# Copied into the image via the build context — a change to this file triggers
# a Docker layer cache miss on the COPY step in provider.Dockerfile.
#
# Responsibilities:
#   1. Ensure harness-owned settings.json keys survive pi's runtime writes
#      (skills, prompts, packages paths) via a targeted JSON merge.
#   2. Run the provider's real entrypoint as a synchronous foreground child so
#      that TUI input works correctly.
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
# Harness key merge
# ---------------------------------------------------------------------------
# Ensures harness-owned settings.json keys survive pi's runtime writes.
# Pi only writes keys it manages; this merge re-injects harness-owned keys
# (skills, prompts, packages paths) without touching pi-managed keys.
# Runs on every session start, before the provider starts.
# Uses Node.js which is available in the base image.

_ensure_harness_keys() {
  local settings="$AGENT_HOME/settings.json"
  if [[ -f "$settings" ]]; then
    node -e "
      const fs = require('fs');
      const p = process.argv[1];
      let o;
      try { o = JSON.parse(fs.readFileSync(p, 'utf8')); } catch(e) { o = {}; }
      o.packages = [...new Set([...(o.packages||[]), '/opt/workflow/agent'])];
      o.skills = [...new Set([...(o.skills||[]), '/opt/workflow/agent/skills'])];
      o.prompts = [...new Set([...(o.prompts||[]), '/opt/workflow/agent/prompts'])];
      fs.writeFileSync(p, JSON.stringify(o, null, 2) + '\n');
    " "$settings"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

_ensure_harness_keys

# Run the agent as a synchronous foreground child.
# stdin, stdout, and stderr are inherited from the shell (PTY in Docker).
# The agent is in the shell's process group = terminal foreground group.
set +e
"$@"
EXIT_CODE=$?
set -e

exit "$EXIT_CODE"
