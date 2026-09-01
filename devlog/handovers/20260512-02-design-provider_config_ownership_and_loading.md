# Agent Handover

**Date:** 2026-05-12
**Milestone:** M2.5 — Vault Capability Layer Prototype
**Type:** Design
**Status:** Closed

## Objective

Design a long-term fix for the settings.json ownership collision between pi and agent-sandbox, covering config sync, discovery of sandbox-layer skills/prompts, and elimination of the fragile copy-in/copy-out cycle.

## Scope

- Evaluate fix approaches (merge-on-copy-in, split-config, hybrid bind-mounts, pi packages)
- Grill through design trade-offs using improve-codebase-architecture
- Settle on a single design and document it
- No implementation — design only

## Carried forward

| Item | From handover |
|---|---|
| Long-term fix: protect custom settings keys from copy-out stripping | 20260512-01-study |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | All open questions resolved (bind-mount vs copy, N-volumes, jq, packages) | ✅ |
| 2 | Settled design documented in `docs/devlog/discussions/design_provider_config_ownership_and_loading.md` | ✅ |
| 3 | No implementation — design record only | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `docs/devlog/discussions/design_provider_config_ownership_and_loading.md` | **Updated** — settled design replaces earlier candidates; full decision record |
| `libs/docker-compose.yml` | Template — mount layout changes in scope |
| `libs/provider-entrypoint.sh` | Entrypoint — copy-in/copy-out removed, pre-flight merge added |
| `scripts/run_agent.sh` | Pre-creation of `sessions/` directory for bind mount |
| `providers/pi/config/agent/settings.json` | Path updates for `/opt/workflow-host/` + `packages` key |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| **Eliminate copy-in/copy-out entirely** | Replaced by directory bind mount + tmpfs at bin/. Simpler, no ownership collision, real-time sync for hot-reloadable files. | Design doc rule 4.1 |
| **Remove `/opt/provider-config` mount** | Config directory mounts directly at `~/.pi/agent/` — no intermediate path needed. | Design doc rule 4.1 |
| **`bin/` as tmpfs** | Shadows the directory mount to keep pi's binary downloads container-local (cross-device mv from `/tmp`). | Design doc rule 4.1 |
| **Sandbox-layer skills/prompts as RO bind mounts** | Mounted at `/opt/workflow-host/` for real-time dev iteration. Image-baked `/opt/workflow/` stays as fallback. | Design doc rule 4.1 |
| **One directory mount for config, not N individual files** | Single `agent/` dir mount covers AGENTS.md, auth.json, models.json, settings.json, sessions/, prompts/. No N-volumes. | Design doc rule 4.1 |
| **Pre-flight merge via Node.js** | Runs at session start to inject harness-owned keys into bind-mounted settings.json. Node already in base image (no jq needed). | Design doc rule 4.3 |
| **`"packages"` + `"skills"`/`"prompts"` keys both kept** | Redundant discovery paths create a real seam with two adapters. | Design doc rule 4.2 |
| **Copy-in/copy-out deletion test passes** | Delete `_copy_in`/`_copy_out` — no config persistence logic breaks. The bind mounts handle it. | Grill session finding |
| **Real-time sync for skills/prompts is necessary** | Draft/confirm workflow on host modifies skills/prompts mid-session. Copy-in/copy-out loses those changes. | Grill session finding |

## Completed this session

| File | Change |
|---|---|
| `docs/devlog/discussions/design_provider_config_ownership_and_loading.md` | **Major restructure** — replaced candidate enumeration with settled design: directory bind mount, tmpfs overlay at bin/, pre-flight merge via Node, settings.json path updates, full decision record |

## Deferred items

None.

## Next session

### Milestone transition

Design is complete. Next session enters at **implementation** — apply the settled design.

### Files to change

| File | Change | Status |
|---|---|---|
| `libs/docker-compose.yml` | Replace `/opt/provider-config` mount with `agent/` dir mount, `bin/` tmpfs, `/opt/workflow-host/` mounts for skills and prompts | pending |
| `libs/provider-entrypoint.sh` | Remove `_copy_in`, `_copy_out`. Add `_ensure_harness_keys` (Node.js merge). Keep `_require_var` + `exec` | pending |
| `scripts/run_agent.sh` | Extend `mkdir -p` to pre-create `agent/sessions` subdirectory | pending |
| `providers/pi/config/agent/settings.json` | Add `"packages": ["/opt/workflow/agent"]`, add `/opt/workflow-host/` paths to `skills`/`prompts` arrays | pending |
| `providers/pi/provider.Dockerfile` | Remove `COPY agent/skills/` and `COPY agent/prompts/` if they exist (verify first — they were moved to build_context_agent) | pending |

### Verification

After implementation, run:
1. `bash tests/knowledge/knowledge_provider_config_cycle.sh` — should pass all tests
2. Start a pi session — verify startup header shows skills and prompts loaded
3. `pi /reload` — verify skills/prompts hot-reload from bind mount
4. Modify a skill or prompt on the host, call `pi /reload` — verify changes visible

### Watch-out items
- The compose template uses `{{VAR}}` (substituted at compose generation) and `${VAR}` (resolved at runtime). The new mounts use both — `${SANDBOX_DIR}` (runtime) and `{{PROVIDER_NAME}}` (generation time). Ensure correct syntax.
- `mkdir -p` for `agent/sessions` must happen BEFORE compose generation, so Docker finds the directory as an existing bind mount source (otherwise root-owned).
- The `bin/` tmpfs must be tested: pi should download fd/rg to a container-local filesystem, not attempt cross-device mv.

---

[CORRECTION — 2026-05-22]: The bind mount approach (directory bind mount + tmpfs overlay at bin/) selected in this session was later found to fail on cross-filesystem mounts. Pi's `proper-lockfile` → `utime()` → `EPERM` on 9p/virtiofs (macOS/Windows Docker Desktop). Settings.json silently falls back to defaults, stripping harness-injected keys. Pi bump to 0.75.4 did not resolve the issue. All 4 candidate options from this session (merge-on-copy-in, split-config, hybrid bind-mounts, pi packages) were re-evaluated in session `20260522-05-design-pi_agent_mount_strategy.md`. The favoured path is option 1 (copy-in), reverting the bind mount for settings.json while keeping the pre-flight merge and other improvements.