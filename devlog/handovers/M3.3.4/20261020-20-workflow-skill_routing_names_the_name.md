---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - the routing principle covers the name

## Objective

Amend `principle-effective-skill-routing` so it governs a skill's name as well as its description, and answer whether pi routes on the name.

## Scope

The skill in both copies, its one pointer line, and the ledger and grouping the edit moves.

Out of scope: renaming any existing skill, and the four candidates still awaiting their grill session.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill states what the name carries, for which readers | read `## The name` | Agent [x] |
| The collision rule is stated | read the second paragraph of `## The name` | Agent [x] |
| A rename is stated as a change with a carrier list | read the third paragraph of `## The name` | Agent [x] |
| The test opens on the name alone | read `## The test` | Agent [x] |
| The pointer line no longer says only the description routes | read the line in `prompt-authoring-conventions.md` | Agent [x] |
| Both skill copies are byte-identical | `diff -q` over the two files | Agent [x] |
| The ledger, the grouping and the gates are clean | `--check`, `--groups`, `scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule covers the name and the description, and the title says so | the name is advertised beside the description, it is what an operator recalls, and it is the only part another document can cite | the skill, title and opening line |
| The open question is answered from the documentation rather than hedged | pi adds each skill's name, description and path to the system prompt, so the name sits in the context the routing decision is made in | the skill, `## Why` |
| The collision rule is stated | the first discovered skill keeps a duplicated name and the second does not load, so a collision costs the skill rather than the name | the skill, `## The name` |
| The name is stated as the description's summary, not as a paraphrase of the body | a name that summarises the description serves the agent, the operator and the citing document at once | the skill, `## The pattern` |
| The pointer line is widened with the rule | the line said the description routes a skill, which the amendment makes incomplete | `prompt-authoring-conventions.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The docs assign the routing role to the description, but put the name in the same context at startup | fact | the name cannot be kept out of the routing decision, so a rule about routing that ignores it is incomplete | the skill |
| The source documents are not scanned by the ledger, so only the pointer line moved a row | result | one ledger row changed kind from none to judgement, and the grouping gained that hash in `j-copy-points-to-its-source` | the ledger and the map |
| A skill's own lines are outside the ledger | fact | editing a skill never moves a ledger row, so a landing that touches only skills is a one-file change plus its record | this record |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-effective-skill-routing/SKILL.md` | the name section, the widened title and description, and a test that opens on the name |
| `~/.pi/agent/skills/principle-effective-skill-routing/SKILL.md` | the installed copy, byte-identical |
| `docs/development/prompt-authoring-conventions.md` | the pointer line says the name and the description route a skill |
| `scripts/lint/norm-ownership.tsv` | the edited line classified as a judgement |
| `scripts/lint/norm-judgements.tsv` | the hash grouped under `j-copy-points-to-its-source` |
| `devlog/handovers/20261020-20-workflow-skill_routing_names_the_name.md` | this record |
