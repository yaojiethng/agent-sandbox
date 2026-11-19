---
date: 2026-11-19
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The units a judgement reads

## Objective

Give the corpus one noun for the size of text a judgement inspects, borrow the sizes from the grammar that names them, and record what is borrowed against what this repository adds.

## Scope

Two vocabularies were in use and neither held the rung this milestone needs. The runbook's scan lists `term`, `sentence`, `passage`, `document`, `artifact` and `corpus`, with no clause, and `grain` carries twenty uses in the tree that mean the size of any work unit, an iteration or a section. The voice rule inspects a clause and the act rule inspects a clause and its type, so both needed a noun that is not a metaphor and not already taken.

The prefactor lands the vocabulary alone. The field on each principle and its gate are a separate row, because a required field over 27 principles is a rollout and not a definition.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `terminology.md` defines `language unit` with two families, the six rungs and the relation inside each. | `grep -n "^## language unit" docs/reference/terminology.md` reads 1, and the entry names `term`, `phrase`, `clause`, `sentence`, `passage` and `document`. | Accepted. |
| The entry states what is borrowed and what is this repository's. | The entry names the rank scale for the sizes and the two families for the split, and `### Relationships` carries the record's path. | Accepted. |
| The citation record holds the four fields and parses. | `node -e 'JSON.parse(...)'` on `.agents/registry/citations/halliday-rank-scale.json` prints ok, and the record's `kept`, `rewritten`, `added` and `dropped` are all non-empty. | Accepted. |
| The runbook's scan reads the language unit and links the entry, with no text unit still called `grain`. | `grep -c "Grain" .agents/skills/instruction-authoring/runbooks/principle-change.md` reads 0, and the entry link reads 1. | Accepted. |
| The purpose ask names the language unit. | `grep -c "the language unit the mechanism reads"` reads 1. | Accepted. |
| The usage paragraph reserves the bare noun and every use that names a language unit carries the term. | `grep -c "never left unqualified" docs/reference/terminology.md` reads 1, and the 14 qualifying edits landed across the two principles, `cut-metadiscourse`, `keep-a-subject-near`, the runbook, the index and the roadmap. | Accepted. |
| The prefactor row is closed with its outcome, the field row is open with its dependency, and the act row names the vocabulary as its dependency. | `grep -c "Name the language units a judgement inspects"` reads 1, `grep -c "Declare the unit on each principle"` reads 1, and the act row carries `Depends on:` the vocabulary. | Accepted. |
| The gates pass. | `scripts/lint.sh` and `scripts/check_document_shape.sh`. | Accepted. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The noun is `language unit`, and bare `unit` stays unreserved. | `unit` already means the roadmap's task unit and the terminology Usage paragraph forbids reserving it; the compound is unambiguous and the field's own word. | `docs/reference/terminology.md`, `## language unit` and `## Usage`. |
| The families are `grammatical units` and `text units`. | The split follows the relation inside each family, composition below the sentence and organization above it, which is what the field distinguishes and what STE's section order already does. | The entry's two Identity lines. |
| `artifact` and `corpus` leave the unit list. | They were never sizes of language; they are what a comparison runs between, and the scan keeps its own vocabulary for that. | The entry's `### Scope`. |
| The citation covers the four syntactic rungs and not the two text rungs. | A citation asserts that we follow a source. The rank scale settles the lower four and no settled scale exists above the sentence, so citing one there would claim a consensus the field does not have. | `.agents/registry/citations/halliday-rank-scale.json`, `dropped`. |
| The field and its gate are deferred to their own row. | A required field over 27 principles is a rollout with a baseline, and this iteration settles the vocabulary a later field needs. | `devlog/roadmap.md`, the field row. |
| The semantic-unit reading was rejected as the family name. | `semantic` names a stratum rather than a size, and a proposition can straddle a sentence boundary, so the label would reintroduce the axis confusion the entry exists to end. | The entry's `### Scope`, and the two-family split. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| No script reads `.agents/registry/citations/`, so a citation record can drift from the tree with nothing reporting it. | Gate gap | A record can claim a source the tree no longer borrows from, and the drift is silent. | Filed as a finding here; not this iteration's subject. |
| STE does carry paragraph rules, 6.4 to 6.6, inside descriptive writing. | Evidence | The earlier claim that STE has no passage rules was wrong, and the entry now cites them, which also shows the standard puts the passage rung inside a writing type rather than in its own section. | The entry's `### Relationships`. |
| The usage rule exposes a second set: the bare noun in the work, test and table senses. | Vocabulary | 73 uses read `the unit` where context carries the sense, so the rule is wider than the language-unit term and needs its own pass. | `devlog/roadmap.md`, the qualification row. |
| `grain` is a different concept from a language unit: it is the fineness of division, so it stays in the four sentences where it means that. | Evidence | Replacing it with the noun changed the meaning, and the entry now states the two apart. | `terminology.md`, `### Relationships`. |
| The `phrase` rung holds no rule in the corpus or in STE's proportional weight, two rules of fifty-three. | Evidence | The list needs the rung for completeness and neither artefact uses it, so a future judgement at that unit is genuinely unowned work. | The entry's `### Relationships`. |

## Completed

| File | One-line change summary |
|---|---|
| [`docs/reference/terminology.md`](docs/reference/terminology.md) | `## language unit` added with its two families, and `## Usage` reserves the compound while leaving bare `unit` ordinary. |
| [`.agents/registry/citations/halliday-rank-scale.json`](.agents/registry/citations/halliday-rank-scale.json) | The rank-scale borrowing, with what is kept, rewritten, added and dropped. |
| [`.agents/skills/instruction-authoring/runbooks/principle-change.md`](.agents/skills/instruction-authoring/runbooks/principle-change.md) | The scan reads the unit and links the entry; the purpose ask names the unit the mechanism reads. |
| [`devlog/roadmap.md`](devlog/roadmap.md) | The prefactor row closed with its outcome, the field-and-gate row opened, the qualification row filed, and the act row given its dependency. |
| Four skills and the registry entry | 29 uses qualified to `language unit` where the referent is a size of text: 14 in `organize-by-diataxis`, 13 in `single-source-of-truth`, 1 in `cut-metadiscourse` and 1 in `keep-a-subject-near`, plus 2 in `terminology.md`. Four edits that had replaced `grain` were reverted, since grain is the fineness of division and not the unit. |
| [`devlog/handovers/M3.3.7/20261119-04-plan-act_rule.md`](devlog/handovers/M3.3.7/20261119-04-plan-act_rule.md) | Retyped Plan and closed, since its implementation is deferred behind this vocabulary. |
