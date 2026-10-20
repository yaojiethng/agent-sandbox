---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - file the precision principle, and close the five

## Objective

File `principle-match-precision-to-stakes`, and mark all five landing rows done, which the earlier four landings did not do.

## Scope

The roadmap row **File `principle-match-precision-to-stakes`**, plus the roadmap write-back owed by the four landings before it.

Out of scope: the four undecided candidates, which need the grill session the row **The remaining class-2 candidates** schedules.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both copies are byte-identical | `diff -q` over the two `SKILL.md` files | Agent [x] |
| The four questions are ordered assumption first | read it: the assumption, reach, undo, report | Agent [x] |
| The source line points at it | `grep -c principle-match-precision-to-stakes` in the conventions returns 1 | Agent [x] |
| All five landing rows are marked done with their handover | `grep -c '^- \[x\] \*\*File '` in the roadmap is 6, and none of the five is left open | Agent [x] |
| The gates are clean | `bash scripts/lint.sh`, and `make test` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The examples table is inside the skill | a tight and an open case side by side is what makes stakes concrete, and the skill is their only home | the skill |
| The superseded line's phrase "degrees of freedom" is gone from the pointer | the review rejected both coined terms, and the pointer names stakes and the three questions instead | the conventions |
| The four earlier landing rows are marked done here | each landing owed its own write-back and did not do it; a reader of the roadmap would have seen five rows open for work already committed | the roadmap |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Four landings committed without marking their roadmap rows | lapse, mine | the roadmap understated progress until this record corrected it, which is the state a reader trusts least | this record |
| The frontmatter gate rejected an unquoted colon inside a description | mechanism | a description containing a colon must be quoted or rephrased; rephrasing kept it plain and short | the skill's frontmatter |
| Five landings moved 24 judgement lines out of the two documents and left 10 pointers | result | the ledger went from 162 rows to 152, and the judgement count from 75 to 67, with two skills model-invoked and three operator-invoked | this record |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-match-precision-to-stakes/SKILL.md` | new: four questions, the examples table, assumptions and gaps, what it does not cover, why, and the test |
| `~/.pi/agent/skills/principle-match-precision-to-stakes/SKILL.md` | the installed copy, byte-identical |
| `docs/development/prompt-authoring-conventions.md` | the degrees-of-freedom line becomes a pointer to the skill |
| `scripts/lint/norm-ownership.tsv` | regenerated: 152 rows |
| `scripts/lint/norm-judgements.tsv` | regrouped: one row dropped, one added |
| `devlog/roadmap.md` | all five landing rows marked done, each naming the handover that landed it |
| `devlog/handovers/20261020-18-workflow-file_precision_principle.md` | this record |
