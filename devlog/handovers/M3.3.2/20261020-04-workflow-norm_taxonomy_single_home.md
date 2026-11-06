---
date: 2026-10-20
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# One home for the norm kinds

## Objective

The norm kinds are defined once, in the reference layer, and the policy that applies them points at that home. A second copy is a defect, and the ledger cannot drift from the table.

## Scope

**In scope.** The kind definitions move to `docs/reference/agent_workflow.md` `### Norm kinds`. `documentation_policy.md` `## Rule authority` shrinks to the pointer, the ledger rule and the home pointer. The four ownership norms leave for `principle-one-home-per-rule`. The ledger's kind vocabulary matches the table, and `check_norm_ownership.sh` reads the kind list from the table instead of holding its own copy. The duplicate this created in `principle-check-placement` is removed.

**Out of scope.** Reserving `judgement`, or any other kind name, in `docs/reference/terminology.md`. The item-level reclassification of the rows the census flags. Shipping `testing_policy.md`, which needs a manifest decision.

## Acceptance criteria

| # | Criterion | Class | Result |
|---|---|---|---|
| AC1 | The three kinds, named rule, judgement and description, are stated once in `agent_workflow.md` `### Norm kinds`, and no other document states them | Agent | Agent [x] |
| AC8 | The section states the ladder that classifies a sentence, in order, with the artifact-resolution test as its decisive step | Agent | Agent [x] |
| AC9 | The home is decided by the producer rule, and no document still says a judgement's only home is a principle skill | Agent | Agent [x] |
| AC2 | `## Rule authority` carries the pointer, the ledger rule and the home pointer, and defines no kind | Agent | Agent [x] |
| AC3 | The ledger's kinds equal the reference table's, and the script reads that list from the table | Agent | Agent [x] |
| AC4 | `principle-one-home-per-rule` holds the four ownership norms, byte-identical in both trees | Agent | Agent [x] |
| AC5 | `agent_workflow.md` states the judgement exception beside the sentence that denied it | Agent | Agent [x] |
| AC6 | `scripts/lint.sh` across 10 gates, `check_norm_ownership.sh --check` across 162 rows, the frontmatter gate, and the suite's 1232 tests all pass | Agent | Agent [x] |
| AC7 | The after-census states rows, kinds and observers, and every remaining flagged row is filed | Agent | Agent [x] |

## Decisions

| Decision | Rationale | Recorded in |
|---|---|---|
| Terms go to the reference layer, the classification procedure stays in the policy | All three rules that touch this agree on reference for a term, and the policy workflow produces the procedure | this record |
| Three kinds, not four | The `definition` kind I first proposed rested on a regex count that did not survive inspection, so the case for it did not exist | this record |
| The mechanism split folds into the observer column | `rule-gated` and `rule-reviewed` restated a distinction the observer already carries | this record |
| The kind list is read from the reference table | Two hand-kept copies is the drift this unit exists to remove | this record |
| The kind answers detectability, the home answers the producer | `model`-style coupling of the two emptied the policy layer, because 124 of 162 lines are judgements | this record |
| The classification is a ladder with a resolution test | A fresh classifier given only the table invented an observer for four sentences, so the table needed steps, not a list | this record |
| `judgement` stays ordinary vocabulary | Operator direction, and 46 uses across 7 files make a reservation a tax on every document | this record |
| The third kind is named `description`, not `model` | `model` already names a domain representation in `docs/reference/`, so the kind would be read as a claim about domain models, which it is not | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `docs/development/testing_policy.md` is a policy the image does not ship | pre-existing, deployment | a member the agent cannot read in the container | roadmap row `A policy member that the image does not ship` |
| 12 rows classified `judgement` or `model` name an observer they do not have, and 5 `model` rows ask the reader to act | pre-existing, ledger | item-level reclassification, not a vocabulary problem | roadmap row `Twelve ledger rows name an observer they do not have` |
| A fresh classifier given the table and ten sentences invented a reviewer for the four rows that have no observer | design evidence | the table needed "a guessed observer is not an observer", which it now states | this record's Decisions |
| A sidequest `20261020-05` pauses this record to guard the dispatch seam | interruption | the parent keeps its Active status and resumes after the sidequest closes | the sidequest handover |

## Completed

| Artifact | Change |
|---|---|
| `docs/reference/agent_workflow.md` | `### Norm kinds`, the single home, plus the judgement exception at the point that denied it |
| `docs/policies/documentation_policy.md` | `## Rule authority` reduced from five paragraphs to three statements and a pointer |
| `src/reasoning/providers/pi/config/agent/skills/principle-one-home-per-rule/SKILL.md` | new, the four ownership norms |
| `$AGENT_HOME/agent/skills/principle-one-home-per-rule/SKILL.md` | byte-identical installed copy |
| `src/reasoning/providers/pi/config/agent/skills/principle-check-placement/SKILL.md` | the restated authority rule now points at the reference section |
| `docs/development/prompt-authoring-conventions.md` | the judgement sentence points at the new home |
| `scripts/lint/norm-ownership.tsv` | kinds collapsed to rule, judgement and description across 162 rows; `model` renamed to `description` on 49 |
| `scripts/check_norm_ownership.sh` | reads the kind list from the reference table, fails on a kind the table does not state, and carries no `model` literal |
| `devlog/roadmap.md` | two open rows filed |
