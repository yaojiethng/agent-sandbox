---
date: 2026-10-03
milestone: M3.2.1 - Loops as Workflows
type: Housekeeping
status: Closed
---

# Handover - Clean the M3.2.1 task list

## Objective

Clean the M3.2.1 task list so its open rows are genuine work: re-file the two out-of-scope rows, close the two `/document` rows with their developed extent stated, move their remainder to M3.2.2, close the draft-gate re-path at the handover-window cutoff, and give the two bucket parents completion context.

## Scope

The M3.2.1 `Docs and ADR consolidation` and `Prompt/AGENTS.md conventions` groups, the `/document`: docs-session runbook and `/document` convergence rows, the M3.2.1 section blurb, the draft-gate re-path sub-item of handover `20261002-19`, and the two destination sections (T1, T7) and M3.2.2's `Distil documentation-pass.md` row.

| In | Out |
|---|---|
| Re-file `Expose a capacity signal to the agent` to T7 | Any change to `autonomous_agent_loop.md`; its consolidation pass is the next unit |
| Re-file `Skill and prompt eval infrastructure` to T1 | The producer-owns-the-definition rule; the operator scheduled its own `docs:` unit |
| Close the `/document` runbook and convergence rows with their extent stated | Implementing the M3.2.2 `Distil documentation-pass.md` row |
| Close the re-path sub-item at the `20261001` cutoff and re-path the four in-scope handovers | Records dated before `20261001`; they stay as history |
| Move the `/document` remainder under M3.2.2's `Distil documentation-pass.md` row | Any code, prompt, or policy change |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The capacity-signal row sits under T7, not M3.2.1 | `grep -n "Expose a capacity signal" devlog/roadmap.md` reports line 321, after `#### T7` at 313 | Agent [x] |
| The skill/prompt-eval row sits under T1, not M3.2.1 | `grep -n "Skill and prompt eval infrastructure" devlog/roadmap.md` reports line 269, after `#### T1` at 220 | Agent [x] |
| The runbook row is `[x]`, names handover `20261002-12`, states the M3.2.1 extent, and the rename is recorded under M3.2.2 | `grep -n "docs-session runbook" devlog/roadmap.md` | Agent [x] |
| The convergence row is `[x]` and states non-convergence as the M3.2.1 extent, remainder under M3.2.2 | `grep -n "\`/document\` convergence" devlog/roadmap.md` | Agent [x] |
| The M3.2.2 Distil row carries the `/document` remainder as unchecked subtasks | `grep -n -A5 "Distil .documentation-pass" devlog/roadmap.md` reports four subtasks | Agent [x] |
| The `Docs and ADR consolidation` bucket carries no unrelated open child | the bucket is `[x]` with only `[x]` children; the closed-parent scan reports none | Agent [x] |
| The `Prompt/AGENTS.md conventions` parent names what landed and what remains | `grep -n "Prompt/AGENTS.md conventions" devlog/roadmap.md` carries the completion line | Agent [x] |
| The deconfliction row carries no duplicate fragment | `grep -c "Handover .20261002-27.. the canonical owner" devlog/roadmap.md` returns 0 | Agent [x] |
| The M3.2.1 blurb names no `/auto` or `/parallel-auto` as current scope | `sed -n '/#### M3.2.1/,/#### Not in scope/p' devlog/roadmap.md \| grep -c "/parallel-auto"` returns 0 | Agent [x] |
| The `Handover format drift` row states the cutover `20261001` | `grep -n "Handover format drift" devlog/roadmap.md` names `20261001` and credits `20261003-05` | Agent [x] |
| The re-path sub-item and its parent are `[x]` and state the `20261001` cutoff, earlier records out of scope | `grep -n "Re-path the stale prompt references" devlog/roadmap.md` | Agent [x] |
| The four in-scope handovers name the moved prompt under `drafts/` and carry a `[CORRECTION -- 2026-10-03]` block | `grep -c "CORRECTION -- 2026-10-03"` returns 1 on each of the four | Agent [x] |
| No unmarked stale draft-gate path remains in a record dated 2026-10-01 or later | `grep -rn "prompts/(auto\|sequential-work\|parallel-work\|task-queue\|maintenance)\.md"` on the records on or after `20261001` returns only correction blocks | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the M3.2.1 task list, the T1 and T7 destinations, and the M3.2.2 row |
| [`devlog/handovers/archive/20261001-01-plan-auto_smart_dispatcher_reservation.md`](../../devlog/handovers/archive/20261001-01-plan-auto_smart_dispatcher_reservation.md) | stale draft-gate paths, re-pathed |
| [`devlog/handovers/archive/20261001-03-workflow-backlog_triage_prompt.md`](../../devlog/handovers/archive/20261001-03-workflow-backlog_triage_prompt.md) | stale draft-gate paths, re-pathed |
| [`devlog/handovers/archive/20261002-06-chore-prompt_frontmatter_parse_gate.md`](../../devlog/handovers/archive/20261002-06-chore-prompt_frontmatter_parse_gate.md) | stale draft-gate path, re-pathed |
| [`devlog/handovers/archive/20261002-10-workflow-maintenance_extraction_and_dispatch.md`](../../devlog/handovers/archive/20261002-10-workflow-maintenance_extraction_and_dispatch.md) | stale draft-gate path, re-pathed |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Re-file by moving the row, not by copying it | a copy in two milestones is the record-layer duplicate the maintenance check reports | this handover |
| Close the `/document` rows at the M3.2.1 extent and move the remainder to M3.2.2 | the operator ruled that further `/document` development belongs to M3.2.2, and the remaining work is not abandoned | roadmap M3.2.1 and M3.2.2 |
| Apply the `20261001` cutoff to the draft-gate re-path | the operator directed that the re-path use the same cutoff as the handover format window, so a record before it stays as history | this handover; `handover_policy.md` |
| Schedule the producer-owns-the-definition rule as its own `docs:` unit | it is policy content, not record cleanup; mixing a policy change into a `chore:` record commit breaks the one-type-per-delivery rule | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The operator directed the re-path cutoff at `20261001`, matching the handover format window, so records before it are out of scope. Four handovers on or after the cutoff carried stale draft-gate paths. | steering | current iteration |
| The operator scheduled the producer-owns-the-definition rule as a small `docs:` unit immediately after this one; it is not record cleanup and does not ride this commit. | steering | next iteration |
| The `Handover format drift` row named cutover `20261003`, but handover `20261003-05` had moved the window to `20261001`. The row was stale against `handover_policy.md`. | contradiction | current iteration |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | M3.2.1 task list restructured: two rows re-filed, two `/document` rows closed with extents stated, four remainder subtasks added under M3.2.2's Distil row, both bucket parents closed with completion context, stale literal, blurb, and duplicate fragment fixed |
| the four in-scope handovers | draft-gate paths re-pathed to `workflow/coding-agent/drafts/` under `[CORRECTION -- 2026-10-03]` blocks |
| `devlog/roadmap.md` | roadmap maintenance before the handover: dropped the forward-looking sentence from the landed deconfliction row (commit `e1264aa`) |
