---
status: open
date: 2026-11-12
---

# The git-discipline evidence

## Context

The convention [`git-discipline`](../../.agents/skills/git-discipline/SKILL.md) is read before every commit, and its rules have never been measured against the history they govern. This record is the requirements pass for the deferred rewrite *The convention leads from history as a commons*: the corpus measurement, the rule-to-defect map, the consumers, the failure cases, and the disposition of the drafts and discussion records that list problems.

## The corpus

Extracted with `git log --format='%h%x1f%s%x1f%b%x1e'` and an `awk` pass over the fields. The script was a one-off; the numbers are the evidence, and a reader reruns the same two commands.

| Measure | All 1,458 | Last 300 | Last 100 |
|---|---|---|---|
| subject over 50 characters | 876 | 123 (41%) | 38 (38%) |
| body over 280 characters | 430 | 51 (17%) | 14 (14%) |
| active type prefix | -- | 291/300 (97%) | -- |
| `wip:` subject | 1 | -- | -- |
| `fixup!`/`squash!` subject | 0 | -- | -- |
| body names a handover | 248 | 40/301 | -- |

Three non-conforming type words appear in the recent log: `impl:` (`ebdf215d`, `89199eb4`), `design:` and `feature:`. Merge commits (`Merge pull request #...`) are host-authored and outside the rule.

The three most recent delivery commits violate the subject budget: `1738076d` (73), `f27d8071` (56), `cf8edc8f` (54). The rule is violated by the commits that argue for it, so the budget is contested rather than merely old.

## The rules against the corpus

| Rule | Defect it prevents | Real instance | Strength |
|---|---|---|---|
| subject is `type: imperative summary`, 50 characters or fewer | a log a reader cannot scan | 41% of the last 300, including this iteration's own predecessors | measured, contested |
| body is one sentence, 280 characters or fewer | a reason no reader reaches | 17% of the last 300 | measured, contested |
| the type is one of the nine active types | a commit that reads as the wrong category | `ebdf215d impl:`, `89199eb4 impl:` | measured, holding |
| an intermediate commit is `wip:`, fixup or amend, never typed | a false delivery surface | no instance in 300; one `wip:` in 1,458 | no instance |
| a correction folds into the commit it corrects | a fixup stack; a fix hidden in a later commit | `9d323247`, `b5e66395` are separate corrections; both target a closed session, where the rule allows the separate commit | exception used, no violation |
| a commit is one coherent change | a commit a reviewer cannot read or revert | not measured; no instance produced | no instance |
| one iteration is one delivery commit and one closed handover | a typed commit with no deliverable | the branch carries its handover; 13% of recent bodies name one | partial |
| a branch name is `type/milestone_description` | an unnamed or ambiguous branch | the current branch conforms | no instance |
| the history operations have runbooks | an operation with no procedure | the retired prompts were replaced by `prepare` and `history-cleanup`; `check_agent_primitives` is clean | holds |
| the agent leaves a branch a host verb consumes | a prompt that mirrors a host verb | the retired prompts; the gate | holds |
| published history is never rewritten | a rewritten public branch | no instance | no instance |

## The consumers

| Consumer | Path | What it cites and assumes |
|---|---|---|
| `/commit` | [`commit.md`](../../workflow/coding-agent/prompts/commit.md) | reads `git-discipline`; assumes one delivery commit per iteration, `wip:` folds, a typed intermediate is forbidden |
| `/record-correction` | [`record-correction.md`](../../workflow/coding-agent/prompts/record-correction.md) | reads `git-discipline`; assumes a correction folds into a closed commit, and a type change does not fold |
| `prepare` | [`prepare.md`](../../.agents/skills/git-discipline/references/prepare.md) | assumes the branch carries one delivery commit and descends from the trunk; cites `branching.md` for readiness |
| `history-cleanup` | [`SKILL.md`](../../workflow/coding-agent/skills/history-cleanup/SKILL.md) | reads `git-discipline`; assumes fold, reorder, split and whole-range rebase leave one delivery commit and no inversion |
| `code-review` | [`SKILL.md`](../../workflow/coding-agent/skills/code-review/SKILL.md) | takes its range from the operator or the branch point; the 2026-10-31 feedback entry records the range being inferred at the call site |

## The failure cases

