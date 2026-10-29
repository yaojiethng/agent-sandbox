---
date: 2026-10-27
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Documentation
status: Closed
---

# Handover - the layer model states the division and the rule, not a status

## Objective

Make `system_overview.md` `## Architecture Layer Model` say what the three layers are and what order work on them runs in, and drop the claim that any layer has stopped changing.

## Scope

One section of `docs/reference/system_overview.md`, plus its three carriers: the two lines in the `project-documentation` convention that named the freeze status and the freeze rule, and the `AGENTS.md` pointer row that named a freeze status check.

Out of scope, and named here because they are adjacent: M3.4.1 will re-cut this model, and T8's `A controlled vocabulary for layer` row will rename the implementation-stack sense to `tier`. Neither is pre-empted. Also out of scope: the two planned rewrites the section's old status column implicitly denied, which have no roadmap row and are filed as a finding rather than a task.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The section states what each layer holds and nothing about how it works | the `Holds` column; the mechanics stay with `copy_delivery.md`, `mount_delivery.md` and `agent_workflow.md` | Agent [x] |
| No layer carries a status column | the Freeze status column and the "frozen at M1.2; changes expected" cell are gone; the question "what is in flight" is the task list's | Agent [x] |
| The rule runs in both directions | building settles the layer below first; a low-layer change waits on the work above it | Agent [x] |
| The cost of going around the rule is stated as four mechanisms | four items, each naming a different thing that breaks: the interface, the review, the record, the evidence | Agent [x] |
| The four faults are diagnosable | `### Which situation you are in`: three cases, each with a test and a fix | Agent [x] |
| `frozen layer` is not a reserved term | no entry in `terminology.md`; no document in the tree says the phrase after this unit | Agent [x] |
| No carrier asserts the old state | convention line 20 and line 27, and the `AGENTS.md` row, retargeted; `grep -rn "freeze" docs/reference/system_overview.md` returns nothing | Agent [x] |
| Gates and suite | `bash scripts/lint.sh` clean across 15 gates; `bash scripts/run_tests.sh` 1349 passed | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The status column is deleted, not corrected | A date in that column asserts a layer will not change again, and two rewrites are already planned against it. Correcting the dates would keep the false claim and make it current | the section, and this record |
| The word `frozen` leaves the model | It carried two questions at once: whether an interface is settled, and whether a layer is closed for edits. Those have different answers, which is how "frozen at M1.2, changes expected in M1.5" was written in good faith | the section |
| The rule is described by the build order, not by up and down | "Building runs up, rewriting runs down" needs a diagram nobody drew, and the second clause described the permission rather than the invalidation | the section |
| No `terminology.md` entry for `frozen layer` | A reserved term names a thing whose meaning documents must share. This named a state of a process, and the rule is the durable subject | this record |
| The writing rule moves to the convention, one pointer remains | The convention owns how a document states a layer's state; the model owns the division and the order. Two statements of one rule is the duplication this milestone removes | the section's closing line |
| The four costs keep their mechanisms, not their adjectives | Each item now names what breaks and why: the interface future work relies on, the review's evidence, the absent record, the stale carriers. Four descriptions of one break would not be a warning | the section |

## Decisions pending

| Question | Why it is not resolved here |
|---|---|
| Do the planned rewrites get roadmap rows | A unified provider image and a per-project `.devcontainer` are both decisions the operator stated, and neither has a row. Filing rows is a scope call, not an edit |
| When does the model adopt `tier` | T8's controlled-vocabulary row resolves the term, and pre-empting it here would desync the row that owns the decision |

## Findings

- **The section asserted permanence while two rewrites were pending.** The old column read "Frozen at M1.2; changes expected in M1.5 and M2": frozen, with a diary, for two milestones that have since closed. Both further rewrites are real and neither has a task, which is why nothing contradicted the column.
- **A model that promises a lower layer will not move blocks the work it should protect.** The rule reads as a one-way climb until the reverse is stated: an unfinished layer above is a reason to leave a low layer alone. That half is what a reader considering a container rewrite needs, and it was absent.
- **The section's own vocabulary is already scheduled to change.** M3.4.1's Finding calls this model stale and too shallow and says it re-cuts the model, and T8's row renames the implementation-stack sense of `layer` to `tier`. The content here survives both, since a division and an order do not depend on the word for them, but the table is written in today's vocabulary on purpose.
- **Four rounds of red pen removed two opposite failures.** The first draft was pedantic, the second was chatty; "runs up" and "runs down" survived both because they sounded clear. What replaced them is the build order spelled out, which has no metaphor to decode.

## Completed

- [x] `docs/reference/system_overview.md` `## Architecture Layer Model`: division, two constraints, the rule, the four costs, the three diagnoses, two pointers.
- [x] `project-documentation`: the architecture-document sentence, its pointer, and the status-line bullet's parenthetical.
- [x] `AGENTS.md`: the pointer row retargeted from a freeze status check to the stabilization rule.
