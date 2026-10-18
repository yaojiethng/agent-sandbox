---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - File the history-cleanup runbook

## Objective

Persist the branch-rewrite procedure as a runbook, so removing an inversion from a draft branch is a prescribed operation with a proof, not an ad-hoc reset.

## Scope

One prompt under `workflow/coding-agent/prompts/`, and one row in the git policy's reference table so the operation is discoverable from the policy that governs commits. The prompt assumes the project's `git-discipline` and `work-log` conventions for commit types and records, and prescribes no project path.

Not in scope: rewriting the branch this session produced. The operator asked for the plan and the prompt; the rewrite stays a separate release.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The prompt states four invariants, not a shape | the mandate names reviewability, bisectability, record truth, and no content written then replaced | Accepted |
| Safety is checked before anything is written | the first step records upstream, tags and branches in the range, signatures and notes | Accepted |
| Inversions are found mechanically | the step names `git log -G`, removed-against-added matching, and a repeated patch id | Accepted |
| Verification moves from the tree to the series | tree identity, patch-id multiset, `git range-diff` | Accepted |
| Each commit is gated as it is produced | the rebuild step requires `--exec` or a worktree run per commit | Accepted |
| The prompt follows the workflow-document structure | frontmatter, `> $@`, project conventions, steps each ending on a completion criterion, non-goals, failure modes | Accepted |
| The gates and the suite are green | `bash scripts/lint.sh` 10 gates; `bash scripts/run_tests.sh` 1,227 | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The proof is `range-diff` plus patch ids, not a tree diff | A tree diff proves the endpoint. Only the series proves that a hunk did not move between commits, and the multiset forbids a change split and recombined. | the prompt's `## Prove the series` |
| Bisectability is an invariant | A linear series whose middle commit does not build is linear and useless. The gate runs as each commit is produced. | the mandate; the rebuild step |
| Records are the only thing rewritten | The working tree already holds the final content, so the content is the invariant and the records are the artifact that describes the old shape. | the mandate |
| A tag, branch, note or signature inside the range stops the run | None appears in `git log`, so each is how a rewrite loses something silently. | the safety step; the failure modes |
| The name is `history-cleanup`, not `squash` | The name states the work, not the mechanism, and a squash is one of several outcomes. | the prompt's file name |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does the loop's prompt table in `AGENTS.md` list maintenance runbooks? | whether this prompt and `rebase` and `merge` appear in the same table | list them; keep the table to loop transitions |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The repo's five commits since the base held two inversions: a convention rewritten one commit later, and a policy section plus provider bullet revised one commit later. | measurement | The prompt exists because the failure recurred twice in one session, not as a hypothetical. |
| A tree diff would have passed on both of those ranges. | diagnosis | Only the series checks catch content that moved or was replaced inside a range. That is why the accept step is `range-diff`. |
| The policy's reference table named `rebase` and `merge` but would not have named this operation. | evidence | A runbook nobody can reach from the governing policy is a file, not a procedure. |

## Completed

| File | Change |
|---|---|
| [`history-cleanup.md`](../../workflow/coding-agent/prompts/history-cleanup.md) | the runbook: safety, patch-series data, mechanical inversion detection, target proposal, rebuild with a per-commit gate, series proof, per-commit proof, report |
| [`git_policy.md`](../../docs/policies/git_policy.md) | a reference row naming the operation |
