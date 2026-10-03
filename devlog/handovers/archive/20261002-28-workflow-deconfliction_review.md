---
date: 2026-10-02
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - The deconfliction review across the two maps

## Objective

Read the settled policy map against the settled procedure map and expose what neither pass could reach alone: a rule with no home, a rule with two, and a procedure that restates a rule a policy already owns. Then land the moves the join proves.

## Scope

The third and last row of the campaign. The policy map mapped the rule layer alone; the procedure map mapped the procedure layer alone. Each is internally complete and neither can see a defect that spans the two, because a spanning defect looks correct from either side.

| In | Out |
|---|---|
| The join: rule rows against step rows, on their shared subject | Re-opening either map's settled verdicts |
| The three named classes: no home, two homes, a procedure restating a policy | The 4 `point` verdicts already filed as roadmap row 109 |
| The class neither map names: a rule the policy layer owns and no gate can enforce | Narrowing the convention or deleting the links, which finding 3 raises |
| The citation sweep across every prompt and skill, not only the 46-mention shortlist | Milestone-close bookkeeping -- compaction, changelog, promotion |
| Land the moves the join proves | A new gate. A gate is a workflow change, not a review output |

**Maps read.** The 196-rule policy map and the 235-step procedure map -- working documents of the campaign, not retained.

**Pre-flight findings already in hand, all pre-existing and outside iteration `20261002-27`'s changed surface:**

| # | Finding | Provenance |
|---|---|---|
| 1 | `roadmap-maintenance.md` cites `iteration_policy.md` `### Unconditional write-back`, which is a bolded bullet inside `### Close invariants`, not a heading | `1d3aefa` |
| 2 | `iter.md:61` carries the tree's only `Range-read` directive, inside a `text` block, linking a path that resolves nowhere at runtime | `aaa1246` |
| 3 | `prompt-authoring-conventions.md` `## A prompt names a record, it does not link it` is contradicted by 58 `docs/` links across 9 prompts, whose form the record-links gate enforces and passes | live |

Findings 1 and 2 are defects in a pre-existing surface, so the Defect resolution rule makes them new work rather than this iteration's to fix, and they fold into this unit because the review covers their class. Finding 3 is a collision to report, not to resolve.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | Every rule row is read against the step rows that share its subject, and every step row against the rule rows, with no row silently dropped | the join names both sides; a row on neither side is named as such | met -- 19 shared subjects named on both sides; the residue is named by group |
| 2 | Each of the three named classes is reported with evidence, or stated empty | one section per class, each naming its instances | met -- class 1 empty; class 2 one live instance, fixed; class 3 empty; class 4 named with five rules |
| 3 | The citation sweep covers every prompt and skill, and every unresolvable citation is fixed or filed with its reason | the sweep script's count and the list of survivors | met -- 32 files, 158 inline citations, 0 unresolvable; 3 fenced links are illustrative examples in a format template |
| 4 | Finding 3 is reported as a collision and left unresolved | the finding names both rules and the gate that enforces the weaker, and no link is deleted | met -- 94 `docs/` citations across 12 files; no link deleted |
| 5 | The moves the join proves land, and the gates stay green | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | met -- lint clean across 5 gates; 1038 of 1038 tests passed |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | finding 3's convention |
| [`workflow/coding-agent/skills/roadmap-maintenance.md`](../../workflow/coding-agent/skills/roadmap-maintenance.md) | finding 1 |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | finding 2 |
| [`scripts/lint/record-links.mjs`](../../scripts/lint/record-links.mjs) | the gate that enforces the weaker rule in finding 3 |

## Decisions

