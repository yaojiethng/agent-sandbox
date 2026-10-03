# Agent Handover

**Date:** 2026-09-28
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Implementation
**Status:** Closed

## Objective

Execute the M3.2.1 stale-artifact cleanup (the "Fold the T1 stale-artifact row into M3.2.1" row, F1-F2 disposition): remove the stale concept docs and their references, purge the TASK.md entrypoint promise, and clear the `.agent-input` vs `.workspace/input` discrepancy. Runs before U2 so the content migration writes over clean ground.

## Scope

One unit, one commit, one handover. Operated disposition set by the operator (2026-09-28): R1-R3 all remove, plus purge TASK.md entrypoint references and any empty template stubs.

- Remove `docs/concepts/autonomous_task.md` (R1) and its inbound references.
- Audit `docs/concepts/agent_workflow.md` (R2) for staleness; keep it (the audit confirmed it is live and canonical).
- Remove the TASK.md-as-task-entrypoint references and any packaged TASK.md template stub.
- Clear the `.agent-input` mentions and confirm no live `.agent-input` claim remains (R3).

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `autonomous_task.md` and `agent_workflow.md` disposition | `ls docs/concepts/` | Agent [x] accepted: `autonomous_task.md` removed, `agent_workflow.md` kept |
| AC2 | No inbound link references the removed `autonomous_task.md` | `grep -rn "autonomous_task"` across `docs/` `workflow/` `src/` | Agent [x] accepted: only historical handovers match |
| AC3 | No TASK.md file-promise or packaged task template remains | `grep -rn "TASK.md"` across `docs/` `workflow/` `src/` `scripts/` | Agent [x] accepted: `scripts/templates/TASK.md.template` (orphan) removed; no file-promise remains |
| AC4 | No live stale-artifact `.agent-input` claim remains | `grep -rn "agent-input"` across `docs/` `workflow/` `src/` `scripts/` | Agent [x] accepted: architecture-doc-reviewer example updated; only the open T6 Pre-snapshot validation row mentions `.agent-input/`, a future capability |
| AC5 | The fold-row disposition (R1 remove, R2 keep, R3 updated) is recorded in the M3.2.1 roadmap row | read the Fold row | Agent [x] accepted: R1-R3 disposition recorded |
| AC6 | Lint clean and the suite passes | `scripts/lint.sh`, `scripts/run_tests.sh` | Agent [x] accepted: lint clean, 1002/0 |

## Hot files

| File | Why in scope |
|---|---|
| `docs/concepts/autonomous_task.md` | removed (R1) |
| `docs/concepts/agent_workflow.md` | audited, kept (R2, live and canonical) |
| `docs/development/contributors.md` | inbound reference to removed `autonomous_task.md` removed |
| `scripts/templates/TASK.md.template` | removed (R1 orphan stub task template) |
| `workflow/coding-agent/audits/architecture-doc-reviewer.skill.md` | `.agent-input` reference updated to `.workspace/input/` (R3) |
| `devlog/roadmap.md` | Fold row gains the R1-R3 disposition |
| `devlog/handovers/20260928-06-impl-stale_artifact_cleanup.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| R1-R3 remove, R2 audit-then-keep, plus TASK.md entrypoint promises and empty template stubs | operator set, 2026-09-28: empty template documents do more harm than no document | roadmap Fold row + this handover |
| R2 `agent_workflow.md` kept | audit confirmed it is live and canonical (152 lines, workflow-expression model, seven live inbound references); removal would orphan the framework's authoritative concept home | roadmap Fold row + this handover |
| TASK.md entrypoint references purged by removing `autonomous_task.md` | no live TASK.md file promise existed beyond that doc | roadmap Fold row + this handover |
| No empty AGENTS.md/task stubs packaged with the agent exist | pi config `AGENTS.md` (86 lines) and `pi-agent.md` are substantive; `env.stub` is a provider-config template promoted to `.env`; no onboard/entrypoint step generates an empty AGENTS.md or TASK.md | roadmap Fold row + this handover |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| R2 was proposed as remove but the audit showed it live and canonical | scope | removing `agent_workflow.md` would break seven live references and delete the workflow-expression model | kept; recorded as R2 keep |
| The handover Scope and Hot-files listed `agent_workflow.md` as removed, contradicting its own Decisions, Findings and Completed tables and the live tree | record defect | a reader would believe a live concept doc was deleted | caught by independent verifier (space-bunny-free, 2026-09-28); corrected in this handover |
| `scripts/templates/TASK.md.template` is a git-tracked orphan task template referencing the retired `agent_context_brief.md` | missed artifact | an empty task template shipped with the agent contradicts the operator's "empty template documents do more harm than no document" directive | caught by independent verifier; removed |
| The open T6 Pre-snapshot validation row references `.agent-input/`, a path the harness does not use | stale path in a future capability | keeps a live `.agent-input` mention alive outside the cleanup scope | flagged, not edited -- future capability, adjacent to the R3 cleanup |

## Completed

| File | Change |
|---|---|
| `docs/concepts/autonomous_task.md` | removed (R1) |
| `docs/development/contributors.md` | removed the `autonomous_task.md` document-table row |
| `scripts/templates/TASK.md.template` | removed (orphan task stub) |
| `workflow/coding-agent/audits/architecture-doc-reviewer.skill.md` | `.agent-input` example updated to `.workspace/input/` (R3) |
| `docs/concepts/agent_workflow.md` | kept (R2, audit confirmed live) -- no change |
| `devlog/roadmap.md` | Fold row records the R1-R3 disposition; TASK.md and `.agent-input` claims corrected |
| `devlog/handovers/20260928-06-impl-stale_artifact_cleanup.md` | this handover |

## Deferred items

| Item | Why deferred | Where it goes |
|---|---|---|
| The manual administrative close checklist refresh | it is the rule side of the close procedure, interlocked with U4's migration | M3.2.1 U4 |

## What's Next

U2: the minor-loop procedure migration from `iteration_policy.md` into `/iter`, now over clean stale-artifact ground.
