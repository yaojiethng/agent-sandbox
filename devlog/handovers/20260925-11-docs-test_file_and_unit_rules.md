# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Documentation
**Status:** Closed

## Objective

Write the placement and unit-quality rules the rectification campaign files by: the file-and-unit sentence in the test placement policy, and two anti-patterns in the testing conventions.

## Scope

[`docs/development/testing_policy.md`](../../docs/development/testing_policy.md) gains one subsection under Test Placement; [`docs/development/testing-conventions.md`](../../docs/development/testing-conventions.md) gains one form in Anti-Pattern 6 and one new Anti-Pattern 9. No code, no test-file change, and no register status change: the rules are written, the units have not moved.

## Carried forward

None.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The placement rule names the file name as the lookup and forbids a roster | reading the new subsection | Agent [x] |
| Anti-Pattern 9 states symptom, example, and rule, and its example units exist | `grep` over the named file | Agent [x] |
| Anti-Pattern 6 carries the removed-design form with a real example | the header and the two named units in `tests/test_confirm_workflow.sh` | Agent [x] |
| No roster or index is introduced | inspection: no table of files added to either doc | Agent [x] |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |
| The suite is untouched | `bash scripts/run_tests.sh` | Agent [x] - 785 units, unchanged |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/development/testing_policy.md`](../../docs/development/testing_policy.md) | new subsection "The file and the unit" |
| [`docs/development/testing-conventions.md`](../../docs/development/testing-conventions.md) | Anti-Pattern 9, and the removed-design form in Anti-Pattern 6 |
| [`devlog/roadmap.md`](../roadmap.md) | names the rules as landed and the campaign as the next unit |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The organisation rule is one sentence, not a rule set | it creates no list, no file, and no gate; the corpus already obeys it, so the sentence codifies rather than imposes | this handover and the policy |
| The sentence lives in `testing_policy.md` Test Placement, not in the conventions doc | that section already decides which directory a test belongs in; one section answering "where does this test go?" is one lookup, and splitting directory from file would create a second | the policy |
| No roster of which file covers what, and no consistency duty on the `Covers:` headers | the file name is the lookup; a roster goes stale and needs a gate to stay true, which is the retired `project_index.md` one level down | the policy and this handover |
| The duplicate rule is a new anti-pattern, the removed-design rule an added form in Anti-Pattern 6 | the removed-design form is the same defect as the change-mirror string pin, one level up; the duplicate unit has no existing home | the conventions doc |
| The register's rows 3, 52, 73, 147, 164, 172, 248 and 281 stay open | the rule is written and the units still sit where the rows found them | the register |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The read-through's phase 2-4 pass wrote finding numbers into test-file header comments (`tests/test_routing.sh` cites "finding 52" twice, at its duplicate pair and its files-ignored clause). When the campaign closes those rows, each comment points at a closed row. | record coupling | a decision for the campaign's first slice: either the comment states the behaviour without the row number, or the campaign updates the number as it closes the row |
| Row 3's part (c), the naming drift (`tests/test_apply_count.sh` named for a metric rather than a subject), is covered by the new sentence but has no evidence row of its own. | coverage | none; recorded so the campaign's rename is not read as invention |

## Completed

| File | Change |
|---|---|
| `docs/development/testing_policy.md` | Test Placement gains "The file and the unit": a test file is named for its subject and holds that subject's units, the file name is the lookup, and no roster of which file covers what is kept |
| `docs/development/testing-conventions.md` | Anti-Pattern 9 (the duplicate unit: one unit per case, fold the extra clause into the survivor, a gate-owned rule is the gate's) and the removed-design form in Anti-Pattern 6 |
| `devlog/roadmap.md` | the conventions row records the landed rules and points the campaign at them |

## Deferred items

| Item | Reason | Where it goes |
|---|---|---|
| The 130 unresolved test-class rows | each needs a unit written against a production-file read | the rectification campaign, starting with the two rows these rules came from |

## What's Next

The first slice of the campaign applies the two rules to the rows that produced them: collapse the near-duplicate units (row 52) and rewrite the two removed-design units (row 248). Slice one is the rules' acceptance test in practice: if the rule is unclear when applied to a real unit, it is clarified in the same iteration.

Read at iteration start: this handover, the campaign row, and the two rule sections.

**Conclusions from this iteration:** the organisation rule shrank to one sentence when the operator asked whether a lookup is needed at all, and the answer was that the file name already is one. An index of which file covers what was proposed, rejected, and is now forbidden in writing, which is the point of writing it down.
