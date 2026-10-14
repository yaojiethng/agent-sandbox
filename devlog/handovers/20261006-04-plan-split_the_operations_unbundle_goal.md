---
date: 2026-10-06
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Plan
status: Closed
---

# Handover - Split the Operations Unbundle Goal

## Objective

Replace the single M3.3.1 goal row with a task list whose rows run one at a time, each landing on its own handover and leaving the repository working.

## Scope

The active sub-milestone carried one open row for its end state, `End-of-sub-milestone goal: docs/operations/ is no longer bundled`. That row mixes four kinds of work: a design decision that nothing in the tree answers, a migration of seven policy documents, a change to what two images carry, and a sweep of the readers outside the migration. The iteration replaces it with ten rows in execution order.

The seam comes from measurement over the instruction roots, 94 references to `/opt/sandbox/docs/operations/` over 17 files. Seven policies carry them: `roadmap_policy.md` 31, `iteration_policy.md` 29, `handover_policy.md` 11, `git_policy.md` 9, `documentation_policy.md` 7, `adr_policy.md` 4, `discussion_policy.md` 2. Two further live instruction files read a policy in the repository-relative form and are named by the row that moves their policy.

In scope: `devlog/roadmap.md`, and this handover. Out of scope, each with a reason: every move, the bundle removal and the gate, which the new rows own; the parked outgoing-link row, which keeps its general half and loses only its decidable half to the gate row; and the two document trees that no instruction root reads, which the design row decides rather than assumes.

## The split

The goal is one state of the tree: the bundle is gone, each policy sits with the skill that determines its workflow, and no instruction root reads a path outside its own tree. Each row below retires one part of that state. The third column is the test the policy sets, that a part delivers an outcome of its own and leaves the repository working after it lands.

| Task | The part of the goal it retires | Why it is a task |
|---|---|---|
| Decide where the operations content lives, and what the repository copy becomes | the goal's premise, since nothing can move before the destination, the copy's form and the path form are settled | it is a decision with no file change, and `roadmap_policy.md` `### Filing rules` gives an open design question a discussion document with one row referencing it, so the row closes when the document resolves rather than when a file moves |
| Move the handover policy to its skill, as the pilot | one of the seven policies acquires its one home, and the form the other five repeat is settled | a policy's readers must move together, because a partial move leaves readers pointing at the old home; it goes first because it exercises both reader classes, so a wrong form reverts one policy rather than seven |
| Move the roadmap policy to its skill | the second of the seven, and the largest at 31 references | the same reader test, and its owning skill is unambiguous, so nothing in it depends on the pilot beyond the form |
| Move the iteration policy | the third of the seven, at 29 references | the same reader test, and no skill owns it, so its destination is a separate decision from a move with an obvious owner |
| Move the git policy | the fourth of the seven, at 9 references | the same reader test |
| Move the documentation policy | the fifth of the seven, at 7 references | the same reader test |
| Move the ADR and discussion policies together | the sixth and seventh, 6 references between them | one task because the same three prompts read both, and two rows would double the close overhead for two documents that always travel together |
| The rule and the readers outside the seven policies follow the move | the own-tree clause, for the readers that are not a policy's reference | it changes the advice layer rather than a policy's readers, and it can only be written once every destination is known |
| The own-tree rule becomes a gate | the criterion's build-time half, extended from a dead path to a path outside the root's tree | it is a check rather than a content change, and it lands before the deletion so the deletion is verified rather than asserted |
| Drop the operations bundle | the headline state, the bundle gone from the image | it is the one change that splits no further, and it comes last because those three lines are what keeps the unmigrated references resolving while the earlier rows land |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The goal row is replaced | `devlog/roadmap.md` carries ten open rows where the one `End-of-sub-milestone goal` row stood, and no row of that title remains | Agent [x] |
| Every row ends on its own outcome | reading the ten rows shows no row is a step inside another's work, and each names what ends it | Operator [ ] |
| The counts are measured, not estimated | each row's reference counts come from the scan over the instruction roots | Agent [x] |
| The order is stated rather than implied | the last row names why it comes last, and the first names why nothing moves before it | Agent [x] |
| Lint and the suite are clean | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` | Agent [x] -- 8 gates clean, 1114 tests across 76 files, liveness clean |
| The handover closes | this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `devlog/roadmap.md` | the goal row becomes ten rows |
| `devlog/handovers/20261006-04-plan-split_the_operations_unbundle_goal.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The seam is one row per policy document | `iteration_policy.md` is read by 8 files and `roadmap_policy.md` by 7, so a move per reader would copy the same content into several trees; a move per document keeps one home for each rule | this handover |
| The design row stands first, ahead of every move | the destination is undecided in the tree, and `roadmap_policy.md` `### Filing rules` puts an open design question in a discussion document with one row referencing it | this handover |
| The pilot row moves the handover policy | it is the only policy beside the roadmap's that both a skill and several prompts read, so one unit proves both classes | this handover |
| The gate row lands before the bundle row | the deletion is then guarded by a check rather than asserted by a grep | this handover |
| The ten rows run in series rather than being dispatched in parallel | `iter.md` and `document.md` appear in six of the seven move rows, so the task queue cannot fan them out | this handover |
| The counts stay in the rows rather than in this handover | the count is the reason each row is its own unit, so it belongs where the work is read | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The provider `AGENTS.md` reachable-paths table names three `/opt/sandbox/docs/` roots. Only the operations row falls under the goal's check, because the other two bundles have no reader among instruction roots. The blind spot is filed into the design row rather than a row of its own, since the design may rule that both keep shipping. | design gap | the design row |
| Two live instruction files read a policy in the repository-relative form, `workflow/coding-agent/prompts/gm.md:10` and `src/reasoning/agent/skills/domain-model/ADR-FORMAT.md:4`. The form resolves because the working tree is the current directory, and not from the shipped copy's own directory. | contradiction, measured | the iteration row and the ADR row, each taking its own reader |
| Three lines in the eval skill name `docs/operations/` as a fixture path rather than as a reading reference, twice in `eval/evals/commit-body-budget.json` and once in `eval/scripts/run_case.sh`. A different class from the readers above. | evidence, surveyed | unowned, at the operator's word |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | the goal row replaced by ten rows in execution order, each naming its own outcome, its own check and its own provenance |
| `devlog/handovers/20261006-04-plan-split_the_operations_unbundle_goal.md` | this handover |
