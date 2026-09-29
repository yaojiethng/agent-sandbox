---
description: Run a task fan-out as a fork and a join: per-task worktrees, a blocking join that hands each worker-requested break point to the operator, both re-queue routes, a usable or not-usable termination audit, a write-back proposal judged by the operator, a bring-back that writes a file set and prunes the worktree, and a clean close. Use when several segments of work need the operator's decision at their own boundaries.
argument-hint: "[task list - the tasks to fork, each a track with a worker - optional]"
---

> $@

# Task-Queue - The General Sequencing Primitive (Main-Agent Template)

**Scope:** how the primary runs a fan-out as a queue: the per-task fork, the break points the workers request, the blocking join, the re-queue routes, the termination audit, the write-back proposal, the bring-back, and the clean close.

## Purpose

task-queue is a sequencing primitive, not a loop workflow and not a task shape. The caller supplies the tasks, their segments, and what a well-specified completion is. The primitive owns the machinery: the fork, the join, the continue decision, the termination audit, the re-queue, the write-back proposal, and the bring-back.

The queue is the load-bearing form. A worker runs a segment, stops, and requests a break point. The primary blocks in one join call until the request is ready, and the call delivers the break point as one atomic transition. Handling the delivered break point is the join: the primary holds, re-orients the operator, and waits. Clearing a regular break point re-queues the task for its next segment. The terminal break point carries the task to the audit, the proposal, and the bring-back.

A task has four phases, and each names the one thing that moves it: `forked`, `active`, `terminated`, `retired`. The audit decides the way out of `active`: a `usable` audit terminates the task, and a `not-usable` audit leaves it in the queue for another segment. Only a terminated task is brought back, and the bring-back is what retires it.

The queue records only requested break points and does not mark their kind. A final break point and a regular break point are the same kind of entry. The distinction lives in how the primary handles a delivered entry: a regular entry re-queues the next segment; a terminal one runs the audit.

The pi extension `task-queue` (loaded automatically from the agent extensions directory) implements the queue, the state machine, the fork, the join, the re-queue, the bring-back, and the close. This template names the operations; the extension enforces them. The worker protocol is plain files, so any worker - a pi subagent, a bash harness, any provider - can participate.

## When to run this way

Run this way when several independent tracks of work each need the operator's decision at boundaries the worker itself detects. The operator's decision rate, not the agent's turn time, paces the wall clock.

Not this template:

- one track with no operator boundary - use `iter.md` or `auto.md`.
- a read-mostly pass where each subagent returns verdicts and merges nothing - use `fanout-run.md`.

The independence rule of `parallel-auto` applies to the tracks: no track reads or writes a file another track owns. The queue does not make dependent tracks safe; it makes independent tracks reviewable.

## The queue contract

The extension holds these rules; a violation is a tool error, and the error names the rule:

- Every recorded request enters the queue exactly once. A request id recorded twice is rejected.
- Every entry passes request -> scheduled -> triggered, in that order, and triggers at most once. The join performs the whole passage in one call, so the queue never rests in the first two states.
- Entries trigger in request order per task. Cross-task order is the primary's choice; the queue does not constrain it.
- One break point waits on the operator at a time. The join reports the undecided one instead of delivering a second payload beside it.
- Every entry references exactly one task, one worker, and one working directory; the references are the same at trigger as at record.
- A task accepts new segments only while `forked` or `active`. `terminated` and `retired` are closed.
- A task audits only after its worker requested the terminal break point with nothing pending.
- A `not-usable` audit leaves the task in the queue; the next step is a re-queue, not a second audit of the same break point.
- A bring-back runs only from `terminated`, over an existing proposal, and writes exactly the file set the primary names. A named path outside the proposal is rejected. The empty file set is legal: it writes nothing and still prunes. A bring-back whose worktree is gone resumes only on the record that attempt left; without it the call is refused and writes nothing, because a removal the tool did not perform is not evidence of a write.
- A worktree and its branch are removed only at the bring-back; the close refuses while any registered worktree or branch survives, and while any unregistered leftover of an aborted fork survives.
- One primary writes one state directory. Every state-mutating call runs its whole load-derive-save under the state directory's ownership lock, and a second process on that directory is refused with the live owner named.

