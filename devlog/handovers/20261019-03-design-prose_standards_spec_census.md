---
date: 2026-10-19
milestone: M3.3.4 - The prose standards as principles
type: Design
status: Closed
---

# Handover - the prose-standards principle spec census

## Objective

Plan the two prose standards into principle specs: resolve every judgement line of both source documents to a spec or a stay, and name one principle per judgement.

## Scope

The three roadmap rows **Plan the `communication` standard into principle specs**, **Plan the prompt-authoring conventions into principle specs**, and **Dedupe the two plans** in [`devlog/roadmap.md`](../roadmap.md). The deliverable is a draft design, [`20261019-design-draft-prose_standards_specs.md`](../discussions/20261019-design-draft-prose_standards_specs.md); the rows stay open until the operator settles it and its specs file as their own rows.

Out of scope: filing the 12 proposed principles, which is the settled plan's work; the `closed_record_corrections.md` assessment stays open.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The census resolves all 80 judgement lines of both source documents | `awk -F'\t' '$3=="judgement" {n++} END{print n}' scripts/lint/norm-ownership.tsv` prints 80; the two census tables carry one row each | Agent [x] |
| Each proposed spec names its principle, one-line statement, and source lines | read `### Proposed principle set` in the census | Operator [ ] |
| Dedupe names one principle per judgement | read `### Dedupe`; seven groups | Agent [x] |
| The operator settles the draft and confirms the 12 names | operator review of the census | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A judgement becomes a principle only when it states a decision about what to say or keep; a shape, placement, process step, or obligation stays | the split criterion resolves each row to one side, so a judgement row is not automatically a spec | the census, `### Resolution rule` |
| The census proposes 12 new specs and routes 2 rows to filed skills | 30 judgement rows collapse into 12 judgements; the other 48 stay | the census, `### Proposed principle set` |
| The three ASD-STE100 specs are flagged as the structure boundary | if the operator reads plain wording, term consistency and clause order as sentence shape, they stay and the count drops to 9 | the census, `## Consequences` |
| Each spec files as its own roadmap row when the plan settles | the plan row's own text requires it; a draft is not yet a settled decision | the roadmap plan rows |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does the operator accept the 12 spec names and the two filed absorptions? | filing the spec rows and the principles | accept as proposed; rename; move the three STE specs to the stay column |

## Findings

| Finding | Type | Impact |
|---|---|---|
| 30 of the 80 judgement rows state 12 judgements; the rest are shape, placement, or process. | result | the principle tranche is smaller than a row-per-judgement count suggests |
| The two source documents restate some judgements in more than one section; the dedupe table names each. | result | one judgement, one principle, one name |
| The census reads as a draft, and the source line refs are the current line numbers, so an edit to a source document retires its ref. | limitation | the ledger's hash key is the stable identity; the census quote is the citation |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261019-design-draft-prose_standards_specs.md` | new draft design; the spec census, the 12 proposed principles, the dedupe, and the stay rows |
| `devlog/roadmap.md` | the two plan rows and the dedupe row note the draft census and its settlement gate |
