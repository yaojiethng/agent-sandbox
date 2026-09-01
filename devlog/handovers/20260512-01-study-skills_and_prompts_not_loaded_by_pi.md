# Agent Handover

**Date:** 2026-05-12
**Milestone:** M2.5 — Vault Capability Layer Prototype
**Type:** Study
**Status:** Closed

## Objective

Investigate why pi (the coding agent) does not have the skills and prompts loaded from the paths referenced in its settings.json — specifically `/opt/workflow/agent/skills` and `/opt/workflow/agent/prompts` — and determine root cause. Document findings, re-seed the config, and persist diagnostics.

## Scope

- Trace the full config copy-in/copy-out cycle
- Identify root cause of missing skills/prompts
- Re-seed settings.json with correct credentials
- Write knowledge test and documentation

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Root cause identified: copy-out/copy-in cycle stripped custom `skills`/`prompts` keys from settings.json | ✅ |
| 2 | settings.json re-seeded in bind-mount and AGENT_HOME with runtime defaults preserved | ✅ |
| 3 | Skills/prompts confirmed loading after container restart | ✅ |
| 4 | Knowledge test `tests/knowledge/knowledge_provider_config_cycle.sh` exists and passes | ✅ |
| 5 | Config flow diagram and fragility notes added to `docs/architecture/provider_lifecycle.md` | ✅ |
| 6 | Three-layer skills/prompts model documented in `docs/concepts/agent_workflow.md` | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `providers/pi/config/agent/settings.json` | Onboard source template with correct `skills`/`prompts` keys |
| `/opt/provider-config/agent/settings.json` | Bind-mount copy — was stripped, re-seeded this session |
| `~/.pi/agent/settings.json` | AGENT_HOME copy — was stripped, re-seeded this session |
| `libs/provider-entrypoint.sh` | Copy-in/copy-out mechanism (`_copy_in`, `_copy_out`) |
| `tests/knowledge/knowledge_provider_config_cycle.sh` | **New** — knowledge test for config cycle |
| `docs/architecture/provider_lifecycle.md` | Added `## Config Flow and Fragility Notes` section |
| `docs/concepts/agent_workflow.md` | Added `### Skills and Prompts Layer Model` subsection |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Re-seed with runtime defaults + add only `skills`/`prompts` keys | Full onboard template (v0.67.6) would overwrite runtime-settled values (v0.70.6) for `defaultModel`, `defaultThinkingLevel`, `compaction`, `packages` etc. | This handover |
| Document three-layer model in `agent_workflow.md` not `provider_lifecycle.md` | The three-layer model is a conceptual model (skills/prompts loading), not a lifecycle mechanism. Correct document per folder ownership. | This handover |
| Fragility notes go in `provider_lifecycle.md` | The config cycle is a lifecycle mechanism; fragility stems from how the cycle interacts with pi's settings write behaviour. | This handover |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| **Container restart dropped prior session's handover** | procedural | This handover was written in a prior container session that was not persisted to snapshot. Re-created from investigation notes. This finding documents that handovers written in one container session may be lost if the container restarts without saving. |
| **`build_context_agent` also copies `agent/skills/` and `agent/prompts/` even though they are now config-seeded** | structural | The copy in `build_context_agent()` feeds the Docker COPY instruction that bakes files into the image at `/opt/workflow/`. The config seeding copies the same files into `SANDBOX_DIR/.pi/agent/`. This creates two code paths for the same files — the image-baked path is the primary sandbox-layer mechanism; the config-seeded path is the user/operator layer. They are independent by design but the dual-maintenance surface is noted. |

## Completed this session

| File | Change |
|---|---|
| `/opt/provider-config/agent/settings.json` | Re-seeded from runtime defaults + added `"skills"` and `"prompts"` keys |
| `~/.pi/agent/settings.json` | Same re-seed (AGENT_HOME) |
| `tests/knowledge/knowledge_provider_config_cycle.sh` | **New** — 4 tests covering copy-in, copy-out, round-trip, and real-system inspection |
| `docs/architecture/provider_lifecycle.md` | Added `## Config Flow and Fragility Notes` with ASCII config flow diagram, ownership collision analysis, fragility summary table, three-layer interaction notes |
| `docs/concepts/agent_workflow.md` | Added `### Skills and Prompts Layer Model` with layer table, rationale for image-baking, and dependency on settings.json keys |
| `docs/devlog/handovers/20260512-01-study-skills_and_prompts_not_loaded_by_pi.md` | **New** — this handover |

## Deferred items

| Item | From handover | Status |
|---|---|---|
| Long-term fix: protect custom settings keys from copy-out stripping | This handover | Deferred — root cause identified, two potential approaches: (1) merge instead of replace on copy-in, (2) split agent-sandbox-owned config into separate file |

## Next session

### Milestone transition

This investigation session is complete. The next session should enter at **design** — evaluate fix approaches and produce a design proposal before implementing.

### Known constraints for the design

1. **Image-baking is intentional, not accidental.** The `build_context_agent()` → `provider.Dockerfile COPY` chain that bakes `agent/skills/` and `agent/prompts/` into the image at `/opt/workflow/` MUST NOT be removed. It provides a stable baseline independent of the working tree. The fragility is in the settings.json path bridge, not in the image-baking.

2. **Pi's settings write behaviour is partially characterised.** The runtime settings.json was stripped to 4 keys (143 bytes). Whether pi actively drops unrecognised keys or whether the seed never included them is not fully resolved. The knowledge test (`tests/knowledge/knowledge_provider_config_cycle.sh`) documents a manual verification procedure for this — running it would determine whether pi preserves `"skills"` and `"prompts"` when they are present at session start and pi subsequently saves. This matters for choosing between fix approaches: if pi preserves them, merge-on-copy-in (Approach A) is viable. If pi strips them, split-config (Approach B) is safer.

3. **The knowledge test is the verification tool.** Run `bash tests/knowledge/knowledge_provider_config_cycle.sh` to verify any fix. Its Test 4 (`test_real_config_state`) inspects all three config locations and flags drift between onboard source and bind-mount.

### Blocking questions
- Which approach to design for?
  1. **Merge on copy-in (Approach A):** before replacing AGENT_HOME, merge the bind-mount's settings.json with the onboard seed, favouring runtime values for pi-managed keys and seed values for agent-sandbox-managed keys
  2. **Split config (Approach B):** keep agent-sandbox-owned settings (skills/prompts paths) in a separate file that pi doesn't manage, and have pi load both
- Does the operator want to first run the manual verification from the knowledge test to determine which approach is viable?

### Remaining work
- Design and implement a long-term fix for the settings.json ownership collision
- Two approaches to evaluate:
  1. **Merge on copy-in:** before replacing AGENT_HOME, merge the bind-mount's settings.json with the onboard seed, favouring runtime values for pi-managed keys and seed values for agent-sandbox-managed keys
  2. **Split config:** keep agent-sandbox-owned settings (skills/prompts paths) in a separate file that pi doesn't manage, and have pi load both

### Watch-out items
- The `build_context_agent` function in `libs/containers.sh` copies `agent/skills/` and `agent/prompts/` into the build context. These then get `COPY`'d into the image by `provider.Dockerfile`. This is the intended sandbox-layer image-baking mechanism — it should NOT be removed when designing the long-term fix. The fragility is in the settings.json path bridge, not in the image-baking.
