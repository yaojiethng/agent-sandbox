---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - The derived-state principle

## Objective

Give the judgement corpus the rule the derived-artifact census produced, so a stored copy is judged by what keeps it equal and what ends its life rather than by preference.

## Scope

An operator-directed sidequest, landed ahead of the census it came from (handover `20261023-07`), which waits behind it. Two files: the principle skill, and the sentence that enumerates the holders of the `source` claim.

The judgement is about stored copies. The two neighbours state different objects: `communication-principle-only-derive-what-you-own` judges a number in a sentence, and `principle-single-source-of-truth` judges a rule copied across documents.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| A1 | The skill passes the shape gate | `scripts/check_document_shape.sh` clean, and its count rises from 25 to 26 principle skills | Agent [x] |
| A2 | The claim is declared and the table holds it | frontmatter carries `claim: source`; the table's `source` row states a restated fact is a copy | Agent [x] |
| A3 | A judgement skill sets no `disable-model-invocation` | the frontmatter carries none, per the authoring convention's own rule | Agent [x] |
| A4 | The three filters are ordered and the table grades on them | `## The pattern` lists reproducibility, auditability, cost of derivation as filters applied in order; the classification column carries the four outcomes and the paragraph under the table scores them | Agent [x] |
| A5 | The carrier sentence names three holders | `grep -c 'guard-derived-state' prompt-authoring-conventions.md` returns one, in the `source` sentence | Agent [x] |
| A6 | The prose took the communication pass | one term per thing (copy, value, file); no table sentence repeated in the prose; the test carries the drift question | Agent [x] |
| A7 | Lint and the suite stay green | `bash scripts/lint.sh` clean; `make test` green | Agent [x] |

## Decisions

| # | Decision | Rationale | Where recorded |
|---|---|---|---|
| D1 | The judgement is a new skill, not an addition to a neighbour | Both neighbours state a different object and therefore a different test | this record |
| D2 | The reasons are the domain keywords, in a fixed order with cost last | A lockfile's derivation cost is near impossible, so cost alone would not say to commit it; reproducibility decides first | the skill's `## The pattern` |
| D3 | The table's rows are classifications, not reasons | A reason-keyed matrix repeated what the four classifications already say; one table keeps a single lookup, and the paragraph under it does the scoring | the skill's table |
| D4 | The leading word is `drift` | The pathology is derived-state drift; the operator named it and the census measured it | frontmatter `leitwort` |

## Decisions pending

None.

## Findings

| # | Finding | Type | Impact | Triaged to |
|---|---|---|---|---|
| 1 | Several existing principles set `disable-model-invocation` against the convention's rule | pre-existing corpus defect | a judgement skill drops out of the model's prompt | the roadmap row **The judgement corpus disagrees with its own `disable-model-invocation` rule**; not fixed here |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/providers/pi/config/agent/skills/principle-guard-derived-state/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/principle-guard-derived-state/SKILL.md) | the new principle: three ordered filters, a four-row classification table, and five short parts |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | the `source` sentence names three holders and the object each judges |
