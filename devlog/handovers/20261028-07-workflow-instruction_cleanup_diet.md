---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - the cleanup prompt is replaced by the dieted pass

## Objective

Replace the live cleanup prompt with the dieted rewrite it had been a candidate for: five faults including **an unneeded instruction** settled by a deletion run, the **`enforce`** remedy with its `carrier` field, and the motivation, non-goals history and duplicated fault list cut.

## Scope

In scope: `workflow/coding-agent/prompts/instruction-cleanup.md`, which the dieted draft replaces in full, and the closed roadmap row that states the procedure and its faults. Out of scope: the eval case set, which is a row of its own.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The pass names five faults, the fifth settled by a deletion run | `grep -n 'five' workflow/coding-agent/prompts/instruction-cleanup.md`; the deletion-run paragraph | Agent [x] |
| The item shape carries `enforce` and `carrier` | the proposal block | Agent [x] |
| A removal names where the rule lives now | `carrier:` in the item shape, and the paragraph on `enforce` | Agent [x] |
| The roadmap row states five, not four | `grep 'five faults' devlog/roadmap.md` | Agent [x] |
| The live prompt is the dieted rewrite, not a candidate beside it | the prompt carries the draft's structure: the order of work, the census keyed by site, the categories and the fold | Agent [x] |
| The motivation, the non-goals history and the duplicated fault list are gone | read the prompt | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| An unneeded instruction is settled by a deletion run, not by provenance | a register shows why a rule was written and never whether it still earns its line; one dispatch runs the procedure without the rule | the prompt |
| `enforce` applies when detection is cheaper than description | a rule a check holds is one check and no prose; a judgement with no check stays prose | the prompt |
| The check lands in the same commit as the deletion | a rule removed before its check exists is a rule lost | the prompt |
| The draft replaces the live prompt rather than staying a candidate | operator direction on 2026-10-28: the two designs had already landed, and the diet is the rest of the same edit | this record |
| The description names the trigger, not the faults | at invocation the faults have not been checked; the invoker knows only that the surface is bloated or coupled | the prompt's description |

## Decisions pending

None.

## Findings

- **The diet recovered 12%, not the 70 to 80% `skill-diet` reports.** Its large recoveries are copied tool documentation, and this prompt has none. What it bought instead: a taxonomy word collision found (`kind` in the census is not `fault` in the judgement) and the removed motivation.

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/instruction-cleanup.md` | replaced in full by the dieted pass: the order of work, the census keyed by site, the categories, the five-fault judgement, the screen and the fold, with `enforce` and `carrier` |
| `devlog/roadmap.md` | the closed procedure row states five faults |
