# Agent Handover

**Date:** 2026-05-22
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Study
**Status:** Closed

## Objective

Investigate and document two bugs discovered in this session: the `_ensure_harness_keys` off-by-one path bug that prevents skills/prompts from being seeded into the runtime settings.json, and the `.pi/agent/bin` tmpfs mount shadowing and its noexec side effect.

## Scope

1. Diagnose the root cause of the missing `skills` and `prompts` keys in the runtime `~/.pi/agent/settings.json` — trace through the template file, the Docker build, the bind mount, and the `_ensure_harness_keys` merge function.
2. Verify whether the `.pi/agent/bin` tmpfs mount shadowing is still active and whether it introduces a noexec problem that breaks pi's binary downloads.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | Root cause of missing skills/prompts keys identified and documented | Handover records the bug, affected code, and fix | ✅ Accepted |
| 2 | `.pi/agent/bin` mount shadowing verified as active or regressed | `mount` confirms tmpfs at `bin/` | ✅ Accepted |
| 3 | Both findings categorised | Handover records categories | ✅ Accepted |
| 4 | AGENTS.md check warns when Pi AGENTS.md is missing | `test_warn_on_missing_agents_md` passes | ✅ Accepted |
| 5 | `_ensure_harness_keys` injects skills/prompts/packages | `test_merge_adds_harness_keys` passes | ✅ Accepted |
| 6 | `_ensure_harness_keys` preserves existing user keys | `test_merge_preserves_existing_keys` passes | ✅ Accepted |
| 7 | `_ensure_harness_keys` deduplicates paths | `test_merge_deduplicates_paths` passes | ✅ Accepted |
| 8 | Warns when settings.json not found | `test_warn_on_missing_settings` passes | ✅ Accepted |
| 9 | Shared entrypoint contains no Pi-specific logic | `grep` → 0 matches | ✅ Accepted |
| 10 | Shared entrypoint sources provider preflight script if present | `grep` → match | ✅ Accepted |
| 11 | Pi Dockerfile COPIEs preflight into image | `grep` → match | ✅ Accepted |
| 12 | `containers.sh` stages preflight from providers' `preflight.sh` | `grep` → conditional cp | ✅ Accepted |
| 13 | All tests pass | Both test suites pass (5 + 8 = 13 tests) | ✅ Accepted |
| 14 | Knowledge test renamed | Old file gone, new file present | ✅ Accepted |
| 15 | Architecture documents in scope describe the system as built | Operator reviewed diff | Operator |

## Hot files

| File | Why in scope |
|---|---|
| [`libs/provider-entrypoint.sh`](../../libs/provider-entrypoint.sh) | Refactored — generic entrypoint with pre-flight hook |
| [`providers/pi/preflight.sh`](../../providers/pi/preflight.sh) | **New** — Pi-specific pre-flight: AGENTS.md check, `_ensure_harness_keys` merge |
| [`providers/pi/provider.Dockerfile`](../../providers/pi/provider.Dockerfile) | Updated — COPY for preflight script |
| [`libs/containers.sh`](../../libs/containers.sh) | Updated — conditional preflight staging in `build_context_agent` |
| [`tests/test_providers_pi_preflight.sh`](../../tests/test_providers_pi_preflight.sh) | **New** — unit tests for Pi preflight |
| [`tests/test_provider_entrypoint.sh`](../../tests/test_provider_entrypoint.sh) | Updated — removed merge tests (moved to preflight test) |
| [`tests/knowledge/knowledge_pi_config_cycle.sh`](../../tests/knowledge/knowledge_pi_config_cycle.sh) | Renamed from `knowledge_provider_config_cycle.sh` |

## Decisions made this session

None.

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| `_ensure_harness_keys` looks at `$AGENT_HOME/settings.json` but the file is at `$AGENT_HOME/agent/settings.json` — merge silently skipped | bug | All providers — skills/prompts/packages keys never seeded into runtime settings.json |
| Same off-by-one in AGENTS.md preflight check (line 105) — `$AGENT_HOME/AGENTS.md` not found, produces misleading WARN | bug | Non-fatal but produces confusing startup log |
| `.pi/agent/bin` tmpfs mount is active and shadows the bind mount's bin/ | verification | Current behaviour confirmed |
| tmpfs has `noexec` — `fd` and `rg` binaries present but cannot execute (Permission denied) | confirmed behavior — pi handles gracefully. tmpfs prevents cross-device mv errors (intended purpose). noexec prevents execution from bin/ but pi falls back to system grep/find. [see correction below] | No functional impact — resolved |
| Operator context-steering bypasses minor loop gates (Gate 1 / Gate 2), causing scope confirmation and AC definition to be skipped. Agent did not enforce the workflow or signal the skip. | workflow gap | Next session / future workflow — would benefit from guardrails or a recovery process |

