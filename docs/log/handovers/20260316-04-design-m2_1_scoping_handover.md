# Agent Handover

**Session date:** 2026-03-16
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Design

## Objective
Scope the M2.1 implementation: resolve all open design questions for the two-container model, define the task list, and confirm acceptance criteria.

## Scope
M2.1 design scoping — resolve Docker Compose orchestration model, image naming, build commands, mode overrides, capability Dockerfile generation, dry-run guarantees, and `.env` variable split. Produce the implementation task list grouped by functional area.

## Acceptance criteria
- All design questions resolved and recorded — **accepted**
- Task list defined with file-level granularity — **accepted**
- Acceptance criteria for M2.1 implementation defined — **accepted**

## Hot files

| File | Why in scope |
|---|---|
| Roadmap M2.1 section | Task list and decisions produced this session |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Docker Compose per project | Declarative orchestration replaces imperative `docker run` | `roadmap.md` M2.1 → `tool_interface.md` |
| Image naming: `<project>-agent-sandbox`, `<project>-opencode-agent` | Compose accepts hyphens natively | `roadmap.md` M2.1 → `tool_interface.md` |
| Compose baked vs `.env` split | Stable structure vs machine-specific runtime | `roadmap.md` M2.1 → `tool_interface.md` |
| `.env` runtime variables defined | Each maps to a host path or credential that varies per machine/run | `roadmap.md` M2.1 → `tool_interface.md` |
| Mode overrides via `-f` flags | Ports not exposed when not in serve mode | `roadmap.md` M2.1 → `tool_interface.md` |
| `make build [sandbox\|agent\|all]` dispatch | Granular rebuild; staleness integrated per-image | `roadmap.md` M2.1 → `tool_interface.md` |
| Two-image staleness: separate `image-files.txt`, warn separately | Images go stale independently | `roadmap.md` M2.1 → `tool_interface.md` |
| Capability Dockerfile in `SANDBOX_DIR`, default template in `libs/_templates/` | Projects control their own dev environment | `roadmap.md` M2.1 → `tool_interface.md` |
| Dry-run minimum guarantees | Defines what a successful dry-run proves | `roadmap.md` M2.1 → `tool_interface.md` |
| Dogfood first: agent-sandbox's own compose before template | Template derived from working version | `roadmap.md` M2.1 |
| `start_agent.sh` remains entry point | Compose handles container orchestration only | `roadmap.md` M2.1 |
| Tool interface spec: `docs/architecture/tool_interface.md` | Defines external contract distinct from `execution_model.md` | `roadmap.md` M2.1 |

## Completed this session

| File | Change |
|---|---|
| Roadmap M2.1 section | Implementation task list (7 groups, 17 tasks), design decisions, acceptance criteria |

## Deferred items

| Item | Reason | Goes where |
|---|---|---|
| Modularise `start_agent.sh` across providers | M2.2 scope | `roadmap_future.md` M2.2 |
| Decouple sandboxing from tool implementation | Cross-cuts M2.1 and M2.2 | `roadmap_future.md` M2.2+ |

## Next session

M2.1 documentation — update architecture docs to reflect confirmed design before implementation.