## The join contract

`taskq_join` is the queue's `fork(2)` and `wait(2)`. One call is one delivery:

- **It blocks.** The call blocks the primary's turn until a break point is ready or the timeout expires. `timeoutMs` is required and bounds the block. Prefer a generous timeout over any sleep, and never sleep and re-poll: the call is the wait, and a timeout is a timed wait that changes nothing. A timeout that is not a finite positive number is refused at once, and a `taskId` no task holds is refused at once rather than at the end of the wait.
- **It subsumes the whole transition.** The call scans the task worktrees, records the worker's request, schedules it, triggers it, and returns the join payload. No other tool deploys a break point, so the call cannot be made out of order.
- **It delivers at most one break point, exactly once.** A retry neither re-delivers nor skips a break point.
- **It holds the operator's one hold.** While a delivered break point is undecided, the call returns that hold, the worker's message, and the step that clears it. A regular break point clears when the worker requests again; a terminal one clears at the audit. A worker that requested again already decided its previous break point, terminal or not. A re-queued task holds on the worker's next request: the re-queue the not-usable audit asked for is already recorded, so the hold never names it a second time.
- **It selects.** The named `taskId` wins; the default is the earliest forked task that has a break point ready, and inside a task the earliest request.
- **It reports a timeout as a result, not an error.** A `timeout` outcome means no break point became ready. Nothing was recorded, scheduled, or triggered.
- **It archives what it admitted.** The archive holds the exact bytes of the request document the join validated, so the record and the document can never diverge.
- **It carries the diagnostics.** The payload names the uncommitted paths left in the worker's worktree, which the branch diff does not carry, and the protocol notices the scan collected: a broken request document, one whose name and content disagree, a worker that requested again before its hold cleared, and a request document a task the queue has already closed can never admit. A segment whose only change is the worker's protocol files reports no deliverable at all, never the protocol diff as a segment.

## The state map

The extension keeps four task phases and three queue-entry states. Every one of them maps onto a step of the loop below.

| Task phase | Queue-entry state | What the primary does | Loop step |
|---|---|---|---|
| forked | none | dispatch the worker into its worktree | fork |
| active | none, between break points | let the worker run its next segment | join, after the operator cleared |
| active | triggered, undecided | present the payload and hold for the operator | join, payload |
| active | requested or scheduled, only mid-call | nothing: the join passes through both states inside one transition | join |
| active | triggered, audited not-usable | roll the worktree back in place, or cut a fresh one | re-queue |
| terminated | triggered, audited usable | build the proposal and take the file set | proposal, bring-back |
| retired | triggered, brought back | audit the run and close it | close |

Two rows carry the contract. A delivered break point rests in `triggered` and waits for the operator; a task that re-requested already decided its previous break point. A queue written before the join existed can rest in `requested` or `scheduled`; the join finishes the transition for it.

## Step 1 - Fork

Fork every task before dispatching anything: one worktree and one branch per task, all cut from the same baseline commit. Keep the primary's tree clean for the whole run.

Call `taskq_fork` per task with the task id and the baseline. The extension owns the worktree location: it cuts the worktree and the branch at the run-scoped canonical path, outside the main tree, and returns that path. The caller creates no worktree and passes no path. The collision check, the cut, the registration, and the undo of a failed registration are one locked transaction, so two forks on one state directory cannot interleave. A leftover worktree, branch, or directory at the canonical path is refused with the path named; clear it by hand and fork again. Baseline mismatch is unreproducible hell: one baseline for all tasks.

One primary writes one state directory. A second process on the same directory is refused with the live owner's lock named, because the lock is what keeps two writers from overwriting each other's record. Do not start a second primary against the same run.