## Completed this session

| File | Change |
|---|---|
| [`libs/provider-entrypoint.sh`](../../libs/provider-entrypoint.sh) | Refactored: removed Pi-specific logic (AGENTS.md branch, `_ensure_harness_keys`); added generic pre-flight hook that sources `/opt/sandbox/bin/provider-preflight.sh` if present; updated header comments |
| [`providers/pi/preflight.sh`](../../providers/pi/preflight.sh) | **New** — Pi-specific pre-flight: AGENTS.md check at `$AGENT_HOME/agent/AGENTS.md`, `_ensure_harness_keys` merge with warn-on-skip and verify-after-merge |
| [`providers/pi/provider.Dockerfile`](../../providers/pi/provider.Dockerfile) | Added `COPY provider-preflight.sh /opt/sandbox/bin/provider-preflight.sh` |
| [`libs/containers.sh`](../../libs/containers.sh) | Added conditional staging of `providers/<n>/preflight.sh` → `$context_dir/provider-preflight.sh` in `build_context_agent` |
| [`tests/test_providers_pi_preflight.sh`](../../tests/test_providers_pi_preflight.sh) | **New** — 6 unit tests for Pi preflight: merge adds keys, preserves keys, deduplicates paths, warns on missing settings, warns on missing AGENTS.md, merge resilient to missing AGENTS.md |
| [`tests/test_provider_entrypoint.sh`](../../tests/test_provider_entrypoint.sh) | Removed merge tests (moved to preflight test); kept env var, exit code, stdin tests |
| [`tests/knowledge/knowledge_pi_config_cycle.sh`](../../tests/knowledge/knowledge_pi_config_cycle.sh) | Renamed from `knowledge_provider_config_cycle.sh`; updated header to reflect Pi-specific scope and historical note |

## Deferred items

| Item | Reason | Goes to |
|---|---|---|
| tmpfs noexec verification — test in fresh container after clearing `bin/` | Confirmed: noexec is real but pi handles gracefully (fallback to system tools). No action needed. [see correction below] | Resolved — no fix required |
| Workflow bypass guardrails / recovery process — exploration of how to prevent or recover from operator context-steering that skips minor loop gates | Need design, not implement | Future workflow / roadmap item |
| Generic pre-flight validation (Proposal 3) — validate AGENT_HOME bind mount, critical file presence | Not started; lower priority | M2.7 remaining tasks |
| Cross-filesystem mount issue — Pi's settings-manager uses `proper-lockfile` → `utime()` → EPERM on 9p mounts (macOS/Windows Docker Desktop). Causes `settings.json` to silently fall back to defaults, stripping harness-injected `skills`/`prompts` keys. Nullifies the `_ensure_harness_keys` fix. | Confirmed — affects all host OSes using non-Linux-native bind mounts. Needs mount strategy redesign. | Next major loop — revisit `.pi/agent/` mounting strategy |

## Next session

**Major loop required before next session.** The cross-filesystem mount issue (utime/EPERM on 9p mounts) nullifies the `_ensure_harness_keys` fix. The `.pi/agent/` mount strategy needs to be redesigned before skills/prompts mounting can work reliably across host OSes.

**Trigger B:** Not run — M2.7 has many remaining tasks (Track A container identity, Track B staleness detection, dual-layer seam testing, autosave, etc.).

**Blocking design question:** How should the `.pi/agent/` directory be mounted to avoid the utime/EPERM problem? See deferred items.
- The `agent/` subdirectory path convention remains Pi-specific; any new provider must account for this in their own preflight.sh

**Conclusions from this session:**

### Finding 1: `_ensure_harness_keys` off-by-one path bug

**Root cause:** Line 119 of `libs/provider-entrypoint.sh` references `$AGENT_HOME/settings.json` but the compose template bind-mounts `${SANDBOX_DIR}/.{{PROVIDER_NAME}}/agent` → `/home/agentuser/.pi/agent`. The entire runtime config lives under `$AGENT_HOME/agent/`, not at `$AGENT_HOME`. The actual path is `$AGENT_HOME/agent/settings.json`. The same error exists at line 105 for the AGENTS.md preflight check.

**Category:** Bug (regression). Introduced in session 20260513-10 (M2.7 — settings.json collision fix with Node.js pre-flight script). Went undetected because `[[ -f "$settings" ]]` makes failure silent — no error, no warning.

