---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - `/iter` reads as the procedure it is

## Objective

`/iter` is a how-to: its reader is the agent about to run an iteration. It carried explanation of the workflow's own architecture and rationale for its own rules, which that reader cannot act on, and three closing sections that restated one boundary. The explanation is gone, the guards remain, and the prompt reads as the sequence it is.

## Scope

The row **The `/iter` prompt carries what a how-to reader cannot use**, filed from the operator's worked case with two lines named: "This is the collapsed gate the operator-involved workflows share" and "There is no document registry; the docs tree is the authoritative file list".

The pass cut three classes and kept a fourth:

- the architecture explanation, whose home is `docs/adr/coding_agent_loop_workflow.md`;
- the rationale tail of a rule, where the rule is an imperative or a precondition -- the instruction stays, the justification goes;
- the restatement: `## Release gate`, `## Steps 8-9` and `## The acceptance gate` each described where `/iter` stops, so the boundary now sits in the release gate and the other two carry only what they add;
- and every guard, precondition, exit condition and citation, unchanged.

Ruled out of scope: the sibling prompts. The same class is likely in `/wrapup`, `/scope` and `/plan`, and that is a row rather than this unit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The two lines the row named are gone | `rg -n 'collapsed gate\|document registry' workflow/coding-agent/prompts/iter.md` prints nothing | Agent [x] |
| The closing sections state the boundary once | `rg -n '^## The acceptance gate' workflow/coding-agent/prompts/iter.md` prints nothing, and the milestone-grain boundary sits in `## Release gate` | Agent [x] |
| No rule, guard or precondition was lost | `git diff` for this unit removes rationale and restatement only: every imperative, exit condition and citation in the removed hunks appears in the file after the pass | Agent [x] |
| The roadmap row is rewritten to what landed | the row reads `- [x]` and names this handover | Agent [x] |
| Every decision this unit recorded is realized in the file | the `## Decisions` table read against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The architecture explanation is cut, not pointed at | the reader acts without it, and the ADR already holds it; a pointer earns its line only where the reader must consult the detail | the prompt |
| A rule's rationale tail goes and the rule stays | the how-to's reader needs the instruction and the precondition, and the reason changes no step | the prompt |
| The three closing sections merge into the release gate | each described the same boundary, and a reader taking any one of them as the whole would miss the others | the prompt |
| The siblings are a row, not this unit | the same class in four more prompts is its own pass with its own verification | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The pass cut one rule with its rationale: `A criterion that traces to nothing concrete is likely not needed` instructed the agent to drop such a criterion, and the shortened bullet kept only what to trace to | defect, rule | the agent would keep an untraceable criterion, which the bullet read as satisfied once a source was named | this unit, restored on re-reading the diff |
| The prompt surface's other procedures carry the same class: `/wrapup`, `/scope` and `/plan` are how-tos whose rationale and architecture explanation a running reader cannot use | defect, text | the same attention cost is paid on every iteration's close and scope, not just its start | the roadmap row **The sibling prompts get the same pass `/iter` got** |
| `## Steps 8-9` still lists what stays specific to `/iter`, which is a boundary the release gate now also states | drift | two statements of one boundary drift, and the shorter one reads as complete | this unit, by keeping the list to what it adds: the two gated steps |

## Completed

| File | Action |
|---|---|
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | sixteen edits: the two named lines, six rationale tails, four restatements, and the three closing sections merged into the release gate |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes; the sibling-prompt row is filed |
