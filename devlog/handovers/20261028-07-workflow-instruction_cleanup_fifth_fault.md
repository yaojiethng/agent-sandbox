---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - the fifth cleanup fault and the enforce remedy

## Objective

Land the two designs the dieted instruction-cleanup prompt held: the fifth fault, **an unneeded instruction**, settled by a deletion run, and the **`enforce`** remedy with its `carrier` field.

## Scope

In scope: `workflow/coding-agent/prompts/instruction-cleanup.md` and the closed roadmap row that states the procedure's fault list. Out of scope: the rest of the diet, which stays a candidate, and the eval case set, which is a row of its own.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The pass names five faults, the fifth settled by a deletion run | `grep -n 'five' workflow/coding-agent/prompts/instruction-cleanup.md`; the deletion-run paragraph | Agent [x] |
| The item shape carries `enforce` and `carrier` | the proposal block | Agent [x] |
| A removal names where the rule lives now | `carrier:` in the item shape, and the paragraph on `enforce` | Agent [x] |
| The roadmap row states five, not four | `grep 'five faults' devlog/roadmap.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| An unneeded instruction is settled by a deletion run, not by provenance | a register shows why a rule was written and never whether it still earns its line; one dispatch runs the procedure without the rule | the prompt |
| `enforce` applies when detection is cheaper than description | a rule a check holds is one check and no prose; a judgement with no check stays prose | the prompt |
| The check lands in the same commit as the deletion | a rule removed before its check exists is a rule lost | the prompt |

## Decisions pending

None.

## Findings

- **The diet recovered 12%, not the 70 to 80% `skill-diet` reports.** Its large recoveries are copied tool documentation, and this prompt has none. What it bought instead: a taxonomy word collision found (`kind` in the census is not `fault` in the judgement) and the removed motivation.

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/instruction-cleanup.md` | the fifth fault, the deletion run, and `enforce` with its `carrier` field |
| `devlog/roadmap.md` | the closed procedure row states five faults |
