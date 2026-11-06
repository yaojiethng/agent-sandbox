---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - file the done-criteria principle

## Objective

File `principle-say-what-done-looks-like` as the judgement's only home, model-invoked, and leave the conventions pointing at it.

## Scope

The roadmap row **File `principle-say-what-done-looks-like`**. One landing, with its own propagation.

Out of scope: the two remaining landings and the four undecided candidates.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both copies are byte-identical | `diff -q` over the two `SKILL.md` files | Agent [x] |
| It is model-invoked | no `disable-model-invocation` field, and its description names the situations that call for it | Agent [x] |
| The two source lines point at it | `grep -c principle-say-what-done-looks-like` in the conventions returns 2 | Agent [x] |
| The reference-region distinction survives | both pointers keep it: a reference region has no step to finish | Agent [x] |
| The ledger and the map agree with the sources | `--check` and `--groups` clean | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The skill keeps the three kinds of criterion | the mechanical case, the case where the work builds the instrument, and the judgement case are the whole of it; dropping the middle one would leave checker-building unbounded | the skill, `## The three kinds of criterion` |
| The description spends its words on situations | the skill is model-invoked, so its description is the only thing that decides whether it loads; the rule it states applies to itself | the frontmatter |
| The reference region kept a clause of its own | without it, a reader would look for a finish condition on a list of rules consulted on demand, which has none | both pointers |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The rule applies to itself and the skill is model-invoked | result | the description names starting a task, a step, a segment, and reporting complete, which are the situations an agent is in when it needs this | the frontmatter |
| The ledger row count held at 152 while two rows were replaced | result | the landing swapped two judgement lines for two pointers, so the total is stable and the judgement count with it | this record |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-say-what-done-looks-like/SKILL.md` | new: inventory and bound, the criteria and their verification, the three kinds, why, and the test |
| `~/.pi/agent/skills/principle-say-what-done-looks-like/SKILL.md` | the installed copy, byte-identical |
| `docs/development/prompt-authoring-conventions.md` | the runbook definition and step 4 point at the skill |
| `scripts/lint/norm-ownership.tsv` | regenerated: 152 rows |
| `scripts/lint/norm-judgements.tsv` | regrouped: two rows dropped, two added |
| `devlog/handovers/20261020-16-workflow-file_done_criteria_principle.md` | this record |