Dispatch one fresh subagent per task into the worktree the fork returned, on its own branch, with a brief that names the task, its segments, its owned files, its report, and the worker protocol. Wrap every dispatch so its failure and its duration are visible - the wrapper from `parallel-auto` Step 3, verbatim:

```bash
cd "<worktree>" && S=$(date +%s) && pi --provider <p> --model <m> --thinking <t> -p "$(cat <brief>)" && echo "RC=$?" && echo "SECONDS=$(( $(date +%s) - S ))"
```

## Step 2 - Segments and break points

A worker advances under its own validation. It commits its segment in its own worktree, then requests a break point by writing one immutable document into its own worktree:

```text
<worktree>/taskq/requests/<requestId>.json
```

```json
{ "taskId": "<taskId>", "requestId": "<taskId>-<n>", "status": "running", "message": "<what the operator must know>", "at": "<iso time>" }
```

A pi worker uses the `taskq_worker_request` tool, which writes exactly this document and never overwrites one. Any other worker writes the same file by hand. `status` is `running` for a regular break point and `done` for the terminal one. The worker stops there and waits.

Workers never write into the main tree. Their taskq directory never joins a write-back proposal.

The primary does not read the request documents: `taskq_join` reads them, validates them, and delivers one.

## Step 3 - Join

Call `taskq_join` with a generous `timeoutMs` and let it block. The call returns the join payload: the task, the worker, the worktree, the branch, what the worker asks, and the segment the worker changed since the last break point.

Hold at each delivered break point. Present the operator the payload: what changed, what the worker asks, what is uncommitted, and what the options are. Then wait. The hold is the point of the primitive; do not advance, do not bring back, do not dispatch the next segment until the operator decides.

A call that returns `timeout` is normal while a worker runs its segment: join again. A call that returns `held` names the break point the operator still holds, what the worker asked, and the step that clears it: do that step before joining again.

## Step 4 - Clear a regular break point

When the operator clears a regular break point, re-dispatch the same worker into the same worktree with `pi --continue` (or `--fork` on the same session log). The same directory and the same session supply the conversation history, so the continued worker is the same agent state by construction.

The cleared break point needs no queue call: the worker runs to its next boundary and requests the next break point, which the join delivers as a new entry. A request id is never delivered twice.

## Step 5 - Terminal break point and the termination audit

When the delivered payload carries `requestStatus` `done`, the worker has terminated. Hold at it like any break point, then run the termination audit. Confirm in the task's worktree that the worker returned the output and wrote the report as directed: read the diff, not the summary; run the checks the brief named. Do this in the worker's worktree, by the primary, before any bring-back.

Record the audit with `taskq_verify` and one of two outcomes: `usable` or `not-usable`. The extension refuses to record an audit while any break point is pending, before the worker's terminal request, and for a second audit of the same terminal break point. The audit is structural: it records whether the return arrived as directed, never whether the work is good.

A `usable` audit moves the task to `terminated`. That is the only phase a bring-back runs from.

A `not-usable` audit leaves the task in the queue. It is not a failure state and it needs no second audit: the next step is a re-queue.

## Step 6 - Re-queue a not-usable audit

Call `taskq_requeue` with the task id and a route. The route answers one question: where is the damage?

- `in-place` - the damage is in the segment's content. The extension rolls the worktree back to the head the last delivered segment reached, clears that segment's uncommitted wreckage, and keeps the worktree, the branch, and the same worker's session log. The worker continues from what it had.
- `fresh` - the damage is in the worktree, its git state, or the environment around it. The extension removes the worktree and the branch, cuts a new one from the baseline, and reseeds the worker's request sequence so no id is reused. Use this when a rollback would carry the damage forward.

Either route keeps the queue entries: the next segment is a new entry, never a second run. Either route returns the task to the queue - `in-place` to `active`, `fresh` to `forked` - and neither touches the main tree.

The `fresh` route is a forced removal, so package the branch before calling it. The `in-place` route is not forced, but packaging before any re-queue keeps the discarded segment readable. Package with the durability packaging of `/package-branch`, against the task branch and its baseline:

