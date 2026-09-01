# Agent Handover

**Date:** 2026-07-22
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Type:** Design — M2.6.4 Mount Model Design
**Status:** Closed

## Objective

Complete the M2.6.4 mount model design session: resolve all design decisions for the worktree mount model, including the PROJECT_DIR mount wiring pre-design investigation, and produce a scoped implementation plan covering compose template changes, worktree lifecycle, command adaptation, and migration path.

## Scope

**Unit 1 (Complete)** — PROJECT_DIR mount wiring investigation
- Traced PROJECT_DIR flow through .env → Makefile → agent-sandbox.sh → start_agent.sh
- Documented current mount shape (6 bind mounts + anonymous volume + provider config)
- Identified 6 stale/contradictory documentation items, 4 undocumented behaviors, 1 .env variable lifecycle gap
- Output: `devlog/discussions/20260722-study-settled-mount_wiring_survey.md`

**Unit 2 — Design decisions (not started)**
All design questions needed before implementation can start:
- Mount path specification, worktree lifecycle, compose template changes
- Command adaptation, migration path, security invariant updates

**Unit 3 — Design document output (not started)**
- ADR for resolved design decisions, updated architecture docs, roadmap task list

## Carried forward

| Item | From handover |
|---|---|
| PROJECT_DIR mount wiring investigation | `20260721-07-workflow-policy_disambiguation_and_mount_wiring.md` |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | PROJECT_DIR mount wiring traced through Makefile, compose template, start_agent.sh, config | `devlog/discussions/20260722-study-settled-mount_wiring_survey.md` F1, F2 | ✅ Agent |
| 2 | Cross-platform path concerns documented | Survey F5b, Open Questions section | ✅ Agent |
| 3 | Documentation gaps identified (stale/contradictory/undocumented) | Survey F4 (6 items), F5 (4 items), F6 | ✅ Agent |
| 4 | Design decisions resolved with rationale recorded | Pending design session | Operator |
| 5 | M2.6.4 roadmap task list updated | Pending design session | Operator |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | PROJECT_DIR mount wiring — how is PROJECT_DIR specified and forwarded |
| [`scripts/workflows/start_agent.sh`](../../scripts/workflows/start_agent.sh) | PROJECT_DIR mount wiring — entrypoint for agent startup |
| [`scripts/templates/docker-compose.yml.template`](../../scripts/templates/docker-compose.yml.template) | PROJECT_DIR mount wiring — volumes and mounts; target for conditional worktree mount |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | CLI entrypoint — how PROJECT_DIR is accepted |
| [`docs/architecture/security.md`](../../docs/architecture/security.md) | Security invariant updates per tier 3 (worktree mount) |
| [`docs/architecture/system_overview.md`](../../docs/architecture/system_overview.md) | Architecture layer model — potential updates for mount model |
| [`docs/adr/sandbox_delivery_model.md`](../../docs/adr/sandbox_delivery_model.md) | Existing worktree ADR — supersedes or amends as needed |
| `devlog/roadmap.md` | Update M2.6.4 task list with implementation units |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `devlog/discussions/20260722-study-settled-mount_wiring_survey.md` | **New** — mount wiring survey organised by tier: Tier 1 fully achieved, Tier 2 partial (3 gaps), Tier 3 not achieved (7 implementation gaps + 4 doc gaps). Cross-cutting: PROJECT_DIR flow, constraints C1–C5, open questions. |
| `devlog/roadmap.md` | Marked PROJECT_DIR mount wiring pre-design investigation as complete |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| Unit 2 — Design decisions (ADR, architecture doc updates, roadmap task list) | Session scope was limited to the survey; design decisions deferred to dedicated design session | M2.6.4 design session |
| Unit 3 — Design document output | Depends on Unit 2 | M2.6.4 design session |

## Next session

**M2.6.4 — Mount Model Design Session (decision phase).** The three pre-design investigations are complete (extensibility audit, apply logic unification, mount wiring survey). The design session should resolve the open questions in the mount wiring survey and produce:
- ADR for mount model implementation decisions
- Updated architecture docs (security.md, sandbox_lifecycle.md, tool_interface.md, execution_model.md)
- Scoped implementation task list in `roadmap.md`

**Conclusions from this session:** Mount wiring survey produced. Tier 1 fully achieved. Tier 2 has 3 implementation gaps (RW snapshot mount, agent working directory in .snapshot/, entrypoint redirect). Tier 3 has 7 implementation gaps and 4 documentation gaps. Six open questions remain for the design session.
