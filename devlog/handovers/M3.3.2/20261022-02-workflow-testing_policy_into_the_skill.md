---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Extract the testing patterns into the testing skill

## Objective

Move the unambiguous testing patterns and judgements out of `testing_policy.md` and `testing-conventions.md` into the `testing` convention-skill, remove the extracted sections from both documents, and inventory the remainder by kind so the next unit can read it.

## Scope

Continues the `Retire testing_policy` slice under `Retire the policy form`, cut into three units by [`20261022-design-settled-testing_policy_into_the_skill.md`](../discussions/20261022-design-settled-testing_policy_into_the_skill.md). This is unit 1.

In scope: the pass-1 cut the design record states, the skill's `SKILL.md` index and inline judgements, the `patterns/` siblings, the removal of the extracted sections from both documents, the propagation of every reference to a moved section, and the remainder inventory.

Out of scope: resolving the remainder (unit 2), phasing the bridge out (unit 3), and the change to `docs/reference/agent_workflow.md` `### Norm kinds` that specializes description into convention and pattern (filed as its own unit). Also out of scope: changing the test harness or adding isolation machinery. The shipped `iteration_policy.md` line keeps naming `testing_policy.md` until unit 2 lands the rule it points at, because naming the convention seam before the rule has a home would point at nothing.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `SKILL.md` is an index: four judgements inline, and every `patterns/` file named with the situation that opens it | `grep -n 'patterns/' .agents/skills/testing/SKILL.md` names all four | Agent [x] |
| Each pattern file carries the concrete form it moved | `grep -l` a known snippet per file names each file | Agent [x] |
| The moved sections are gone from both documents (negative) and present in the skill (positive) | `grep -n` the moved headings in both docs prints nothing; the pattern files carry the content | Agent [x] |
| Every reference to a moved section names its new home | `grep -rn 'Anti-Pattern [0-9]\|Test Structure Template\|Core Principles 1-3' docs scripts tests .agents src workflow` prints nothing; `bash scripts/lint.sh` clean | Agent [x] |
| The remainder inventory exists: one row per surviving section, with kind and intended home | `grep -n 'Remainder inventory'` in the design record names the table | Agent [x] |
| The roadmap names the three units and the membership row's phase-out resolution | `grep -n` the rows in `devlog/roadmap.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Use the existing kinds and specialize description into convention and pattern | The file's error is labelling judgements as rules. A pattern carries the concrete form; a convention states criteria and remediation; a judgement has no cheap observer | design record |
| The skill is the container: judgements inline, patterns as siblings, an index in `SKILL.md` | The skill format already loads a named sibling, so no mechanism is added and the agent meets the pattern where the task matches | design record |
| Project scope owns the framework and layout; the workflow owns the convention seam | Other projects bind jest, pytest, BDD or TDD. Under-prescribing means the workflow states the operation and the project states the mechanics | design record |
| Extract the full unambiguous-pattern set in one pass | Patterns then have one home from the start; a family pass would leave two homes for several iterations | design record |
| A section that straddles the line is resolved in the slice: the `set -e` suppression is mechanism and moves to `test_harness_mechanism.md`, the fixture table moves to the fixtures pattern, and the placement rules stay in the bridge | The suppression explains how `run_test` runs; the placement rule is a convention the remainder still owns | this record |
| No ADR | The sibling shape is the skill format's existing loading, so the decision adds no standing principle to the convention-skill model the binding ADR already records | design record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The membership row's premise is false: the agent reads `testing_policy.md` from its working directory, and the shipped policies already name it in a code span rather than link it | defect | the row would have shipped or renamed a file whose content is the actual problem. The row is reworded to resolve at the phase-out and stays open | fixed in this unit; the row is reworded |
| The `Retire testing_policy` row's design map names a "testing procedure" that does not exist, while the real destinations are the skill, the mechanism document, the gates and the close steps | gap | the unit renames the destinations and files the rules beside their enforcement | the design record |
| The taxonomy's "The other folders hold no rules" overstates the membership test while `docs/development/` holds contributor conventions with rules and bars | gap | the sentence is the reading the retired row relied on; the reach table beside it is the accurate statement | recorded here; no row filed, because the `Retire documentation_policy` slice owns the taxonomy's wording |
| The shared-fixtures table named three of the four files in `tests/libs/` | defect | a reader following the table would miss `draft_fixtures.sh`. The fixture pattern now lists four and names the directory as the source | fixed in this unit |
| `testing_policy.md` `## Running the Test Suite` says the suite runs "in sequence"; the runner dispatches files in parallel under `TEST_PARALLEL` | defect | a pre-existing inaccuracy in a section this unit leaves for the remainder read; the section is the inventory's `Running the Test Suite` row | unit 2's remainder read |
| The template shipped as a `.sh` asset, and the pre-commit ShellCheck read it as a script and failed on its placeholders | defect | a template is not a runnable script. It is a Markdown asset with a fenced block now, so the shell gate does not read it | fixed in this unit |
| A sidequest pauses this iteration at its pre-close gate: capture the nested-pattern skill shape under `skill-scaffolder` | interruption | the parent keeps its `Active` status and resumes after the sidequest closes; its release gate waits | sidequest `20261022-03` |
| A second sidequest pauses this iteration: file the prose-entrypoint pattern under `skill-scaffolder`, redirected from the handoff's principle-skill route | interruption | the parent keeps its `Active` status; its release gate waits | sidequest `20261022-04` |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/testing/SKILL.md`](../../.agents/skills/testing/SKILL.md) | the four judgements inline and the pattern index |
| [`.agents/skills/testing/patterns/fixtures.md`](../../.agents/skills/testing/patterns/fixtures.md) | the fixture patterns and the shared-helper table |
| [`.agents/skills/testing/patterns/structure.md`](../../.agents/skills/testing/patterns/structure.md) | the file shape and the one-unit-per-behaviour pattern |
| [`.agents/skills/testing/patterns/assertions.md`](../../.agents/skills/testing/patterns/assertions.md) | the assertion patterns, including the change-mirror, test-the-copy and whole-tree forms |
| [`.agents/skills/testing/patterns/dispatch-mocks.md`](../../.agents/skills/testing/patterns/dispatch-mocks.md) | the dispatch mock harness |
| [`.agents/skills/testing/assets/test-file-template.md`](../../.agents/skills/testing/assets/test-file-template.md) | the fill-in test file |
| [`docs/development/testing-conventions.md`](../../docs/development/testing-conventions.md) | reduced to the migration bridge: debugging and the two checklists |
| [`docs/development/testing_policy.md`](../../docs/development/testing_policy.md) | the Core Principles and the `test_common` usage removed; the placement, suite and staleness rules stay |
| [`docs/development/test_harness_mechanism.md`](../../docs/development/test_harness_mechanism.md) | the authoring pointer updated; it now carries the `set -e` suppression mechanism |
| [`docs/development/conventions.md`](../../docs/development/conventions.md) | the testing row points at the skill |
| [`docs/development/bash-coding-conventions.md`](../../docs/development/bash-coding-conventions.md) | the cross-reference rows and the harness-exit pointer updated |
| [`scripts/check_test_liveness.sh`](../../scripts/check_test_liveness.sh) | the comment names the structure pattern |
| [`tests/test_linking.sh`](../../tests/test_linking.sh) | the comment names the assertions pattern |
| [`tests/test_doc_wrap_rule.sh`](../../tests/test_doc_wrap_rule.sh) | the comment names the assertions pattern |
| [`tests/test_document_shape.sh`](../../tests/test_document_shape.sh) | the comment names the assertions pattern |
| [`tests/libs/test_common.sh`](../../tests/libs/test_common.sh) | the comment names the test-the-copy pattern |
| [`.agents/audits/test-quality-campaign.md`](../../.agents/audits/test-quality-campaign.md) | the reading list and the two anti-pattern names updated |
| [`.agents/drafts/read-through-run.md`](../../.agents/drafts/read-through-run.md) | the assertion-rule citation updated |
| [`devlog/roadmap.md`](../roadmap.md) | `Retire testing_policy` cut into three units, the membership row reworded, the sequencing updated |
| [`devlog/discussions/20261022-design-settled-testing_policy_into_the_skill.md`](../discussions/20261022-design-settled-testing_policy_into_the_skill.md) | the method, the cut and the remainder inventory |
