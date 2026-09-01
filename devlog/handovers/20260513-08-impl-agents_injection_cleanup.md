# Agent Handover

**Date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Implementation
**Status:** Closed

## Objective

Investigate the AGENTS.md injection path (M2.7 item 12): determine whether `brief.md` injection is live or dead code, whether pi receives AGENTS.md on every turn, and whether the append-composition layers are intact.

## Scope

M2.7 item 12 investigation and cleanup.

- Trace the AGENT_BRIEF → `brief.md` injection path from Makefile through `start_agent.sh` into the container.
- Verify pi's AGENTS.md discovery mechanism.
- Remove all dead code (--brief flag, AGENT_BRIEF variable, copy-to-INPUT_DIR).
- Update pre-flight checks, design doc, and roadmap.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Investigation completed: brief.md injection is dead code (pi ignores it); pi loads AGENTS.md via CWD walk; ~/.pi/agent/AGENTS.md is missing | ✅ |
| 2 | `--brief` flag removed from `start_agent.sh` flag parsing, usage, and doc comments | ✅ |
| 3 | `AGENT_BRIEF` variable and `--brief=` references removed from `Makefile.template` | ✅ |
| 4 | Pre-flight checks updated: `brief.md` presence → `sandbox/AGENTS.md` + `AGENT_HOME/AGENTS.md` checks | ✅ |
| 5 | `bash -n` passes on all modified files | ✅ |
| 6 | `make test` passes clean | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/start_agent.sh` | Removed `--brief` flag parsing, copy-to-INPUT_DIR logic |
| `libs/_templates/Makefile.template` | Removed `AGENT_BRIEF` variable and `--brief=` from all targets |
| `libs/sandbox-entrypoint.sh` | Updated pre-flight checks (brief.md → AGENTS.md) |
| `libs/compose.sh` | Removed stale brief.md host-side verification |
| `docs/devlog/roadmap.md` | Updated item 12 description with completed + deferred sub-items |
| `docs/devlog/discussions/design_dual_layer_seam_testing.md` | Updated pre-flight table, added provider dry-run checks section |

## Decisions made this session

| Decision | Rationale |
|---|---|
| Remove `--brief` entirely, not just deprecate | The flag and variable had no remaining consumers. Keeping dead flags creates confusion. |
| Provider dry-run checks deferred to item 8/item 10 | Mechanism requires provider overlay mount changes and path resolution that overlap with those items. Not worth doing ad-hoc. |
| ~/.pi/agent/AGENTS.md seeding deferred to item 8 | Requires fixing the provider config copy-in mechanism that's already broken (item 8 scope). |

## Completed this session

| File | Change |
|---|---|
| `scripts/start_agent.sh` | Removed `--brief` flag parsing, usage string, copy-to-INPUT_DIR block, and header docs |
| `libs/_templates/Makefile.template` | Removed `AGENT_BRIEF` variable and `--brief=` from start/serve/dry-run targets |
| `libs/sandbox-entrypoint.sh` | Pre-flight: `brief.md` → `sandbox/AGENTS.md` + `AGENT_HOME/AGENTS.md` |
| `libs/compose.sh` | Removed brief.md host-side verification block |
| `docs/devlog/roadmap.md` | Updated item 12 description |
| `docs/devlog/discussions/design_dual_layer_seam_testing.md` | Updated pre-flight table, added provider dry-run checks section |

## Deferred items

| Item | Reason |
|---|---|
| Seed `~/.pi/agent/AGENTS.md` into provider config dir | Blocked on item 8 (provider config lifecycle fix) |
| Provider dry-run checks hook in `dry_run_reasoning.sh` | Requires provider overlay mount changes — defer to item 8/10 |

## Next session

M2.7 items 1–8 are the remaining scope. Item 8 (settings.json collision fix) is the most-coupled with the deferred items above — if you want to resolve the provider config lifecycle, that's the natural next step.
