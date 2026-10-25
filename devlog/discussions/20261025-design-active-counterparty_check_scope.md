---
status: active
date: 2026-10-25
---

# The compliance counterparty's check scope

A close without an operator acceptance gate has no counterparty to the closing agent's own framing, and the 2026-10-02 rescope is the recorded failure: the agent believed its own six-slice framing, so a self-check by the same agent could not catch it. The roadmap row resolves the mechanism -- a review subagent on the `_REVIEWER` role reads the closed unit -- but leaves its check scope unnamed ("alongside the existing review dimensions"). This record names it, states the evidence each check reads, and states what the seat returns. Source row: [M3.2.2](../roadmap.md#m322---audit-and-review-workflow-cleanup) task item **The review-pass family**, sub-row **Reviewer subagent as the compliance counterparty for gateless closes**.

## Where a close has no gate

A close is gateless when the operator's acceptance is absent at the moment the unit reaches its done state. Three sites qualify, and each leaves a different artifact for the seat to read.

| Site | What the close is | Artifact the seat reads |
|---|---|---|
| An `/iter` run under an autonomy grant | the agent closes its own iteration and marks its own acceptance criteria | the commit range, the handover, the roadmap diff |
| A unit packaged for `/rebase` | the `/package-branch` tool exports numbered diffs for a host tree, and the packaging step can check nothing | the branch's commit series and its handovers |
| A worker's returned segment merged back | `taskq_verify` is a structural audit -- it records whether the return arrived as directed, never whether the work is good | the worker branch's commit series and its handover |

The second is the one the roadmap row names explicitly: compliance must be checked before packaging, because the export is applied where no one can re-derive it. The third is partial -- the operator judges the proposal at the terminal break point -- but the stored audit is structural, so the compliance reading has no home there either.

## The check scope

Eight checks. Each names the evidence it reads and the signal that fails it, and each rules the close already states; the seat applies the rule to this unit, and adds no rule of its own.

| # | Check | Evidence read | Failure signal | Rule |
|---|---|---|---|---|
| C1 | The range is one unit | `git log --oneline <base>..HEAD` against the handover's Scope | more than one delivery-typed commit, an unfolded `wip:`, or a range that spans distinct deliverables | `git-discipline` The fold; `iteration_protocol` one iteration, one unit |
| C2 | The delivery commit is typed and within budget | each delivery commit's subject and body | a prefix outside the nine active types, a type the work does not belong to, a subject over 50 characters, a body over 280, a transient identifier | `git-discipline` The commit message |
| C3 | One handover names the unit and is closed | `devlog/handovers/` for the unit's record | no record, two records, `Status: Active`, a frontmatter type that contradicts the commit type | `work-log`; `iteration_protocol` close invariants |
| C4 | The acceptance criteria were verified, not asserted | each criterion's `Verification` and `Result` | a criterion with no verification text, or marked accepted whose command the seat cannot reproduce on the closed tree | `iteration_protocol` close invariants |
| C5 | The scope reconciles | the handover's Scope, its Completed table, and the diff's file list | an in-scope item absent from Completed, a changed file outside scope with no Finding row, an incomplete item not written back as an open row | `iteration_protocol` close invariants, scope reconciliation and deferred resolution |
| C6 | The roadmap write-back rode the commit | the commit's diff against the row the handover names | the task unmarked, resolved sub-rows left expanded, or a row asserting a state the tree contradicts | `task-list` |
| C7 | The gates the close claims are reproducible | `bash scripts/lint.sh`, and the suite claim the handover makes | lint not clean on the closed tree, or a suite claim the seat cannot reproduce | the project `AGENTS.md`; `testing` |
| C8 | Nothing closed unearned | the diff | a `[x]` row whose artifact is absent, a test removed or weakened to make a suite pass, a stubbed branch behind a claimed capability | `iteration_protocol` defect resolution |

C1 and C2 are the two the roadmap row names. C3 through C8 are what "one commit per handover" cannot be checked against without them: the rule is a claim about a record, and a commit range alone never shows whether the record was written.

## What the seat does not check

- **Code quality and correctness.** The existing review prompts own those dimensions, and their judgement classes stay with the reviewer. A counterparty that re-ran them would double the cost of every close for a second opinion no rule settles.
- **Whether the work is worth doing.** The roadmap and the scope gate already answered that; the seat reads the record it was given.
- **The operator's ruling.** The seat reports; the operator decides what to do with a HOLD.

## The verdict and where it lands

The seat returns one line per check -- `C<n> | result | evidence` -- and one top line, `APPROVE` or `HOLD`, where a HOLD names the failing check and nothing else. The vocabulary is the seat's existing one: [`dispatch.md`](../../docs/reference/dispatch.md) already carries `APPROVE` and `HOLD` for a review seat, and a second vocabulary for the same judgement would be a synonym.

The report lands in the closed unit's handover as a Findings row, with `Triaged to:` naming the close itself. It does not block: a gateless close is gateless by definition, and a blocking counterparty would manufacture a new operator dependency at exactly the point the mechanism exists to remove one. The delta is visibility -- today a close with no gate leaves no record that anything was read, and after this it leaves the report, its evidence and its verdict.

A HOLD the closer ignores is therefore a recorded act. That is the failure class the 2026-10-02 rescope names: the agent's framing went unchecked and unrecorded, so no one could see it had.

## The invocation

- **Role and seats.** `_REVIEWER`, one seat. Compliance is mechanical, and one pass is enough to read a record; a two-seat close would double the cost for a judgement no rotation improves. The caller sets the count, so a large or unusual unit may ask for two.
- **The brief.** It names the base commit and the head commit by full hash, the handover's path, and the roadmap rows the unit touched. Naming a date or a branch name instead is the framing failure the `2026-09-21` entry records.
- **Cost.** One model pass per closed unit, at the moment the close lands. The reviewer runs on the closed tree, so the seat is not asked to reason about a worktree it does not hold.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The check scope is eight named checks, each traced to an existing rule | the row left "the existing review dimensions" unnamed, so no seat could be briefed consistently and no finding could name a check | this record, The check scope |
| The seat returns a report and does not block the close | a blocking counterparty at a gateless close recreates the operator dependency the mechanism removes; the delta is a recorded, checkable report | this record, The verdict and where it lands |
| The verdict vocabulary is the seat's existing `APPROVE`/`HOLD` | a second vocabulary for one judgement is a synonym the terminology surface forbids | this record, The verdict and where it lands |
| The check scope names no code-quality dimension | the existing review prompts own those, and their judgement classes stay with the reviewer | this record, What the seat does not check |
| The report lands as a Findings row naming the close | the handover is the unit's one record, and a report kept anywhere else is not read by the next iteration | this record, The verdict and where it lands |

## Rows this design refines

1. **The counterparty check scope** -- the eight checks, their evidence and their verdict, as the brief a close passes a seat. The counterparty row's unnamed clause is what this replaces.
2. **The counterparty's report lands in the closed unit's handover** -- the Findings row, its `Triaged to:` destination, and the HOLD rule.
3. **The three gateless closes name the seat** -- the autonomous `/iter` close, the `/package-branch` packaging step, and the merge-back audit; each names the seat invocation and the artifact it reads.

Kept as a deferred decision, not a row: whether `/package-branch` and `taskq_verify` invoke the seat themselves or only require that it was invoked. Both are build questions, and the answer depends on the build's shape.
