#!/usr/bin/env bash
# providers/pi/preflight.sh
# Pi-specific pre-flight checks, sourced by provider-entrypoint.sh at startup.
#
# Responsibilities:
#   1. Verify Pi-specific AGENTS.md location ($AGENT_HOME/agent/AGENTS.md)
#   2. Merge harness-owned settings.json keys (skills, prompts, packages) so
#      they survive pi's runtime writes
#
# This script is sourced from /opt/sandbox/bin/provider-preflight.sh by the
# shared entrypoint. If this file is absent, the hook is a no-op.
#
# Pi-specific conventions:
#   - Config lives under $AGENT_HOME/agent/ (agent/ subdirectory)
#   - settings.json references /opt/workflow/agent/ (sandbox-layer workflow files)
#   - /opt/workflow/agent/ is baked into all provider images at build time

# ---------------------------------------------------------------------------
# AGENTS.md check (Pi-specific path)
# ---------------------------------------------------------------------------

_preflight_check_agents_md() {
  local agents_md="$AGENT_HOME/agent/AGENTS.md"
  if [[ ! -f "$agents_md" ]]; then
    echo "WARN: $agents_md is missing — Pi context not available to agent" >&2
  fi
}

# ---------------------------------------------------------------------------
# Harness key merge
# ---------------------------------------------------------------------------
# Ensures harness-owned settings.json keys survive pi's runtime writes.
# Pi only writes keys it manages; this merge re-injects harness-owned keys
# (skills, prompts, packages paths) without touching pi-managed keys.

_ensure_harness_keys() {
  local settings="$AGENT_HOME/agent/settings.json"
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
    # Verify merge took effect
    if ! grep -q '"skills"' "$settings" 2>/dev/null; then
      echo "WARN: Pi harness keys (skills/prompts/packages) missing after merge" >&2
    fi
  else
    echo "WARN: $settings not found — Pi harness keys not injected" >&2
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

_preflight_check_agents_md
_ensure_harness_keys
