---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - file the no-forecast principle

## Objective

Give the judgement that a description of undone work is a forecast one home, and make both carriers point at it.

## Scope

The roadmap row **File `communication-principle-dont-forecast-undone-work`**, acting on the decision in `20261020-27`. Two carriers state the judgement today: the reference section in `documentation_policy.md` and the changelog rule in the `task-list` convention.

One file joined the scope after the gate: `scripts/check_norm_ownership.sh`. This landing produced the first pointer row in the policy, and the instrument read its group as spanning two documents, so it needed the pointer case rather than a fifth local group.

Out of scope: the scatter principle and the one-home amendment, which is iteration B and has its own roadmap row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill exists in both trees and the copies match | `diff -q` returns nothing | Agent [x] |
| The judgement is stated once in each carrier, as a pointer to the skill | `grep -rn "Move speculative design and TODO items"` returns 0; each carrier names the skill once | Agent [x] |
| The changelog section states it once | the template block no longer carries "No future language"; the pointer closes the paragraph | Agent [x] |
| The map no longer reports the group, and the ledger is clean | `--groups` omits `j-describe-only-what-is-true`; `--check` reads 150 rows, 67 judgement, 45 description | Agent [x] |
| The gates stay clean | `bash scripts/lint.sh` clean across 10 gates | Agent [x] |
| The roadmap row closes with its landing note | `grep` the row | Agent [x] |
| A pointer row cannot share a group with a statement | negative test (a) below | Agent [x] |
| A pointer row cannot carry a skill note | negative test (b) below | Agent [x] |
| A statement that merely uses the words still counts as a statement | negative test (c) below | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The skill's rule is one sentence, and the guess becomes a pointer | `principle-match-precision-to-stakes` owns the assumption and the gap, so a second statement here would be a duplicate | the skill's `## Where another rule wins` |
| The reference section keeps its word list as a fast path | one-home allows a fast path while it names the home, and the words are the reader's first signal | `documentation_policy.md` |
| The dangling "per the preamble" goes with the rewrite | it cited text that neither preamble carries, so the line could not stand as a pointer either | the same rewrite |
| A pointer row is local by construction, and the gate computes it | a pointer cites a home instead of stating a judgement, so it must not raise a group's document count | `check_norm_ownership.sh` `groups()` |
| `20261020-27` closes in this commit rather than its own | operator direction: land the two pieces of work as two iterations, with no design commit | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|
| The instrument had no pointer case, so a citation raised its group's document count | design gap | the same misclassification the map's class-2 rule exists to prevent, arriving from the other side | fixed in this iteration |
| Pointer detection read one wording, so three quotation lines still counted as sites | defect | found by the reviewer; the class-1 check could read a two-document group as local | fixed in this iteration, on a test of a judgement sentence plus a skill path |
| `.agents/audits/architecture-doc-reviewer.skill.md` stated the judgement, outside the ledger's scan set | defect | a second carrier the map could not see | fixed in this iteration |
| The `task-list` changelog section stated it twice, in the template block and again one screen below | defect | the landing's own criterion failed until the template lost the sentence | fixed in this iteration |
| The map's `j-ungrouped` group held ten citations and one statement | defect | a junk-drawer group that mixed the two kinds the gate now separates | fixed in this iteration: the citations moved to `j-pointer-rows` |
| `check_norm_ownership.sh` scans two documents, so a judgement carried by a convention skill is invisible | design gap | already filed as its own roadmap row in `20261020-27` | `roadmap.md` |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md` | the skill, new |
| `~/.pi/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md` | the installed copy, byte-identical |
| `docs/policies/documentation_policy.md` | one layer sentence, one fast path of forecast markers, one pointer |
| `.agents/skills/task-list/SKILL.md` | the template block lost "No future language"; the pointer closes the paragraph |
| `.agents/audits/architecture-doc-reviewer.skill.md` | the reference check now names the skill |
| `scripts/check_norm_ownership.sh` | a pointer row is local and counts no document; a group mixing a pointer with a statement fails |
| `scripts/lint/norm-ownership.tsv` | regenerated: 150 rows |
| `scripts/lint/norm-judgements.tsv` | the ten citation rows consolidated into `j-pointer-rows` with the note `-`; the header states the rule the gate applies |
| `devlog/roadmap.md` | the landing row closed |
| `devlog/handovers/20261020-27-design-decide_the_remaining_candidates.md` | closed in this commit |
| `devlog/handovers/20261020-28-workflow-file_the_no_forecast_principle.md` | this record |

## Negative tests

Three behaviours, each run on the landing's own files and then restored to green.

(a) A pointer row moved back into a real group:

```text
norm-ownership: group j-ungrouped holds 1 pointer row(s) and 1 judgement row(s), so a citation and a statement share one group
```

(b) A pointer row given a skill note:

```text
norm-ownership: pointer row in group j-pointer-rows carries the note skill:communication-principle-dont-forecast-undone-work, and a pointer states no judgement: 5. **The handoff.** A runbook that ends by handing to anothe
```

(c) A statement that uses the words without a skill path stays a statement, so the class-1 check cannot be hidden:

```text
cited:no -> statement(counted)
cited:yes -> pointer(skipped)
```
