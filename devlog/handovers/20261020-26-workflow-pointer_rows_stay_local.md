---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - the map states its pointer-row rule and enforces it

## Objective

Settle where a pointer row belongs in the judgement map, and make the answer a check rather than a convention that each landing re-decides.

## Scope

One header line in `scripts/lint/norm-judgements.tsv`, one row moved, one check in `scripts/check_norm_ownership.sh`, and this record.

Out of scope: the classes themselves, and the eleven pointer rows that already sat local.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The map states the rule | read the fourth comment line | Agent [x] |
| The routing row no longer sits in a group of another judgement | read its row: group `j-skill-routing-pointer`, note `-` | Agent [x] |
| The check fails when a pointer row joins a group | negative test below | Agent [x] |
| The check passes on the current map | `--groups`, `--check`, `scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A pointer row stays local | it names where a judgement lives instead of stating one, and a group counts judgements a document states | the map header |
| The rule is enforced | the convention was decided twice in two landings before it was written down, so a statement alone would be decided a third time | `scripts/check_norm_ownership.sh`, `groups()` |
| The check reads the text, not a maintained list | a pointer row is recognisable by the sentence it ends with, so no second list can drift from the first | the same function |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The routing row's note named a home its own text did not | defect | the note claimed `principle-one-home-per-rule` while the row named `principle-effective-skill-routing`, so the map recorded a false pairing | the moved row |
| The first negative test changed only the group, so the gate passed | process | a negative test that alters the wrong field proves nothing, and the check reads the note | this record |
| The map is agent-maintained and needs no operator ruling | fact | the file records evidence the agent produces, so a question about its internal convention is the agent's to answer | this record |

## Completed

| File | Change |
|---|---|
| `scripts/lint/norm-judgements.tsv` | the pointer-row rule in the header, and the routing row moved to `j-skill-routing-pointer` with note `-` |
| `scripts/check_norm_ownership.sh` | `groups()` fails when a pointer row joins a group |
| `devlog/handovers/20261020-26-workflow-pointer_rows_stay_local.md` | this record |

## Negative test

Setting the routing row back to `j-copy-points-to-its-source` with note `skill:principle-one-home-per-rule` produced:

```text
norm-ownership: pointer row joined group j-copy-points-to-its-source, and a pointer states no judgement: **Skill names and descriptions route a skill.** A skill is a
```

Restoring the row returned the gate to green.
