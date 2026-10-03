---
date: 2026-10-03
milestone: M3.2.1 - Loops as Workflows
type: Documentation
status: Closed
---

# Handover - Consolidate the autonomous-agent-loop concept document

## Objective

Move the loop's state diagram into the concept document that states the model, leave the transition rules in the loop ADR, and align the concept document with the redrawn model, whose diagram postdates the document's last edit.

## Scope

The M3.2.1 row `Concept-doc offload: autonomous_agent_loop.md`, at its consolidation pass. The concept doc carried stale loop content and no skill dispatch; the ADR carried the diagram, whose home the promotion topology gives to the concept doc. This iteration splits those two by kind and aligns the concept doc with the settled model.

| In | Out |
|---|---|
| `docs/concepts/autonomous_agent_loop.md` | The per-prompt quality passes; separate rows that grow this document as they land |
| `docs/adr/coding_agent_loop_workflow.md` | Any change to a loop decision; the transition rules stay as written |
| The M3.2.1 concept-doc row | Any change to a workflow prompt or a policy file |
| The iteration handover | The `milestone_policy` expansion; closed by deletion |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The concept doc carries the two-grain loop diagram and no stale close step | `grep -c "MILESTONE GRAIN" docs/concepts/autonomous_agent_loop.md` returns 1; `grep -n "pre-close verification" docs/concepts/autonomous_agent_loop.md` returns nothing | Agent [x] |
| 2 | The concept doc's workflow table names `/wrapup`, and the `/milestone-close` row names compaction, the changelog and the close boundary | `grep -n "wrapup\|milestone-close" docs/concepts/autonomous_agent_loop.md` | Agent [x] |
| 3 | The concept doc states how a workflow dispatches to a skill | the Skills section names `roadmap-maintenance`, `handover-maintenance` and `grill-me` | Agent [x] |
| 4 | The ADR holds no diagram; its transition section states the rules and links the concept doc's diagram | `grep -c "MILESTONE GRAIN" docs/adr/coding_agent_loop_workflow.md` returns 0; the `## Transitions` section links `autonomous_agent_loop.md#the-loop` | Agent [x] |
| 5 | The ADR's closed entry carries the change marker | the 2026-09-28 entry has a `[CORRECTION -- 2026-10-03: ...]` block; `**Current:**` reads 2026-10-03 | Agent [x] |
| 6 | The diagram is written once | `grep -rln "MILESTONE GRAIN" docs/` returns the concept doc only | Agent [x] |
| 7 | The roadmap row is closed and the gates are clean | the row reads `[x]`; `bash scripts/lint.sh` clean across 6 gates | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/concepts/autonomous_agent_loop.md`](../../docs/concepts/autonomous_agent_loop.md) | the model's home; receives the diagram and the skill dispatch |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | keeps the transition rules; loses the diagram |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the row this iteration closes |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The concept doc owns the diagram; the ADR owns the transitions | the promotion topology makes the concept document the model's home and the ADR the explainer of why; a model living in the ADR is the same defect as a rule living in a concept | this handover |
| The ADR links the diagram by fragment anchor; the concept doc links the transition rules by fragment anchor | the repo has no transclusion, so the diagram is written once and linked; anchor links are the repo convention | this handover |
| The diagram-home change carries the ADR's `[CORRECTION]` marker | the change edits a closed record, and R2 requires the type's marker for any closed-record content change | this handover |
| No new ADR entry | the loop decisions do not change; only the diagram's home does, which the taxonomy already governs | this handover |
| The concept doc states the close seam as a one-line link, not a restatement | a near-verbatim copy of the ADR's close-seam paragraph would duplicate one rule across two documents | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|

None.

## Completed

| File | Change |
|---|---|
| `docs/concepts/autonomous_agent_loop.md` | carries the two-grain state diagram; the workflow table gains `/wrapup` and the corrected `/milestone-close` row; a Skills section names the dispatch to the three skills; the stale close step drops |
| `docs/adr/coding_agent_loop_workflow.md` | `## State diagram` becomes `## Transitions`; the ASCII block becomes a link to the concept doc's diagram; the 2026-09-28 entry takes the `[CORRECTION]` marker; `**Current:**` moves to 2026-10-03 |
| `devlog/roadmap.md` | the M3.2.1 concept-doc row closed with its landing note |
