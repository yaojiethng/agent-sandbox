# Agent Handover

**Date:** 2026-10-01
**Milestone:** M3.2.3 -- Dispatch Workflows as a Command Surface
**Type:** Workflow
**Status:** Closed

## Objective

Add a pre-dispatch classifier that sorts the open roadmap backlog into the rows an autonomous run can dispatch and the rows carrying a question, and file it in the loop taxonomy.

## Scope

The `/backlog-triage` prompt, its three cross-links, and its rows in the ADR and concept-doc prompt tables. Filed as an M3.2.3 task: M3.2.3 owns the curated dispatch-command surface, and this prompt selects the rows that surface consumes.

Unit 1 of a two-unit split confirmed at the scope gate. Unit 2 -- the `Decisions pending` handover record -- is handover `20261001-04` and lands separately under the general M3 T1 track. The file sets are disjoint.

Not in scope: execution-order resolution and dispatch-shape selection, which are the M4 `/auto` dispatcher's. A cross-roadmap sweep of stale rows already resident in `roadmap.md`, which the operator judged covered going forward by the roadmap write-back at the release gate and the B5 carry-forward resolution.

## Carried forward

None. The prior handover (`20261001-02`) closed with one deferred item, a determination rule for `superseded` in `discussion_policy.md`, which this iteration does not pick up.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `backlog-triage.md` exists, its frontmatter parses, and the installed copy is byte-identical | `diff -q workflow/coding-agent/prompts/backlog-triage.md /opt/workflow/agent/prompts/backlog-triage.md` | Agent [x] |
| 2 | The ADR prompt table and family prose carry the `backlog-triage` row | `grep -n "backlog-triage" docs/adr/coding_agent_loop_workflow.md` | Agent [x] |
| 3 | The concept doc names `backlog-triage` as driving no transition, below the transition table | `grep -n "backlog-triage" docs/concepts/autonomous_agent_loop.md` | Agent [x] |
| 4 | `sequential-work.md`, `gm.md` and `auto.md` each link the prompt from the section that routes to it | `grep -c "backlog-triage" workflow/coding-agent/prompts/{sequential-work,gm,auto}.md` | Agent [x] |
| 5 | Every relative link in the prompt resolves on disk | `node` link walk over the four prompt files | Agent [x] |
| 6 | `roadmap.md` carries the filed M3.2.3 row for this prompt | `grep -c "backlog-triage" devlog/roadmap.md` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/backlog-triage.md`](../../workflow/coding-agent/prompts/backlog-triage.md) | New prompt: the backlog autonomy classifier |
| [`workflow/coding-agent/prompts/sequential-work.md`](../../workflow/coding-agent/prompts/sequential-work.md) | Step 1 names `/backlog-triage` as the producer of the parked rows |
| [`workflow/coding-agent/prompts/gm.md`](../../workflow/coding-agent/prompts/gm.md) | Close routes the inventory's autonomy split to `/backlog-triage` |
| [`workflow/coding-agent/prompts/auto.md`](../../workflow/coding-agent/prompts/auto.md) | Reference: `/backlog-triage` is the M4 precursor classifier |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | Prompt table and family prose carry the new row |
| [`docs/concepts/autonomous_agent_loop.md`](../../docs/concepts/autonomous_agent_loop.md) | Names the prompt as a classifier that drives no transition |
| [`devlog/roadmap.md`](../roadmap.md) | The filed M3.2.3 row |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Build a backlog autonomy triage prompt | Mined from 5,026 user messages across 481 transcripts: three distinct operator asks in September for the rows completable without them, each time re-derived by reading the whole roadmap | This handover |
| File it as a pre-dispatch classifier inside the taxonomy, not outside it | It selects the rows the dispatch family consumes, so it belongs beside that family; its own scope statement already records that it drives no transition | `docs/adr/coding_agent_loop_workflow.md` |
| Name it `backlog-triage`, not `triage` | `triage` already names the advisor-findings step in the prompt-authoring conventions; a second meaning breaks one-term-one-meaning | `workflow/coding-agent/prompts/backlog-triage.md` |
| Split the two automations into two units | They share no file and serve no common outcome: one selects work, the other records a question. One roadmap task per iteration, and two different milestone owners | This handover, Scope |
| Keep the out-of-scope link-depth repair rather than reverting it | The operator released the close after the repair was surfaced; reverting would restore a broken link to a landed row | This handover, Findings |
| No deferred-item sweep prompt | The roadmap write-back at the release gate and the B5 carry-forward resolution stop orphans accumulating; only the pre-existing backlog is unaddressed, and that is a one-time sweep, not a prompt | This handover, Scope |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The link-depth correction applied to this unit's roadmap row also repaired a pre-existing broken link in the `adversarial-review-run` row, which used `../../` from `devlog/roadmap.md`. Verified broken against `HEAD`. The edit fell outside the released scope and was surfaced to the operator at the release gate, who released the close without reverting it. | scope change | current iteration. Triaged to: this handover's Decisions table; the row is recorded in the M3.2.3 block it already sits in |

## Completed

| Work | Result |
|---|---|
| `/backlog-triage` prompt authored | Five steps (candidate set, well-specifiedness test, question resolution, unit-rule check, table), plus non-goals and five invariants. A verdict on every candidate; one question per parked row; four verdict values (`runnable`, `needs design`, `needs operator decision`, `stale`) |
| Cross-links added | `sequential-work.md` Step 1 routes a whole-backlog plan through the classifier first; `gm.md` Close routes an unattended run through it; `auto.md` Reference records it as the M4 dispatcher's precursor |
| ADR row and family prose | Table row plus a bullet establishing it as a pre-dispatch classifier that runs no iteration, owned by M3.2.3 |
| Concept-doc note | Placed below the transition table, matching how the document already handles `/auto` and `/goal`; it is not a row, because the table's column is the transition a workflow drives and this one drives none |
| Installed mirror refreshed | Four prompt files copied to `/opt/workflow/agent/prompts/`, byte-identical |
| Roadmap row filed | M3.2.3 task row naming the prompt, its verdict values, and its two routing targets |

## Deferred items

| Item | Reason |
|---|---|
| Nothing for this prompt | The operator set the scope; the deferred-item sweep question was answered at the gate |

## What's Next

Unit 2 is handover `20261001-04`, the `Decisions pending` record under the M3 T1 track. It is independent of this prompt and lands as its own commit. After both, `fanout.md`'s rename and doc pass remains unstarted from the prior handover.
