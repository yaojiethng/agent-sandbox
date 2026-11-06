---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Design
status: Closed
---

# Handover - decide the two remaining class-2 candidates

## Objective

Decide `j-describe-only-what-is-true` and `j-co-location`, so the duplication map holds no open candidate and the communication-surface filing reads settled sources.

## Scope

The roadmap row **The remaining class-2 candidates**. Two dispositions, each argued against the milestone's split criterion and the map's land test. `j-describe-only-what-is-true` resolves as a new principle, `communication-principle-dont-forecast-undone-work`. `j-co-location` resolves as its own principle, `communication-principle-dont-scatter-what-belongs-together`. Its landing also amends `principle-one-home-per-rule`'s rationale and carries both pointer conversions.

Out of scope: every file of the landing. The skill, the two pointer conversions, the map note, and the per-candidate roadmap row belong to the landing iteration, which the roadmap row requires to be its own.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Each candidate carries a written disposition, with reasons a reader can check against the tree | read the Decisions table below | Agent [x] |
| The roadmap holds one open row per accepted candidate, and the remaining-candidates row is `[x]` | `grep` the three rows: 3 filed, 1 closed | Agent [x] |
| The map's candidate notes name the approved skills, and no note names a withdrawn name | `grep candidate:` returns the two approved names on three rows | Agent [x] |
| The instrument gap is filed as its own row | `grep` the row | Agent [x] |
| The ledger and the gates stay clean | `--check` reads 152 rows; `bash scripts/lint.sh` clean across 10 gates | Agent [x] |
| Every decision this iteration records is realized in the files | read the Decisions table against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `j-describe-only-what-is-true` resolves as a filed principle, not a rejection | its sites state a class of language with a scoped alternative, and two documents already carry the judgement | this record |
| The name is `communication-principle-dont-forecast-undone-work` | operator choice from four shapes; the corpus writes principles as instructions, not labels | this record |
| The domain is the task list's notion of work, and the name presumes no carrier | a name that says "task list" bans a format instead of a class of language, which is the failure the rule itself describes | this record |
| The ban covers a description of undone work, not future tense | a reference document states built behaviour in future grammar, and a hypothesis names its own condition, so neither is a forecast | this record |
| A guess is written as a gap with the check that would settle it | `principle-match-precision-to-stakes` owns the assumption-and-gap form, so the clause points there instead of restating it | this record |
| `j-co-location` resolves as its own principle at the document grain, not a fold and not a structure rule | duplication and scatter are disjoint defects with different remedies, so neither rule can own the other; the paragraph prescribes a decision a writer makes mid-draft | this record |
| Its boundary against `principle-one-home-per-rule` is one clause | a second copy points at the home, where one rule's parts sit together | this record |
| The scatter principle is named `communication-principle-dont-scatter-what-belongs-together` | the object is the relation, not one of the three parts, and "concept" would name a concept document instead | this record |
| The one-home rationale gains duplication as an interpretive hazard | law treats a duplicated provision as a hazard rather than neutral, which names the consequence better than drift alone | this record |
| The one-home amendment lands with the scatter principle, and the forecast principle lands alone | the amendment and the new skill state one boundary from two sides, so separate landings would leave the pair disagreeing; the forecast rule shares no subject with either | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The map's ledger scans two documents, so a judgement also stated in `.agents/skills/task-list/SKILL.md` is invisible to it, which is why this candidate read as class 2 | design gap | a candidate can be misclassified by the instrument that flags it | `roadmap.md` |
| `documentation_policy.md:187` cites "the preamble" for the claim that `roadmap.md` is the only task list, and neither the policy's nor the roadmap's preamble states it | defect | the line cannot stand as written when it becomes a pointer | the scatter landing row, which rewrites that line |
| No repo principle states the general idea; the wider corpus states it once per domain (`technical-writing` per document mode, `design-red-flags` per module) | result | the new principle is the first general statement of it here, and borrows only wording, not rules | this record |
| The organisation aim is served by two rules, not three: conciseness already belongs to `communication-principle-cut-what-carries-nothing` | result | the candidate set shrinks to the scatter rule, and no "organisation" principle is created to connect the two | this record |

## Completed

| File | Change |
|---|---|
| `scripts/lint/norm-judgements.tsv` | three candidate notes renamed to the two approved skill names; no group label changed, so the map report's references still resolve |
| `devlog/roadmap.md` | the remaining-candidates row closed with both decisions named; two landing rows and one instrument row filed |
| `devlog/handovers/20261020-27-design-decide_the_remaining_candidates.md` | this record: seven decisions, four findings, the accepted criteria |