```bash
bash -c 'source /opt/sandbox/lib/package_branch.sh && package_branch "<worktree>" "$HOME/workspace/output" false "<baseline>"'
```

Then re-dispatch the worker with the defect, the evidence, and the numerical acceptance criterion. Its next terminal request reopens the audit, and the join delivers it like any other break point.

## Step 7 - Write-back proposal and file set

Distill the usable track into a write-back proposal: `taskq_proposal` computes the changed paths of the worker branch against the baseline, minus the worker's protocol files and any path the primary excludes. Write the description the operator should judge - what this track proposes to bring back, and why.

The acceptance judgement is the same hold as any other break point, with the file set added on top: present the proposal, take the file set.

- A named subset - write exactly those paths into the main tree. A path outside the proposal is rejected.
- The empty set - write nothing back, and keep the branch diff in the run record instead.

A regular break point never makes a bring-back decision. The terminal break point is the sole place that decision is made for a task.

## Step 8 - Bring-back

Package the branch before the bring-back. The bring-back prunes the worktree and the branch, so a task that comes back without a package is gone. Run `/package-branch` for the task's branch first, using the same command as step 6.

Then call `taskq_merge` with the task id and the file set. One call writes the file set, removes the worktree, prunes the branch, and records the retirement - there is no separate retirement step. The call refuses when a path the file set names is dirty in the main tree: the primary's own mid-edit of a file the file set brings back is a conflict, and an unrelated dirty path never blocks a bring-back. It also refuses when the worktree still holds content outside its protocol directory, because the prune would discard content the primary never wrote back. The prune-refusal is asked before the call writes anything, and the write itself applies atomically, so that refusal leaves the main tree untouched: nothing is written and, for the empty file set, nothing is archived. Only a worktree that grows content between that check and the prune refuses after the write, and the re-run resumes that attempt from the record it left. Brought-back content accumulates in the working tree; commit it once the batch is complete.

A bring-back conflict is a proposal-level problem, not a tree-level one: resolve it by re-distilling the proposal, then bring back again. A bring-back interrupted between the write and the record resumes on retry: the extension recognizes the already-written file set and records it. A call interrupted after the prune resumes on the bring-back record that call left, reports `resumed`, and does not re-derive content it can no longer read. A worktree and branch removed by hand leave no such record, so that re-run is refused instead of inferring a write; the extension never treats a removal it did not perform as evidence. Two file sets touching the same path refuse the second; the independence rule - no track owns a file another track owns - keeps them disjoint.

## Step 9 - Records and close

No worker writes a record. Records are the primary's, written after the bring-back from verified evidence. The run record - the queue journal, the archived request documents, the archived diffs - lives in the run state directory and is primary-written. The state directory defaults to a sibling of the repo root, named `.taskq-<repo name>`; it never lives inside the main tree, because the bring-back needs the main tree clean and the record must not dirty it. `TASKQ_STATE_DIR` overrides the location. The worktrees follow the state directory: each run owns one worktree root beside the repository, and each task owns one worktree in it.

Call `taskq_close` when every task is retired. It audits the exactly-once identities over the whole run (every recorded request produced exactly one entry; every entry triggered exactly once) and refuses while any registered worktree or branch survives, or while any worktree or branch the run created but no task registered is left behind.

A closed run's state directory stays put, and every tool then reports the run closed. To run the same checkout again, archive or delete the directory by hand, `mv .taskq-<repo name> <your archive>`. Keep it while the outcome is still being written back: the journal, the archived request documents, and the archived diffs are the run record, and the state directory keeps it out of the main tree.

## Failure modes

(a) **A worker requests a break point with uncommitted deliverable files.** The segment is not reviewable and the branch diff cannot carry it. The join payload names the uncommitted paths; have the worker commit and re-request, and treat the segment as incomplete until it lands.

