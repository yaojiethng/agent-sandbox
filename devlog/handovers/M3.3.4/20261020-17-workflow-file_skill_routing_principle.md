---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - file the skill-routing principle

## Objective

File `principle-effective-skill-routing` as the judgement's only home, and replace the line that stated it.

## Scope

The roadmap row **File `principle-effective-skill-routing`**. One landing, with its own propagation.

Out of scope: the last landing and the four undecided candidates.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both copies are byte-identical | `diff -q` over the two `SKILL.md` files | Agent [x] |
| The rule speaks of the description, not of pointers, cases or branches | read it: no occurrence of those three words as the rule's subject | Agent [x] |
| The source line points at it | `grep -c principle-effective-skill-routing` in the conventions returns 1 | Agent [x] |
| The skill's own description follows its own rule | read the frontmatter: it names what the skill does and the situations that call for it | Agent [x] |
| The ledger and the map agree with the sources | `--check` and `--groups` clean | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule is stated against the description, not against pointers in a body | pi advertises a name and a description and loads the body after the decision, so a pointer inside a body routes nothing | the skill, opening paragraph |
| The operator-invoked case is inside the skill, not an exception to it | a hidden skill is still routed, by the operator reading a list, so the same rule applies with a different reader | the skill, `## What it does not cover` |
| The word "keyword" stays out of the rule body | "words an agent can match" is the same idea in the words a writer uses, and keyword invites the reader to guess at a mechanism pi does not have | the skill, `## The pattern` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The replaced line was the rule's only statement, and it described pointers rather than descriptions | correction | the rule now matches how a skill actually loads, which the earlier draft did not | the skill |
| The map's grouping for the line stays one site in one document | result | the skill is a class-2 landing, which is why it needed a grill session rather than a duplication finding | this record |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-effective-skill-routing/SKILL.md` | new: the pattern, what it does not cover, why, and the test |
| `~/.pi/agent/skills/principle-effective-skill-routing/SKILL.md` | the installed copy, byte-identical |
| `docs/development/prompt-authoring-conventions.md` | the context-pointer line becomes a pointer to the skill |
| `scripts/lint/norm-ownership.tsv` | regenerated: 152 rows |
| `scripts/lint/norm-judgements.tsv` | regrouped: one row dropped, one added |
| `devlog/handovers/20261020-17-workflow-file_skill_routing_principle.md` | this record |
