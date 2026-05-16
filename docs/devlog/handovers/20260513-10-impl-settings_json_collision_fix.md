# Agent Handover

**Session date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Implement the settings.json ownership collision fix (M2.7 item 8): replace the copy-in/copy-out mechanism in `libs/provider-entrypoint.sh` with a pre-flight Node.js merge script, update the compose template mount paths (now slots into the `x-workspace` anchor from item 10), and seed `~/.pi/agent/AGENTS.md` alongside the other config files.

## Scope

M2.7 item 8 — Settings.json ownership collision fix, as designed in `docs/devlog/discussions/design_provider_config_ownership_and_loading.md`.

- Replace `/opt/provider-config` bind mount with `agent/` directory bind mount, `bin/` tmpfs, and `/opt/workflow-host/` mounts for skills/prompts.
- Remove `_copy_in` and `_copy_out` from `libs/provider-entrypoint.sh`; add `_ensure_harness_keys` (Node.js pre-flight merge).
- Pre-create `agent/sessions` in `scripts/run_agent.sh` before compose generation.
- Seed `AGENTS.md` into provider config so pi's append-composition gets the global layer.
- Also covers: provider dry-run checks hook point (from item 12 investigation — deferred, but the config dir changes make it easier to add later).

## Carried forward

| Item | From handover |
|---|---|
| Seed `~/.pi/agent/AGENTS.md` into provider config dir | 20260513-08-impl-agents_injection_cleanup — deferred to item 8 |
| Provider dry-run checks mechanism | 20260513-08-impl-agents_injection_cleanup — deferred to item 8 |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Compose template has AGENT_HOME directory bind mount + bin/ tmpfs replacing provider-config mount | ✅ |
| 2 | provider-entrypoint.sh has no _copy_in/_copy_out | ✅ |
| 3 | provider-entrypoint.sh has _ensure_harness_keys Node.js merge that preserves pi keys and adds harness keys | ✅ |
| 4 | settings.json retains pi-managed keys after merge | ✅ (tested) |
| 5 | All provider Dockerfiles have PROVIDER_CONFIG_DIR removed | ✅ |
| 6 | run_agent.sh pre-creates agent/sessions | ✅ |
| 7 | AGENTS.md updated in provider config | ✅ |
| 8 | bash -n passes on all modified files | ✅ |
| 9 | make test passes clean | ✅ |
| 10 | Architecture documents describe the system as built | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `libs/provider-entrypoint.sh` | Remove copy-in/copy-out, add Node.js merge |
| `libs/docker-compose.yml` | Update provider config mount to use `x-workspace` anchor |
| `libs/docker-compose.dry-run.yml` | May need updates for new mount layout |
| `scripts/run_agent.sh` | Pre-create agent/sessions directory |
| `providers/pi/config/agent/settings.json` | Add packages/skills/prompts keys |
| `providers/pi/config/agent/AGENTS.md` | **New** — pi-specific global context |
| `providers/pi/provider.Dockerfile` | Verify no COPY of agent/skills/ or agent/prompts/ |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `libs/docker-compose.yml` | Replaced provider-config mount with AGENT_HOME dir mount + bin/ tmpfs |
| `libs/provider-entrypoint.sh` | Removed copy-in/copy-out, added _ensure_harness_keys |
| `providers/pi/provider.Dockerfile` | Removed PROVIDER_CONFIG_DIR ENV and /opt/provider-config mkdir |
| `providers/claude-code/provider.Dockerfile` | Same |
| `providers/hermes/provider.Dockerfile` | Same |
| `providers/opencode/provider.Dockerfile` | Same |
| `providers/pi/config/agent/AGENTS.md` | Updated with current harness behavior |
| `scripts/run_agent.sh` | Pre-create agent/sessions |
| `scripts/dry_run.sh` | Removed PROVIDER_CONFIG_DIR check |
| `tests/test_provider_entrypoint.sh` | Replaced copy-in/copy-out tests with _ensure_harness_keys tests |

## Deferred items

None.

## Next session

M2.7 items 1–7 (run_id derivation, Docker labels, stop redesign, prune, two-sig model, paired refactor, context_dir removal) are the remaining scope. Item 8, 9, 10, 11, 12 are complete.