| # | Decision | Rationale | Recorded |
|---|---|---|---|
| 1 | The review's findings are recorded in this handover, not a persisted report | the maps and the report were working documents for the campaign and are not retained | this handover |
| 2 | Pre-flight finding 1 needs no fix and no row | iteration `20261002-27` already corrected the citation; the handover finding describes the pre-fix tree | this handover |
| 3 | Finding 2's `Range-read` directive is retired to prose that names the record | the tree's only instance; no convention defines the directive, and the prompt-authoring convention allows a named record in plain text | `iter.md` |
| 4 | The missing-document duplicate resolves by a pointer in `study_policy` | `documentation_policy` owns the rule; the two texts say the same thing in the same words | `study_policy.md` |
| 5 | Class 4's ungated rules stay with their maintenance skills; no gate is added | a new gate is out of scope, and each rule already has a scheduled maintenance check | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The join names 19 subjects on both sides; the residue (policy-only rules with no procedure, and procedure-only steps with no rule) has no counterpart by design | analysis | recorded in this handover |
| Class 1 is empty: every no-home row from either map now has a home | gap | closed by this campaign's gap fills |
| Class 2 has one live instance: the missing-document rule is stated in `documentation_policy.md` and again in `study_policy.md` | contradiction | fixed in place -- `study_policy` now points |
| Class 3 is empty against the tree: iteration `20261002-27` dropped all 30 runbook restatements, and the live runbooks point at the owner | contradiction | closed by `20261002-27` |
| Class 4 -- a policy-owned rule no gate can enforce -- names five rules, each relying on a maintenance skill: the duplicate-content test in `documentation_policy.md` Rule authority, the three-files-one-record rule in `roadmap_policy.md` One record, the targeted-change rule in `roadmap_policy.md` timing invariant, the no-`## Deferred` rule in `handover_policy.md` Format, and the prompt-names-a-record rule in `prompt-authoring-conventions.md` | gap | filed: each rule keeps its maintenance check; no new gate |
| Finding 3: `prompt-authoring-conventions.md` forbids a prompt from linking a record, while the `record-links` gate requires the link to resolve; 94 `docs/` citations across 12 files are live on disk and dead at runtime | contradiction | reported, unresolved. Triaged to: roadmap.md -- *Establish the dependency convention for seeded documents* |
| `record-links` was registered but enabled nowhere, so the gate named by `documentation_policy` never ran and reported a clean tree over an empty rule set | bug | fixed in place -- the rule is enabled and a two-direction guard now warns on a registered-but-unenabled rule |
| The citation sweep found 158 inline citations across 32 prompt and skill files and 0 unresolvable | analysis | recorded in this handover |
| Four `point` verdicts name a restating document outside both maps' shortlists | gap | already filed as an open roadmap row |

## Completed

| File | Change |
|---|---|
| `.markdownlint-cli2.mjs` | enabled `record-links` with the shared `recordTrees` list |
| `scripts/check_markdown.sh` | added the two-direction rule-registration guard |
| `tests/test_lint_umbrella.sh` | declared the guard's cases |
| `docs/operations/documentation_policy.md` | recorded `record-links` in the lint rule set and the registered-but-unenabled defect |
| `docs/operations/roadmap_policy.md` | removed the changelog snippet-handover procedure, which moves to its runbook; ASCII dashes |
| `docs/operations/study_policy.md` | replaced the restated missing-document rule with a pointer |
| `workflow/coding-agent/prompts/iter.md` | removed the `Range-read` directive and the dead Markdown link; named the record in prose |
| `workflow/coding-agent/prompts/milestone-close.md` | named the `changelog` fence label the moved snippet procedure produces |
| `workflow/coding-agent/skills/roadmap-maintenance.md` | corrected the close-invariants citation |
| `workflow/coding-agent/audits/surface-area-report.md` | repointed the retired roadmap-audit row at the maintenance skill |
| `devlog/roadmap.md` | marked the deconfliction-review row landed; repaired six record-format defects |
| `devlog/handovers/archive/20261002-23-plan-m3_1_submilestones_and_precommit_runbook.md` | repaired a broken relative link and a stray marker |
| `devlog/changelog.md` | removed a duplicated separator |
