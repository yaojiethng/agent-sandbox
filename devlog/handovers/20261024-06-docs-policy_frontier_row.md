---
date: 2026-10-24
milestone: M3.6.3 - Route and decide
type: Design
status: Closed
---

# Handover - The policy bakeoff becomes a frontier, in the milestone that measures

## Objective

Rewrite the policy bakeoff into a row the repository can execute, and file it where the measurement is owned: replacing `M3.6.2`'s requests-per-completed-task row, with the bakeoff row closing in `M3.6.3` on a pointer to it.

## Scope

The two roadmap rows and `M3.6.3`'s scope sentence, the run brief at `.agents/drafts/dispatch-policy-frontier-run.md`, and this record. No measurement is run and no code is written: this unit rewrites the task, as the previous `/scope` pass specified it.

## Why the row moved

`M3.6.2` already carried almost every part of the rewritten task as its own rows: the cost ledger that reads the corpus, the outcome instrument that prices an attempt, the aggregates, and the requests-per-completed-task row whose per-role key this repository cannot compute. `M3.6.3` decides; `M3.6.2` measures. Yesterday's failover A/B left `M3.6.3` for the same class of reason -- the capability was owed elsewhere -- and this row leaves because the measurement is.

## What the replacement changed

| The bakeoff asked for | The frontier row asks for |
|---|---|
| two or three candidate policies compared | the one policy that exists, priced |
| one brief and one commit, as the sample | the session corpus and the worktrees its commits landed in |
| cost beside wall clock | dollars, wall clock and requests per delivered change set, because the axes trade off and the free tier is request-limited |
| "the winner and what it beats" | a pre-committed outcome: a policy with the data that ranks it, or a closure |
| candidates assumed expressible | three limits recorded: no role in the transcript, `$0.00` is free-or-unpriced, and the candidates collapse |

Three findings from the replaced row were kept rather than dropped with it: the free tier's shared 200-requests-per-IP-per-day pool and why a per-token price misranks a cheap model; the quota record as a moment with no remainder, which puts a quota axis out of reach; and the fact that no aggregate divides by a completed task.

## What the row now claims, and what would falsify it

The row is an investigation with its outcome pre-committed, so it terminates either way. Its premise is falsifiable in one place: if `cwd` does not join a session to a worktree that produced commits -- worktrees under `/tmp` may be pruned -- the frontier cannot be printed and the record says so instead of a table.

## Decisions

| # | Decision | Rationale | Where recorded |
|---|---|---|---|
| D1 | The row replaces `Requests per completed task` instead of sitting beside it | the frontier subsumes the request count as one of its three axes, and two rows over one corpus would drift | the `M3.6.2` row; this record |
| D2 | The row lands in `M3.6.2`, not `M3.6.3` | `M3.6.2` owns the instrument the study reads and already carried the rows this one subsumes | the row's position; this record |
| D3 | The bakeoff row closes on a pointer rather than being deleted | a closed row keeps the reasoning and the operator's direction visible; a deleted one loses them | the `M3.6.3` row's closure |
| D4 | The run brief is a file, not prose in the row | the row is the task list entry and the brief is what a run reads; the previous bakeoff's intent survived only because a brief carried it | `.agents/drafts/dispatch-policy-frontier-run.md` |
| D5 | The three axes are dollars, wall clock and requests | the free tier's scarce resource is requests, so a cost-only frontier would misrank the models the tier constrains | the row's text |

## Decisions pending

None.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| the frontier row replaces the requests row | `grep -c "^- \[ \] \*\*The policy frontier, from the corpus\*\*" devlog/roadmap.md` prints 1 and `grep -c "Requests per completed task" devlog/roadmap.md` prints 0 | Agent [x] Operator [x] |
| the bakeoff row closes on a pointer | `grep -c "^- \[x\] \*\*The policy bakeoff\*\*" devlog/roadmap.md` prints 1 | Agent [x] Operator [x] |
| `M3.6.3` no longer scopes a bakeoff, and holds no open row | `grep -c "the policy bakeoff, dispatch ownership" devlog/roadmap.md` prints 0; the section's open rows count 0 | Agent [x] Operator [x] |
| the brief exists and names the row it feeds | `.agents/drafts/dispatch-policy-frontier-run.md` opens with the row it serves | Agent [x] Operator [x] |
| the gates stay green | `scripts/lint.sh`, `scripts/run_tests.sh` | Agent [x] Operator [x] |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| the bakeoff's intent survived only in a run brief, and the roadmap row compressed it past recognition | record | a row that names no subject cannot be executed or retired; the rewrite restores the subject | the frontier row; this record |
| two of the three named candidates are not expressible, and the third shipped as a route state | measurement | the bakeoff had no comparison to run, which is why it is closed rather than deferred | the frontier row's limits |
| the transcript records an assignment and never a role | measurement | the per-role efficiency metric the replaced row asked for is not computable, and the brief records that rather than inferring a role | the frontier row; the brief |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | `Requests per completed task` replaced by `The policy frontier, from the corpus`; `The policy bakeoff` closed on a pointer; `M3.6.3`'s scope sentence narrowed |
| [`.agents/drafts/dispatch-policy-frontier-run.md`](../../.agents/drafts/dispatch-policy-frontier-run.md) | the run brief: premise, what is already measured, rulings, phases, run shape, work units, model assignment, check, constraints, what would settle it |
| this record | the placement reasoning, the kept findings, and the decisions |
