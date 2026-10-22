---
date: 2026-10-21
milestone: M3.3.2 - Retire the policy form
type: Housekeeping
status: Closed
---

# Handover - The policy form's closing condition

## Objective

Make M3.3.2's closing condition decidable and its rows state one outcome each, so the milestone can close on its own terms.

## Scope

The roadmap row **The `Retire documentation_policy` entry is malformed**, which is M3.3.2's own first row and the reason its `Sequencing:` line states it first. The row names three defects and one beneath them, and all four are repaired here: the phantom destination, the restated map, the ending clause that duplicates the milestone's acceptance criterion, and the fact that the slice retires the document whose section the same row declares a survivor.

The survivor question needs no decision. `principle-single-source-of-truth` states both halves: a bridge document is a duplicate with extra steps, to be collapsed into the more relevant of the two and the pair linked directly, and a policy file that owns no rule is misnamed. So `documentation_policy` is not held open while its rules wait for owners; each judgement line is folded into its owner in the slice, and the milestone's first acceptance criterion becomes the ledger query that counts the lines still unsourced. The ADR's two-document conclusion is corrected in place, because phase A filed the judgements as `communication-principle-*` skills and `20261020-32` gave the structure rows to `linking`, `docs` and the gates.

The scalar moves to M3.3.2 with this row, per the `2026-10-21` decision bullet that the scalar follows the rows in work, and returns to M3.3.4 when phase B resumes.

Three further findings from the maintenance check live in M3.3.2's own section, so they are part of the task: the `Sequencing:` line routes a row this unit closes, the parent row states no completion context, and M3.3.3's dependency line attributes the prose standards to M3.3.2 rather than M3.3.4.

Ruled out of scope with a destination each. The rest of the maintenance report is the compaction family, rows that carry counts and narrative and the duplicate class-2 rows, which `/milestone-close` owns at milestone grain; the summary table's statuses disagree with the single-scalar frontmatter, which is M3.5's subject. Neither is touched here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| M3.3.2's first accepted criterion is the census query rather than a list of survivor documents, and the query runs as stated | `grep -n "census decides it" devlog/roadmap.md` returns one line; running the `awk` it carries prints 26 ledger rows, every one sourced from `docs/policies/documentation_policy.md`, which is the milestone's remaining work. The criterion asks for no output at close, and the query is what reports it | Agent [x] |
| The live plan names no `communication` standard as a surviving document, and the two records that state the old conclusion carry a dated amendment beside it | ``grep -c '`communication` standard' devlog/roadmap.md`` returns 0; `grep -rn "Amended 2026-10-21\|Revised 2026-10-21" docs/adr/coding_agent_project_bindings.md devlog/discussions/20261014-design-settled-retire_the_policy_form.md` returns one line each | Agent [x] |
| The `Retire documentation_policy` sub-row names owners instead of a phantom, its end state is the census, and it runs after the standard that owns seven of its rows; the plain-wording row is sequenced before it | ``sed -n '/Retire `documentation_policy`/p' devlog/roadmap.md`` names `communication-principle-*`, `## Prohibited content`, `doc-maintenance` and `docs`, with `Runs after the plain-wording standard`; ``grep -o "before the `documentation_policy` retirement[^.]*" devlog/roadmap.md`` returns the plain-wording row's clause | Agent [x] |
| The malformed row closes, cites the design record for the map, and carries no ending clause; the `Sequencing:` line routes only open rows and M3.3.3's dependency names M3.3.4 | ``sed -n '/The `Retire documentation_policy` entry is malformed/p' devlog/roadmap.md`` starts `- [x]`, cites `20261014-08` and holds no `Ends when`; `grep -c "authority-doctrine row" devlog/roadmap.md` returns 0; `grep -c "prose standards \[M3.3.2\]" devlog/roadmap.md` returns 0 | Agent [x] |
| The umbrella is clean | `bash scripts/lint.sh` prints `Lint: clean` | Agent [x] |

## Decisions

None. The bridge rule decided the survivor question, so this unit records no decision of its own.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The maintenance check ran twice, before the scope and again at pre-close: eleven findings, then five. Six live in the sections this unit rewrites and are applied with it: the `Sequencing:` line routed a row the unit closes, the parent row stated no completion context, M3.3.3's dependency credited M3.3.2 for the prose standards, the milestone's second and third criteria restated end states that two rows own, three slice orders contradicted each other, and `seven` was a count I derived and did not own | result | the check's subject is the roadmap's agreement with the tree, and every one of these sat in text this unit was already correcting | fixed in this unit |
| Eight maintenance findings are the compaction family: closed rows carrying counts and narrative, a parent whose children are all done and uncompacted, two closed rows covering one subject, an open row pinning `SKILL.md:42` and `INTERFACE-DESIGN.md:21`, and five M3.3.3 rows carrying a one-space indent that names no parent | result | each states a fact the tree can falsify or a position that moves, and none is M3.3.2's closing condition. `/wrapup` hands compaction and the milestone-record close to `/milestone-close` | `/milestone-close`, which runs compaction at milestone grain |
| The summary table's status for three sub-milestones that hold closed rows reads `Not started`, and the single-scalar frontmatter names one milestone while two are in work | defect | the mismatch is the subject of the row that replaces the scalar with a set, so repairing the statuses here would be a second fix for one defect | M3.5, whose parallel-milestone row owns it |
| The word pass left one `home` in the roadmap, `after a repository home exists for the subsumed skill`, which the sweep missed because it ran over six roots and the roadmap is not one of them | defect | the pass's own criterion named the roots it scanned, so a carrier outside them reads as clean. The line is corrected here. It is the class `devlog/AGENT_FEEDBACK.md` already holds as **A gate that hand-lists its subject set misses a live root**, so it is a recurrence, not a new finding | the feedback entry for that class, which now carries the recurrence and the sweep's own rule |
| The previous unit's record repeats one ruling in its Scope's ruled-out paragraph: the sentence about the drafts under `.agents/drafts/` appears twice, in two wordings, the second weaker than the first | defect | a reader meets the same ruling twice in a record that shipped, and the second wording says less | corrected here, because a duplicated sentence in a record this session wrote is cheaper to delete than to route |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | twelve edits: the scalar, the `Sequencing:` line and the slice order it states, the milestone's first criterion as a census query, its second and third replaced by a pointer to the rows that own those end states, the parent row's completion context with its method restatement dropped, the sub-row's owners and order, the malformed row closed, M3.3.3's dependency line, the plain-wording row's sequencing, and M3.3.4's objective reworded to name the section it files rather than a standard that does not exist |
| [`coding_agent_project_bindings.md`](../../docs/adr/coding_agent_project_bindings.md) | `Amended 2026-10-21` in the policy-form entry's decision, beside the conclusion it revises. No new entry and no `**Current:**` bump: the file amends a clause with a date in place, as requirement R2 already does, and a new dated entry would mark the subtraction decision superseded when only its survivor count moved |
| [`20261014-design-settled-retire_the_policy_form.md`](../discussions/20261014-design-settled-retire_the_policy_form.md) | one supersession pointer at the fate it revised |
| [`20261021-09`](20261021-09-workflow-source_of_truth_word.md) | the duplicated Scope sentence |