**Fix required:**
- Line 105: `$AGENT_HOME/AGENTS.md` → `$AGENT_HOME/agent/AGENTS.md`
- Line 119: `$AGENT_HOME/settings.json` → `$AGENT_HOME/agent/settings.json`

### Shared Reasoning Layer Audit

Audited all shared libraries (copied into every provider image) for Pi-specific logic:

| File | Verdict | Notes |
|---|---|---|
| `libs/provider-entrypoint.sh` | **Pi-specific** (now fixed) | `_ensure_harness_keys` gated behind `PROVIDER_NAME == pi`; AGENTS.md path is provider-aware |
| `libs/session.sh` | Clean | No Pi references |
| `libs/dirs.sh` | Clean | No Pi references |
| `libs/routing.sh` | Clean | No Pi references |
| `libs/package_diff.sh` | Clean | No Pi references |
| `libs/package_branch.sh` | Clean | No Pi references |

**Compose template** — has two hardcoded Pi paths that are not templated:
  - Line 102: `target: /home/agentuser/.pi/agent` (bind mount target)
  - Line 106: `target: /home/agentuser/.pi/agent/bin` (tmpfs mount target)
  These are broken for non-Pi providers; they will only mount at the Pi path regardless of `{{PROVIDER_NAME}}` in the source.

**Provider Dockerfiles** — structurally identical across all 4 providers for the shared libs + agent file COPY commands. All bake `/opt/workflow/agent/skills/` and `/opt/workflow/agent/prompts/` into the image, even though only Pi consumes them.

**build_context_agent** in `containers.sh` — stages `agent/skills/` and `agent/prompts/` for ALL providers via `cp -r` at lines 113-114. This is why `/opt/workflow/agent/` ends up in every image.

### Pre-flight Hook Design (implemented)

**Hook mechanism:** Shared entrypoint sources `/opt/sandbox/bin/provider-preflight.sh` if present (fixed name).

The shared entrypoint sources the file if it exists:

```bash
_provider_preflight="/opt/sandbox/bin/provider-preflight.sh"
if [[ -f "$_provider_preflight" ]]; then
  source "$_provider_preflight"
fi
unset _provider_preflight
```

Each provider supplies their own via the build context:
- `providers/pi/preflight.sh` → staged as `provider-preflight.sh` → Pi-specific validation
- Providers without a preflight script don't have the file in their build context, so the hook no-ops

The pre-flight hook script is staged by `build_context_agent` in `containers.sh`, alongside the other shared libs.

Pi's preflight (`providers/pi/preflight.sh`) includes:
- Pi-specific AGENTS.md check at `$AGENT_HOME/agent/AGENTS.md`
- `_ensure_harness_keys` merge with warn-on-skip and verify-after-merge

### One remaining subtask

Generic pre-flight validation (Proposal 3) — validate AGENT_HOME bind mount, critical file presence — was not started. Remaining in the roadmap.

### Knowledge Test Rename

The existing test at `tests/knowledge/knowledge_provider_config_cycle.sh` tests Pi-specific config behavior (settings.json merge, agent/ subdir paths). It should be renamed to `tests/knowledge/knowledge_pi_config_cycle.sh` to reflect that it is Pi-specific, not a generic provider test.

### Finding 2: `.pi/agent/bin` tmpfs mount shadowing

**Status:** Active and working. The compose template at `libs/docker-compose.yml` lines 103–106 defines a tmpfs mount at `/home/agentuser/.pi/agent/bin` that overlays the bind mount's `bin/` subdirectory. Verified via `mount` and `/proc/mounts`.

**Side effect:** The tmpfs is mounted with `noexec` (Docker default for tmpfs). Binaries downloaded by pi (`fd`, `rg`) land in the tmpfs but cannot execute from that path. [see correction below]

**Status:** Resolved — no fix required. The tmpfs achieves its intended purpose (preventing cross-device mv errors on download). The noexec side effect exists but pi handles it gracefully by falling back to system `grep`/`find` when `bin/` binaries can't execute. No action needed.

---
[CORRECTION — 2026-05-22]: The tmpfs noexec finding was labelled "potential bug" with "Deferred — test in fresh container". Operator tested: after removing pre-seeded binaries, pi re-downloads them successfully (tmpfs prevents cross-device mv, which is its purpose) and falls back to system tools gracefully. No functional impact. Finding reclassified as "confirmed behavior — no action required." Inline edits marked [see correction below]. Updated mid-session findings table, deferred items, and Finding 2 conclusions section.
