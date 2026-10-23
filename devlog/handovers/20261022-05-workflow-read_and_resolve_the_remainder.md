---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Read and resolve the testing remainder

## Objective

Place each surviving section of `testing_policy.md` and `testing-conventions.md` by kind into its home, and leave both bridge documents carrying no instruction, so the next unit can delete them.

## Scope

Continues the `Retire testing_policy` slice under `Retire the policy form`, unit 2 of three, working from the remainder inventory in [`20261022-design-settled-testing_policy_into_the_skill.md`](../discussions/20261022-design-settled-testing_policy_into_the_skill.md).

In scope: the resolution of the inventory's rows by kind, the moves into the `testing` skill, its `patterns/` and `references/`, `test_harness_mechanism.md`, and the change-close procedure the skill states; the retarget of every pointer that names a moved section; and the `in sequence` defect in the `## Running the Test Suite` section the move carries.

Out of scope: deleting the two emptied files and the pointer sweep that names the file rather than a section, both unit 3; the taxonomy wording under `docs/reference/documentation_taxonomy.md`, owned by the `Retire documentation_policy` slice; the audit records that cite the file as a source, which unit 3 retargets.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The `testing` skill states the placement judgement, when-to-write-tests, `## Before you commit the test` and `## Before you close the change` | `grep -n` each in `.agents/skills/testing/SKILL.md` | Agent [x] |
| `patterns/debugging.md` carries the three symptoms and is indexed | `grep -n 'Test passes in isolation\|Test fails on a re-run\|Test behaviour changes'`; `grep -n 'patterns/debugging.md' SKILL.md` | Agent [x] |
| `patterns/fixtures.md` carries the helper-placement rule and the knowledge/workflow/diagnostic fixture table | `grep -n 'Where a helper belongs\|In knowledge, workflow and diagnostic files'` | Agent [x] |
| `patterns/structure.md` carries the file-and-unit rule | `grep -n 'named for its subject'` | Agent [x] |
| `references/test-homes.md` carries the three homes, the four categories and the prefixes, and is indexed | `grep -n 'knowledge_\|diagnose_\|workflow_\|integration'`; `grep -n 'references/test-homes.md' SKILL.md` | Agent [x] |
| `test_harness_mechanism.md` carries the suite contract and the liveness disposition | `grep -n 'failed 0\|liveness finding is a defect'` | Agent [x] |
| No instruction remains in either bridge; each holds a one-line state naming where its content moved | `grep -n '^## '` both files prints nothing | Agent [x] |
| Every pointer to a moved section names its new home | `grep -rn` the two filenames across `docs scripts tests workflow src .agents`, less the two bridge files and the audit records | Agent [x] |
| The `in sequence` claim is gone | `grep -n 'in sequence' docs/development/testing_policy.md` prints nothing | Agent [x] |
| The roadmap marks unit 2 and leaves unit 3 open | `grep -n` the rows in `devlog/roadmap.md` | Agent [x] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` clean | the commands | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `Test Placement` splits three ways: the decision rule is a judgement inline, the file-and-unit rule goes to `patterns/structure.md`, and the four home categories go to `references/test-homes.md` | The section held three kinds. The lookup convention is longer than a judgement, and the scaffolder's file shape puts a long convention in `references/` | this record; the scaffolder's `nested-patterns` pattern |
| The two completion checklists and Keeping Tests Current become two sections in `SKILL.md`, stated once with pointers into the patterns | A copied checklist would give the patterns a second home; the reader needs the completion list where the test is written, not a duplicate of the criteria | this record |
| The mechanism the policy duplicated is deleted, not restated; `test_harness_mechanism.md` gains only the suite contract and the liveness disposition | The runner, the unit contract, the result protocol and the gates already state the rest | this record |
| The `in sequence` claim is corrected by deletion | The runner dispatches files in parallel under `TEST_PARALLEL`; the sentence was wrong before this unit | this record |
| No new dispatch: `iter.md`'s existing pointer retargets to the skill, and the skill's close list is what the pointer reaches | The close already exists; the workflow states the operation and the skill binds the procedure | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The policy's shared-fixtures table named `make_export_with_diffs()`, which no library defines | defect | a reader following the table would look for a function that does not exist. The fixture pattern names `make_session_fixture()` and `make_draft_fixture()`, which `session_fixtures.sh` defines | fixed in this unit |
| The `## tests/knowledge/` section numbered `tests/integration/` as its fourth category, though integration lives outside the knowledge directory | defect | the placement rule and the directory it described disagreed. `references/test-homes.md` gives integration its own section | fixed in this unit |
| The `## Running the Test Suite` section said the suite runs "in sequence"; the runner dispatches files in parallel under `TEST_PARALLEL` | defect | filed in unit 1's handover for this unit's read; the move deletes the sentence | fixed in this unit |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/testing/SKILL.md`](../../.agents/skills/testing/SKILL.md) | the placement and when-to-write judgements, `## Before you commit the test`, `## Before you close the change`, and the index rows for the two new siblings |
| [`.agents/skills/testing/patterns/debugging.md`](../../.agents/skills/testing/patterns/debugging.md) | new; the three failure symptoms |
| [`.agents/skills/testing/patterns/fixtures.md`](../../.agents/skills/testing/patterns/fixtures.md) | the helper-placement rule and the knowledge/workflow/diagnostic fixture table |
| [`.agents/skills/testing/patterns/structure.md`](../../.agents/skills/testing/patterns/structure.md) | the file-and-unit naming rule |
| [`.agents/skills/testing/references/test-homes.md`](../../.agents/skills/testing/references/test-homes.md) | new; the three homes, the four categories and the promotion rule |
| [`docs/development/test_harness_mechanism.md`](../../docs/development/test_harness_mechanism.md) | the suite contract, the liveness disposition, and the pointers retargeted |
| [`docs/development/testing_policy.md`](../../docs/development/testing_policy.md) | emptied; one line names the new homes |
| [`docs/development/testing-conventions.md`](../../docs/development/testing-conventions.md) | emptied; one line names the skill |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | the two pointers retargeted |
| [`docs/policies/iteration_policy.md`](../../docs/policies/iteration_policy.md) | the "Tests for non-trivial logic" owner retargeted |
| [`docs/development/bash-coding-conventions.md`](../../docs/development/bash-coding-conventions.md) | the cross-reference row names the mechanism document |
| [`docs/development/conventions.md`](../../docs/development/conventions.md) | the testing-policy row removed |
| [`scripts/run_tests.sh`](../../scripts/run_tests.sh), [`scripts/mutations_run.sh`](../../scripts/mutations_run.sh) | comments retargeted |
| [`tests/integration/README.md`](../../tests/integration/README.md), [`tests/test_rename_apply.sh`](../../tests/test_rename_apply.sh), [`tests/libs/draft_fixtures.sh`](../../tests/libs/draft_fixtures.sh), [`tests/knowledge/knowledge_pi_config_cycle.sh`](../../tests/knowledge/knowledge_pi_config_cycle.sh), [`tests/test_binary_roundtrip.sh`](../../tests/test_binary_roundtrip.sh) | comments retargeted |
| [`src/reasoning/providers/pi/config/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md) | the knowledge-test pointer retargeted |
| [`devlog/roadmap.md`](../roadmap.md) | unit 2 marked |
