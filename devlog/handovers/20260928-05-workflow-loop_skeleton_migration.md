# Agent Handover

**Date:** 2026-09-28
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Workflow
**Status:** Closed

## Objective

Land the U1 skeleton of the M3.2.1 loop-to-workflow migration: the new ADR (*Coding Agent Loop Workflow*), the four loop prompt stubs, the concept-doc shell, and the policy link pointers. U1 is the structure pass; the policy content migration is U2-U4.

## Scope

One unit, one commit, one handover. U1 establishes the migration's skeleton without moving procedure content.

- The new ADR `docs/adr/coding_agent_loop_workflow.md`: index + responsibilities separation + state diagram + concept offload map + references. Settled-at-close framing.
- Four loop prompts in `workflow/coding-agent/prompts/`: `iter.md` (rename-move of `src/reasoning/agent/prompts/new-iteration.md`), `plan.md` (grill-me stopgap stub), `milestone-start.md` (stub), `milestone-close.md` (refresh of `milestone-close-run.md`).
- The concept shell `docs/concepts/autonomous_agent_loop.md`.
- Policy link pointers from `docs/operations/iteration_policy.md` to the prompts.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | The ADR exists with the five-part scope and a `Current:` date of 2026-09-28 | read `docs/adr/coding_agent_loop_workflow.md` | Agent [x] accepted: taxonomy, responsibilities, inline diagram, offload map, references present |
| AC2 | The ADR's state diagram is inline, uses box-drawing characters, and covers scoping through formal close | read the diagram block | Agent [x] accepted: box-drawing block, scoping to close, minor-loop handoff noted |
| AC3 | The four loop prompts exist under `workflow/coding-agent/prompts/`, each with frontmatter and `> $@` | `ls workflow/coding-agent/prompts/{iter,plan,milestone-start,milestone-close}.md` | Agent [x] accepted: all four present with frontmatter and `> $@` |
| AC4 | `iter.md` is the rename-move of `new-iteration.md`, and the source file is removed | `git log --follow` and `ls src/reasoning/agent/prompts/new-iteration.md` | Agent [x] accepted: staged as rename `R`, source absent, body unchanged |
| AC5 | The concept shell `autonomous_agent_loop.md` exists and takes over the explanatory loop overview role | read `docs/concepts/autonomous_agent_loop.md` | Agent [x] accepted: reframed as loop conceptual home |
| AC6 | Policy link pointers from `iteration_policy.md` to the prompts land | read the Loop workflow prompts section | Agent [x] accepted: all five prompt links present |
| AC7 | Lint clean and the suite passes | `scripts/lint.sh`, `scripts/run_tests.sh` | Agent [x] accepted: lint clean, 1002/0 |

## Hot files

| File | Why in scope |
|---|---|
| `docs/adr/coding_agent_loop_workflow.md` | the new ADR, the migration's anchor |
| `workflow/coding-agent/prompts/{iter,plan,milestone-start,milestone-close}.md` | the four loop prompt stubs |
| `docs/concepts/autonomous_agent_loop.md` | the recycled concept shell |
| `docs/operations/iteration_policy.md` | gains plan-link-pointers to the prompts |
| `src/reasoning/agent/prompts/new-iteration.md` | renamed to `iter.md` |
| `devlog/handovers/20260928-05-workflow-loop_skeleton_migration.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `/iter` is a rename-move of `new-iteration.md` to `workflow/coding-agent/prompts/` | the loop prompts live under `workflow/coding-agent/prompts/` per the separation; `/iter` already existed as `new-iteration` | `coding_agent_loop_workflow.md`, taxonomy table |
| The ADR state diagram is inline with box-drawing characters | `documentation_policy.md` allows box-drawing inside ASCII-art diagrams | the ADR, State diagram |
| `milestone-close.md` is the loop surface that points to `milestone-close-run.md` | the run template holds the body; the loop prompt is the invocation surface; U4 migrates the close procedure into it | the ADR taxonomy |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| None. | | | |

## Completed

| File | Change |
|---|---|
| `docs/adr/coding_agent_loop_workflow.md` | created: the five-part ADR (taxonomy, responsibilities, inline state diagram, concept offload map, references) |
| `workflow/coding-agent/prompts/iter.md` | rename-move of `src/reasoning/agent/prompts/new-iteration.md`, unchanged body |
| `workflow/coding-agent/prompts/plan.md` | created: grill-me stopgap stub |
| `workflow/coding-agent/prompts/milestone-start.md` | created: major-loop-open stub |
| `workflow/coding-agent/prompts/milestone-close.md` | created: close loop surface pointing to `milestone-close-run.md` |
| `docs/concepts/autonomous_agent_loop.md` | reframed as the loop conceptual shell (recycled name) |
| `docs/operations/iteration_policy.md` | added the Loop workflow prompts link section |
| `docs/operations/handover_policy.md` | updated the iter reference and path |
| `docs/concepts/terminology.md` | renamed the open-iteration prompt reference to `iter` |
| `workflow/coding-agent/audits/surface-area-report.md` | updated `new-iteration` references to `iter` |
| `src/reasoning/agent/prompts/new-iteration.md` | removed (renamed to `iter.md`) |
| `devlog/handovers/20260928-05-workflow-loop_skeleton_migration.md` | this handover |

## Deferred items

| Item | Why deferred | Where it goes |
|---|---|---|
| None. | | |

## What's Next

U2: the minor-loop procedure migration from `iteration_policy.md` (Minor Loop Step Details, File Tracking) into `/iter`. U3 and U4 follow; then the four per-prompt quality passes.

Operational note for the host: the runtime `/opt/workflow/agent/prompts/` is baked at image build (preflight.sh). The repo-side `new-iteration.md` to `iter.md` move must be propagated to the image prompt bake before `/iter` is invocable at runtime; the bake wiring is outside this repo tree.