(b) **A request document that does not parse, names another task, or disagrees with its own file name.** The join skips it and names it in the payload's notices; a later call delivers the next valid break point. Fix or delete the document by hand; the queue never admits a broken one.

(c) **A worker that requested again before its hold cleared.** The join delivers the requests in request order and names the race in the payload's notices. The segments are serialized by the queue, so nothing is lost; tighten the worker brief so it stops at the request.

(d) **A dirty main tree on a path the file set names.** The bring-back refuses and names the path. Either the primary is mid-edit of a file another bring-back is writing, or two file sets name the same owned file. Move or commit the primary's edit, or bring back the earlier file set first, then bring back again.

(e) **A file set that does not apply.** The apply fails atomically; the proposal did not match the worker branch state. Re-distill, do not force.

(f) **A worktree or branch left at close.** `taskq_close` refuses and names the task or the leftover. Bring the task back first; remove an unregistered leftover by hand, because an aborted fork can leave one.

(g) **A join that returns `held` again and again.** The operator has not decided the break point the join named. Handle it - the audit for a terminal break point, a re-dispatch for a regular one - before joining again.

(h) **A not-usable audit that does not want a re-queue.** The task stays in the queue either way. Pick the route by the damage: `in-place` for the segment's content, `fresh` for the worktree or its environment.

(i) **A second process on the state directory.** The call is refused with the live owner named. One primary writes one state directory; do not race it.

(j) **A worktree that still holds unwritten content.** The bring-back refuses with `prune-failed` and names the paths, because the prune would discard worker content the primary never wrote back. The main tree is NOT already written when this happens: the refusal is checked before any write, so nothing landed and, for the empty file set, nothing was archived. Write the paths back, park them, or bring them into a segment, then bring back again. The same code refuses after the write when a worker that did not stop at its request added content between the check and the prune; the re-run then resumes that attempt from the bring-back record it left and reports `resumed`.

(k) **A request document a closed task can never admit.** A worker that ran past its terminal request, or past its bring-back, leaves a document in its worktree that no join admits. The join's payload notices name the document and the phase that closed the task. Read it in the worker's worktree and decide by hand; the queue never delivers it.

(l) **A bring-back whose worktree is gone with no record of a write.** The call is refused with `bring-back-unprovable` and names the task, its phase, and the record that is missing. A gone worktree proves a write only when the extension's own prune removed it; a removal by hand - `git worktree remove --force` and `git branch -D` - satisfies the same predicate without any write behind it. The main tree is NOT already written when this happens: the refusal precedes every write, the task stays `terminated` rather than retiring, nothing is archived, and the journal records no bring-back. Restore the worktree and the branch from a branch package and bring back again; with no package, recover the file set by hand and decide the task's fate by hand. The same code refuses a re-run whose file set differs from the one the record names, because a record of a write is not a record of a different write.

## Invariants

- One task per worktree, one branch per task, one baseline for all tasks, a branch rather than a detached HEAD, and a worktree location the fork owns.
- The queue records only requested break points, never marks their kind, and admits a request id exactly once.
- Break points trigger in request order per task, at most once, and only through request -> scheduled -> triggered - a passage the join performs in one call.
- One break point waits on the operator at a time; the join delivers the next one only after the hold clears.
- Every entry references exactly one task, one worker, and one working directory, and the references are the same at trigger as at record.
- No worker write lands in the primary tree except through the primary's bring-back; the main tree is mutated only by the primary.
- The audit runs only after the worker's terminal request, never mid-segment. A `usable` audit is the only way to `terminated`, and a `not-usable` one is answered by a re-queue, not by a second audit.
- A re-queue keeps the queue entries and the main tree: the in-place route rolls back to the last delivered head, the fresh route cuts from the baseline.
- The bring-back writes exactly the file set the primary named - a subset of the proposal, or the empty set - over the proposal the operator judged.
- Records are primary-owned; the bring-back removes the worktree and prunes the branch; close leaves no registered worktree and no leftover branch.
- One primary writes one state directory, and every state-mutating call is one locked load-derive-save.