| Case | Id | What failed | Disposition |
|---|---|---|---|
| the review range was inferred at the call site | handover `20261103-02` | the runbook lost the sentence that named the branch point | mitigated; carried by `code-review`; feedback entry dropped |
| a git operation reverted uncommitted work | feedback 2026-08-10 | `git restore`/`stash`/`checkout` over a dirty file | open; the rule belongs in the rewrite, so the entry is scoped to it |
| the change prompts mirrored host verbs | handover `20261112-03` | `prepare-rebase`, `accept-fast-forward`, `merge-queue` | fixed; `check_agent_primitives` holds it |
| the subject budget is violated by the recent commits | `1738076d`, `f27d8071`, `cf8edc8f` | 41% of the last 300 | the rewrite adjudicates the budget: a weaker rule, or a measured cost of the stronger one |

## Adjudications

- **The 50-character subject budget is contested.** 41% of the last 300 violate it, including the three commits immediately before this record. Either the budget is wrong for this repo or the agents are; the rewrite decides with this number in hand.
- **The 280-character body budget is contested, less sharply.** 17% of the last 300 exceed it.
- **The type set holds.** 97% of the recent commits carry an active type; the exceptions are `impl:` and merge commits, and the merge commits are outside the rule.
- **The no-instance rules** -- the `wip:`/typed-intermediate rule, the branch-name rule and the never-rewrite-published rule -- have no recent violation. They are boundary rules; the rewrite keeps or drops them with that stated, not by omission.
- **The fold rule's exception is used.** The two separate corrections target a closed session, which the rule permits.

## The problem inventory

The scan read every file under `.agents/drafts/` (17), `devlog/discussions/` (16 active) and `src/reasoning/agent/drafts/` (3), and the two archived records whose subject is the git boundary or the change workflow. A file is a *problem inventory* when it states a problem, defect, violation, gap or audit; a design or run plan is not.

| File | Problem | State | Disposition |
|---|---|---|---|
| `devlog/discussions/20261002-report-draft-default_model_resolution_bug.md` | default-model resolution | open | keep; row 920 |
| `devlog/discussions/20261003-study-draft-roadmap_churn_study.md` | roadmap churn | closed study, sources T5 | keep until the T5 rewrite lands |
| `devlog/discussions/20261014-design-draft-doc_maintenance_eval_restart.md` | doc-maintenance eval restart | deferred | keep; the future row |
| `devlog/discussions/20261014-report-draft-scoped_model_list_stale_after_refresh.md` | scoped model list staleness | open | keep; row 921 |
| `devlog/discussions/20261016-report-draft-carrier_census.md` | carrier defects and contested classifications | open set | keep; row 411 deletes it when the set empties |
| `devlog/discussions/20261027-report-draft-surface_census.md` | instruction-surface cost and duplication | open rows | keep; rows 334 and 335 |
| `devlog/discussions/20261105-design-open-defect_flow.md` | defect flow across branch and milestone | open | keep; row 331 |
| `devlog/discussions/20261105-design-concluded-handover_tracks.md` | handover-track read surface | open facts | keep; row 761 retires it |
| `.agents/drafts/dispatch-harness-defects-handoff.md` | six dispatch defects | open | keep; row 656 |
| `.agents/drafts/gate-constraints-handoff.md` | constraint kinds the gates should express | open | keep; row 120 |
| `.agents/drafts/precommit-gate-runbook.md` | gate procedure braindump | open | keep; row 120 |
| `.agents/drafts/task-list-work-log-violation-requirements.md` | task-list and work-log error classes | all now enforced by the maintenance skills | **retired**; the classes are in `roadmap-maintenance` and `handover-maintenance` |
| `devlog/discussions/archive/20260925-design-draft-git_boundary.md` | git boundary options | open rows 685-688 | keep |
| `devlog/discussions/archive/20260925-design-draft-diff_workflow_invariants.md` | the change workflow's invariants | held by `change_model.md` | **retired**; the invariants are in the reference |
| the remaining drafts | run plans, design prompts, templates | active inputs | keep; not problem inventories |
| the remaining discussions | settled designs and reports | cited by an ADR or a row, or historical | keep; not problem inventories |
| the other 84 archived records | unrelated subjects | closed history | not read |

The two retirements are records whose durable facts live in a shipped record and which no open row or ADR cites: the error classes are in the two maintenance skills, and the change-workflow invariants are in [`change_model.md`](../../docs/reference/change_model.md). The `rm` is in the iteration's diff.

## What this asks of the rewrite

- State the intent, then keep only the rules the evidence supports; adjudicate the two budgets and name the no-instance rules as boundary choices.
- Keep the type set and the fold exception; the evidence supports both.
- State the uncommitted-work rule the 2026-08-10 entry asks for, which resolves that entry.
- Keep the runbook and host-verb handoff; the retired prompts are the evidence they replaced a worse surface.
