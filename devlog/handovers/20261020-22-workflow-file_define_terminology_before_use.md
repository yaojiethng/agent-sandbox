---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - terminology gets its own principle

## Objective

Split class-2 candidate 2 into two rules that were sharing one line, and file the terminology rule as its own principle with a home.

## Scope

The new skill in both copies, the pointer line that replaces the candidate row, the sentence-structure bullet without its terminology clause, the ledger and grouping the edits move, and this record.

Out of scope: the sentence-structure skill's own wording, which is candidate 2 reopened and stays untouched here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The home states both situations that need a definition | read `## The pattern` | Agent [x] |
| The split of one word into two names is stated | read the third paragraph of `## The pattern` | Agent [x] |
| The test is a pointer, not a memory check | read `## The test` | Agent [x] |
| The terminology clause is gone from the sentence-structure bullet | read line 49 of `documentation_policy.md` | Agent [x] |
| The example stays with the terminology rule | read line 54 of `documentation_policy.md` | Agent [x] |
| Both skill copies are byte-identical | `diff -q` over the two files | Agent [x] |
| The ledger, the grouping and the gates are clean | `--check`, `--groups`, `scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Terminology and sentence structure are two principles | the sentence-structure bullet carried a terminology clause, so one line was doing two rules and the candidate row looked like its duplicate | the two carrier lines, and this record |
| The name is `principle-define-terminology-before-use` | the operator's name names the action an operator recalls from the situation, where the alternative named the test and left the action to be worked out | the skill, frontmatter |
| `defined noun` leaves the policy | it is not a linguistics term, and the standard terms (`definite noun phrase`, `given information`) mean something else, so it claimed a precision it did not have | line 49, and this record |
| The skill is model-invoked | terminology is settled while the work is being written, not as a pass over a finished artifact | the skill, no `disable-model-invocation` |
| The domain-model fork is not edited | the new principle is the general home, but the fork's section carries provenance, so the instance is recorded here instead | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The rejected spec census paired `doc-60` and `doc-61` in one group | evidence | the duplication was visible under the census's own labels, so the split was found late rather than missed | this record |
| The rejected candidate `one-term-one-meaning` states the converse rule | fact | one word for one thing and one meaning per word are two failures, and the policy states only the first | the new skill, and this record |
| `j-ungrouped` fails once its rows come from two documents | process | a new judgement in a second document needs its own named group, because an ungrouped set spanning two documents is a class-1 set with no home | the grouping file, and this record |
| `--regroup` adds rows only after classification | process, recurrence | the order is generate, classify, regroup; the reverse order leaves rows that the gate rejects | this record |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-define-terminology-before-use/SKILL.md` | new: the pattern, what it does not cover, why, and the test |
| `~/.pi/agent/skills/principle-define-terminology-before-use/SKILL.md` | the installed copy, byte-identical |
| `docs/policies/documentation_policy.md` | line 54 becomes the terminology rule with its pointer, and line 49 loses the grafted clause |
| `scripts/lint/norm-ownership.tsv` | both edited lines classified as judgements |
| `scripts/lint/norm-judgements.tsv` | each row grouped singly under a named group with a local note |
| `devlog/handovers/20261020-22-workflow-file_define_terminology_before_use.md` | this record |
