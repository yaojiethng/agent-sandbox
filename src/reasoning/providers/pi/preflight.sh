#!/usr/bin/env bash
# providers/pi/preflight.sh
# Pi-specific pre-flight checks, sourced by provider-entrypoint.sh at startup.
#
# Responsibilities:
#   1. Verify Pi-specific AGENTS.md location ($AGENT_HOME/agent/AGENTS.md)
#   2. Merge harness-owned settings.json keys (skills, prompts, packages) so
#      they survive pi's runtime writes
#   3. Reset models-store.json freshness so pi revalidates the catalog at
#      first refresh instead of serving a build-time-frozen overlay
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
    echo "WARN: $agents_md is missing  --  Pi context not available to agent" >&2
  fi
}

# ---------------------------------------------------------------------------
# Bind-mounted subdir check
# ---------------------------------------------------------------------------
# Verify the selective bind mounts (prompts/, sessions/, skills/) are present
# and writable. These are Docker bind mounts from the host  --  if missing, the
# compose template may not have set them up correctly.

_preflight_check_bind_mounts() {
  local ok=true
  for d in prompts sessions skills; do
    local path="$AGENT_HOME/agent/$d"
    if [[ ! -d "$path" ]]; then
      echo "WARN: $path missing  --  bind mount may not be configured" >&2
      ok=false
    elif [[ ! -w "$path" ]]; then
      echo "WARN: $path not writable" >&2
      ok=false
    fi
  done
  if ! $ok; then
    echo "WARN: Some bind-mounted directories are missing or not writable  -- " >&2
    echo "WARN: session history and provider prompts/skills may not persist" >&2
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
    echo "WARN: $settings not found  --  Pi harness keys not injected" >&2
  fi
}

# ---------------------------------------------------------------------------
# Models-store freshness reset
# ---------------------------------------------------------------------------
# models-store.json is baked into the image by the build-time
# `RUN pi install` step (which refreshes model catalogs as agentuser).
# Pi skips the network for a store entry while `now - checkedAt < 4h`
# (REMOTE_CATALOG_REFRESH_INTERVAL_MS in pi's remote-catalog-provider.js),
# so an old image serves a stale catalog even after the /model refresh.
# Setting checkedAt to 0 on every entry forces a conditional revalidation
# (etag) at the first refresh while keeping the baked catalog as the
# offline fallback. etag and lastModified are kept so a 304 cannot leave
# the overlay empty.

_reset_models_store_freshness() {
  local store="$AGENT_HOME/agent/models-store.json"
  [[ -f "$store" ]] || return 0
  node -e "
    const fs = require('fs');
    const p = process.argv[1];
    let d;
    try { d = JSON.parse(fs.readFileSync(p, 'utf8')); } catch(e) {
      console.error('WARN: models-store.json is not valid JSON -- freshness not reset');
      process.exit(0);
    }
    let n = 0;
    for (const k of Object.keys(d)) {
      if (d[k] && typeof d[k] === 'object' && d[k].checkedAt !== undefined) {
        d[k].checkedAt = 0;
        n++;
      }
    }
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\\n');
    console.log('models-store.json: reset checkedAt on ' + n + ' provider entries');
  " "$store"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

_preflight_check_bind_mounts
_preflight_check_agents_md
_ensure_harness_keys
_reset_models_store_freshness
