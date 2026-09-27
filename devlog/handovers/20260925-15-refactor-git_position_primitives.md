# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Unify the duplicated git position primitives into one helper set and rename the commit-distance helper so its name states its metric.

## Scope

Read-through register row 33, one refactor unit: the helper set in `src/libs/session_inventory.sh`, the fourteen inline copies it replaces, and the rename trail. Two call sites tighten as a consequence. No record changes inside this unit beyond the row's status.

## Carried forward

| Item | From handover |
|---|---|
| Register row 33, blocked by lane ownership rather than by a dependency | the check-in inventory (no handover) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| One helper set covers commit distance, commit existence, current-ref and HEAD resolvability | reading `src/libs/session_inventory.sh` | Agent [x] |
| The fourteen inline copies are replaced | the per-file table below | Agent [x] |
| The old helper name is gone from the tree | `grep -rn project_branch_age src/ scripts/ tests/` | Agent [x] (no matches) |
| The two tightened refusals each have a unit | the two new units | Agent [x] |
| Lint clean and suite green | both runs | Agent [x] (806 units, 0 failed, 0 skipped) |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/session_inventory.sh`](../../src/libs/session_inventory.sh) | the helper set's home; it is a leaf, so the placement stays acyclic |
| [`src/libs/session_state.sh`](../../src/libs/session_state.sh), [`session_env.sh`](../../src/libs/session_env.sh), [`package_branch.sh`](../../src/libs/package_branch.sh) | the three library callers |
| [`scripts/guards.sh`](../../scripts/guards.sh), [`scripts/start_agent.sh`](../../scripts/start_agent.sh) | the host-leaf HEAD gates |
| [`src/capability/seed_volume.sh`](../../src/capability/seed_volume.sh) | the capability-layer HEAD gates |
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh), [`confirm.sh`](../../scripts/workflows/confirm.sh) | the two tightened checks and the branch derivations |
| [`tests/mutations/bite3.sh`](../../tests/mutations/bite3.sh), [`bite4.sh`](../../tests/mutations/bite4.sh), [`bite_int.sh`](../../tests/mutations/bite_int.sh) | the mutation corpus pins the old names |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Put the helper set in `session_inventory.sh`, which already holds the two helpers | it is a leaf that sources nothing, so the placement cannot create a cycle, and no new file means no per-image deployment-list change | this handover |
| Rename `project_branch_age` to `project_commits_since` | the function returns a commit count; `age` already means wall-clock age in the resume and draft tables, where STATE is the distance and AGE the clock | the function's own header |
| Tighten `draft.sh` and `confirm.sh` to the strong commit check | the row asks for one commit-existence primitive, and the weak check accepts a well-formed hex string that is not a commit object; both sites keep their existing refusal text | this handover's Findings |
| Leave four derivations in their local form | the shared helper would change operator-facing text or cannot supply the value a caller needs | this handover's Findings |

## Findings

| Finding | Type | Impact |
|---|---|---|
| A raw `rev-parse --verify <40 hex>` returns 0 while `cat-file -e <40 hex>^{commit}` returns 128, so the two call sites genuinely accepted a non-commit before this change. Each now refuses it, with its own unit. | bug | current iteration |
| Four sites keep a local derivation: `draft.sh` and `draft_state.sh` derive a branch name only and would print a short SHA on detached HEAD where they print `HEAD` today; `session_save_policy.sh` needs the HEAD sha as well as the verdict, and distinguishes a read failure with status 2; `entrypoint.sh` is mode-dependent, using `rev-list --max-parents=0` for the flatten path. | scope change | not planned |
| The mutation corpus (`tests/mutations/`) is a draft capture and is not wired into any runner; its fixed-line-number probes were already stale against HEAD. Only the name references this unit touched were updated. | contradiction | next iteration |
| `package_branch.sh`'s `git rev-list "${INIT_SHA}..HEAD" --reverse` stays a walk, because the call site enumerates commits rather than counting them. | scope change | not planned |
| `git merge-base` stays a distinct primitive, since it answers an ancestry question rather than a position one. | scope change | not planned |

## Completed

| File | Change |
|---|---|
| `src/libs/session_inventory.sh` | added `git_commit_exists`, `git_commit_distance`, `git_head_resolvable` and `project_current_ref`; rebuilt `project_current_branch` on `project_current_ref`; renamed `project_branch_age` to `project_commits_since` and routed it through the new helpers |
| `src/libs/session_state.sh`, `session_env.sh`, `package_branch.sh` | source the helper set; the commit-existence and HEAD gates use it |
| `scripts/guards.sh`, `scripts/start_agent.sh`, `src/capability/seed_volume.sh` | HEAD gates use `git_head_resolvable` |
| `scripts/workflows/draft.sh` | the export-metadata check uses `git_commit_exists`; two branch derivations use `project_current_ref` |
| `scripts/workflows/confirm.sh` | the merge-target check uses `git_commit_exists` |
| `src/libs/resume_list.sh`, `scripts/workflows/interactive.sh` | the renamed call and its comment |
| `tests/test_session_inventory.sh` | five units for the new helpers and the renamed function |
| `tests/test_draft_workflow.sh`, `tests/test_confirm_workflow.sh` | one unit each for the tightened refusals |
| `tests/mutations/bite3.sh`, `bite4.sh`, `bite_int.sh` | the renamed references |

## Deferred items

None. The four local derivations, the walk, the merge-base and the mutation-corpus note are recorded in Findings.

## What's Next

M3.1 - Backpressure remains active. The remaining sub-milestone rows are the coverage campaign, the failure-signalling vocabulary and the mutation-suite decision.

**Conclusions from this iteration:** the duplicated primitives were four distinct questions wearing two names, so the unification had to separate commit existence from a path inside a commit and commit distance from a commit walk; collapsing those pairs would have changed semantics.
