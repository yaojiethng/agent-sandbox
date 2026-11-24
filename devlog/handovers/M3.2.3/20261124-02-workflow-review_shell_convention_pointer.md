---
date: 2026-11-24
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - The pointer test checks the rule, not one wording

## Objective

Replace the convention-pointer test's byte comparison with the contract the block actually carries, so a carrier may word it itself and the suite is green again.

## Scope

This iteration rewrites [`tests/test_convention_pointer.sh`](../../../tests/test_convention_pointer.sh) and its fixtures. The test compared a shared sentence against a constant in its own file, so the only failure it could produce was a paraphrase; the `code-review` shell's reworded section tripped it, and the shell was not wrong.

The test now checks the two things a carrier can get wrong: the section must name the project's convention root, and it must keep the absent-conventions branch. The branch stays because it fires where these skills run in a project that keeps none of the conventions, which is not this repository. The wording is owned by [`instruction-authoring`](../../../.agents/skills/instruction-authoring/references/body.md), not by a test.

Out of scope, with reasons, though each was considered and dropped: deleting the sentence from the sixteen carriers (the branch is load-bearing elsewhere), loosening the sentence without touching the test (the copy would stay, and the test with it), and editing `code-review` (it needed no edit). The root cause the measurement exposed -- a step must name a convention because it cannot rely on one being loaded -- is filed under M3.3.8 rather than resolved here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A section that names the convention root and the absent branch passes, in wording of its own. | `bash tests/test_convention_pointer.sh` | Agent [x] |
| A section without the convention path is named. | `bash tests/test_convention_pointer.sh`; the `test_missing_path_is_named` unit | Agent [x] |
| A section without the absent-conventions branch is named. | `bash tests/test_convention_pointer.sh`; the `test_missing_branch_is_named` unit | Agent [x] |
| The `code-review` shell is untouched. | `git diff --exit-code -- workflow/coding-agent/skills/code-review/SKILL.md` | Agent [x] |
| The suite is green, where it was red on a clean tree before this iteration. | `bash scripts/run_tests.sh` | Agent [x] |
| The reach root cause is filed with its owner and its dependency. | `grep -n 'workaround for a reach problem' devlog/roadmap.md` under M3.3.8 | Agent [x] |
| Every decision this iteration records is realized in the files. | read the test against the Decisions table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Check structure, not wording: the convention root, and one of the words any absent-conventions branch uses. | A carrier's paraphrase is not a defect, and the test's own constant was the only artifact that required the exact bytes. The structure is what a new carrier actually gets wrong. | This record; `tests/test_convention_pointer.sh` |
| Keep the absent-conventions branch in the carriers. | These skills ship into projects that keep none of the conventions, where the branch is the instruction that applies; the operator confirmed the reason. | This record; operator direction 2026-11-24 |
| Accept any of `missing`, `absent` or `stub` as the branch. | A word list is mechanical and wording-tolerant; a sentence is neither. The list is stated once, at the top of the test. | This record |
| Leave all sixteen carriers unchanged. | The sentence is correct as written; only the test that policed its wording was wrong. | This record |
| File the reach root cause under M3.3.8 instead of resolving it here. | The question is where the contract lives, which is the reach/scope axis M3.3.8 owns; a test rewrite cannot answer it. | `devlog/roadmap.md`, the M3.3.8 row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The gate asserted a byte-identical sentence across 17 carriers, while the rule it protects states only the block's content. The exact form had no consumer beyond the test. | design | the gate policed a copy rather than removing it, so a wording change was a 17-file edit | this iteration: the test now checks the contract |
| One statement carries the whole shared instruction prose: the pointer, in 16 carriers. The next 13 duplicated statements sit in pairs inside one family, and no rule repeats three times. | measurement | the copy is a singlet, not a body, so a composition step is not justified by deduplication | this record; it feeds the M3.3.8 row |
| The 2026-10-27 surface census measured the same thing independently: 34 exact duplicates, 0.5% of the text. | record | two measurements agree, so the finding is not an artifact of this scan | this record; [`20261027-report-draft-surface_census.md`](../../discussions/20261027-report-draft-surface_census.md) |
| The 2026-11-16 and the 2026-10-21 iterations each edited every carrier at once, because the sentence's meaning changed and the test pinned it. | measurement | the cost of the copy is recorded twice, and the pointer's branch changed in both | this record; the M3.3.8 row |
| The failing test was red at HEAD, not in the previous iteration's tree. | record | a green suite is a precondition for every later gate, so this fix preceded further work | this iteration |
| `workflow/vscode/imageConfig/sandbox-agent-sandbox.json` is referenced by no script and no document. | record | an orphan config an editor-surface change would silently not affect | out of scope, carried from handover `20261124-01` |
| `test_convention_pointer.sh` no longer pins the sentence, so a future carrier may word the branch in a way the three-word list misses. | code | a false negative is possible where a carrier invents a synonym | accepted: the alternative is the copy this iteration removed |

## Completed

| File | One-line change summary |
|---|---|
| `tests/test_convention_pointer.sh` | the copied sentence is gone; the check is the convention root plus one absent-branch word, with five units and their fixtures |
| `devlog/roadmap.md` | the M3.2.3 row closes as resolved differently; a new row under M3.3.8 files the reach root cause |
| `devlog/handovers/M3.2.3/20261124-02-workflow-review_shell_convention_pointer.md` | this record |
