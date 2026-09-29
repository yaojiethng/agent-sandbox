---
description: Run a task fan-out as a queue of worker-requested break points over per-task worktrees, with synchronous operator joins, re-queue on clear, final verification, a write-back proposal judged by the operator, a verdict-scoped bring-back, and a clean close. Use when several segments of work need the operator's decision at their own boundaries.
argument-hint: "[task list - the tasks to fork, each a track with a worker - optional]"
---

> $@

# Task-Queue - The General Sequencing Primitive (Main-Agent Template)

**Scope:** how the primary runs a fan-out as a queue: the per-task fork, the break points the workers request, the synchronous joins, the re-queue rule, the final verification, the write-back proposal, the bring-back verdict, and the clean close.

## Purpose

task-queue is a sequencing primitive, not a loop workflow and not a task shape. The caller supplies the tasks, their segments, and what a well-specified completion is. The primitive owns the machinery: the fork, the break-point queue, the join, the continue decision, the final verification, the write-back proposal, and the bring-back merge.

The queue is the load-bearing form. A worker runs a segment, stops, and requests a break point; the primary records the request, schedules it, and triggers it. The trigger is the join: the primary holds, re-orients the operator, and waits. Clearing the break point re-queues the task for its next segment. The final break point carries the task to verification, the proposal, the verdict, and the merge.

The queue records only requested break points and does not mark their kind. A final break point and a regular break point are the same kind of entry. The distinction lives in how the primary handles a triggered entry: a regular entry re-queues the next segment; a terminal one runs the final verification and takes the bring-back verdict.

The pi extension `task-queue` (loaded automatically from the agent extensions directory) implements the queue, the state machine, the fork, the merge, and the close. This template names the operations; the extension enforces them. The worker protocol is plain files, so any worker - a pi subagent, a bash harness, any provider - can participate.

## When to run this way

Run this way when several independent tracks of work each need the operator's decision at boundaries the worker itself detects. The operator's decision rate, not the agent's turn time, paces the wall clock.

Not this template:

- one track with no operator boundary - use `iter.md` or `auto.md`.
- a read-mostly pass where each subagent returns verdicts and merges nothing - use `fanout-run.md`.

The independence rule of `parallel-auto` applies to the tracks: no track reads or writes a file another track owns. The queue does not make dependent tracks safe; it makes independent tracks reviewable.

## The queue contract

The extension holds these rules; a violation is a tool error, and the error names the rule:

- Every recorded request enters the queue exactly once. A request id recorded twice is rejected.
- Every entry passes request -> scheduled -> triggered, in that order, and triggers at most once.
- Entries trigger in request order per task. Cross-task order is the primary's choice; the queue does not constrain it.
- One task has at most one pending break point. The worker holds until its break point is cleared.
- Every entry references exactly one task, one worker, and one working directory; the references are the same at trigger as at record.
- A task accepts new segments only while forked, active, or failed. Verified, merged, discarded, and retired tasks are closed.
- A task verifies only after its worker requested the terminal break point with nothing pending.
- A merge runs only after the final verification passed, over an existing proposal.
- The merge applies exactly the verdict: all, partial, or none. Partial must name a subset of the proposal.
- A worktree and its branch are removed only at retire; the close refuses while any registered worktree or branch survives, and while any unregistered leftover of an aborted fork survives.

## Step 1 - Fork

Fork every task before dispatching anything: one worktree and one branch per task, all cut from the same baseline commit. Keep the primary's tree clean for the whole run.

Call `taskq_fork` per task with the task id, the worktree path (a sibling of the main tree, never inside it), and the baseline. The extension cuts the branch and registers the task. Baseline mismatch is unreproducible hell: one baseline for all tasks.

Dispatch one fresh subagent per task into its own worktree, on its own branch, with a brief that names the task, its segments, its owned files, its report, and the worker protocol. Wrap every dispatch so its failure and its duration are visible - the wrapper from `parallel-auto` Step 3, verbatim:

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

A pi worker uses the `taskq_worker_request` tool, which writes exactly this document and never overwrites one. Any other worker writes the same file by hand. `status` is `running` for a regular break point and `done` for the terminal one.

Workers never write into the main tree. Their taskq directory never joins a write-back proposal.

The primary's loop per request document:

1. `taskq_poll` - scan all task worktrees for unrecorded request documents. A request that advanced while an earlier one is pending is a protocol warning: the worker raced its own hold.
2. `taskq_record` - record the request into the queue (state: requested). The document must sit in the task's own worktree.
3. `taskq_schedule` - move the entry to scheduled. The primary chooses the cross-task order by the order it schedules.
4. `taskq_trigger` - trigger the entry. This is the dequeue, and the join payload comes back: the task, the worker, the worktree, the worker's message, and the segment the worker changed since the last break point.

## Step 3 - Join

Hold at each triggered break point. Present the operator the join payload: what the worker changed since the last break point, what the worker asks, and what the options are. Then wait. The hold is the point of the primitive; do not advance, do not merge, do not dispatch the next segment until the operator decides.

## Step 4 - Re-queue

When the operator clears a break point, re-dispatch the same worker into the same worktree with `pi --continue` (or `--fork` on the same session log). The same directory and the same session supply the conversation history, so the continued worker is the same agent state by construction.

The cleared break point re-enqueues the task for its next segment: the worker runs to its next boundary and requests the next break point, which enters the queue exactly once as a new entry. A request id is never re-recorded.

## Step 5 - Terminal break point and final verification

When the worker's request document carries `"status": "done"`, the worker has terminated. Handle it like any break point - record, schedule, trigger, join - and then run the final verification: the termination audit. Confirm in the task's worktree that the worker returned the output and wrote the report as directed: read the diff, not the summary; run the checks the brief named. Do this in the worker's worktree, by the primary, before any merge.

Record the audit outcome with `taskq_verify` (`passed` or `failed`). The extension refuses to record a verification while any break point is pending or before the worker's terminal request - verification is not a per-segment gate, and it never runs mid-segment.

A failed verification becomes a repair brief to the same worker, into the same worktree, on the same branch: the defect, the evidence, and the numerical acceptance criterion. The worker's next terminal request reopens verification.

## Step 6 - Write-back proposal and verdict

Distill the verified track into a write-back proposal: `taskq_proposal` computes the changed paths of the worker branch against the baseline, minus the worker's protocol files and any path the primary excludes. Write the description the operator should judge - what this track proposes to bring back, and why.

The acceptance judgement is the same hold as any other break point, with a terminal verdict added on top: present the proposal, take the verdict. The verdict has a bring-back scope:

- `all` - merge the whole proposal.
- `partial` - merge exactly the subset the operator names. A path outside the proposal is rejected.
- `none` - park or discard the track. The extension archives the branch diff into the run record.

A regular break point never makes a bring-back decision. The final break point is the sole place that decision is made for a task.

## Step 7 - Merge

Call `taskq_merge` with the verdict. The merge applies exactly that verdict, neither more nor less, and only after the final verification passed. The merge refuses only when a path the verdict touches is dirty in the main tree: the primary's own mid-edit of a file a verdict is bringing back is a conflict, and an unrelated dirty path never blocks a merge. Verdicts accumulate in the working tree; commit the merged content once the batch of verdicts is complete. The apply is atomic, so a rejected merge leaves the tree untouched.

A merge conflict is a proposal-level problem, not a tree-level one: resolve it by re-distilling the proposal, then merge again. A merge interrupted between the apply and the record resumes on retry: the extension recognizes the already-applied verdict and records it. Two verdicts touching the same path refuse the second; the independence rule - no track owns a file another track owns - keeps verdicts disjoint.

## Step 8 - Records, retire and close

No worker writes a record. Records are the primary's, written after the merge from verified evidence. The run record - the queue journal, the request documents, the archived diffs - lives in the run state directory and is primary-written. The state directory defaults to a sibling of the repo root, named `.taskq-<repo name>`; it never lives inside the main tree, because the merge gate requires the main tree clean and the record must not dirty it. `TASKQ_STATE_DIR` overrides the location.

Export anything the operator wants to keep before retiring the track: `package_branch` over a clone of the task's repository, per `parallel-auto` Step 2.

Call `taskq_retire` per decided task: the extension prunes the branch, removes the worktree, and then records the retire. It refuses while the worktree holds any file outside the taskq protocol directory, and a failed prune leaves no trace in the run record: the task stays merged and the journal stays silent, so a re-run after the export completes the retire. Then call `taskq_close`: it audits the exactly-once identities over the whole run (every recorded request produced exactly one entry; every entry triggered exactly once) and refuses while any registered worktree or branch survives, or while any worktree or branch the run created but no task registered is left behind.

A closed run's state directory stays put, and every tool then reports the run closed. To run the same checkout again, archive or delete the directory by hand, `mv .taskq-<repo name> <your archive>`. Keep it while the outcome is still being written back: the journal, the request documents, and the archived diffs are the run record, and the state directory keeps it out of the main tree.

## Failure modes

(a) **A worker requests a break point with uncommitted deliverable files.** The segment is not reviewable and the branch diff cannot carry it. Verify the worktree is clean before triggering; the prompt to the worker makes commit-before-request the rule.

(b) **A request document overwritten before the primary records it.** The worker's `taskq_worker_request` refuses to overwrite; a hand-written protocol can race. `taskq_poll` flags the warning; record the surviving document and treat the lost one as never requested.

(c) **A duplicate record of the same request id.** Rejected by the extension; the error names the entry that already owns the request.

(d) **A dirty main tree on a path the verdict touches.** The merge refuses and names the path. Either the primary is mid-edit of a file another verdict is bringing back, or two verdicts touch the same owned file. Move or commit the primary's edit, or merge the earlier verdict first, then merge again.

(e) **A merge that does not apply.** The apply fails atomically; the proposal did not match the worker branch state. Re-distill, do not force.

(f) **A worktree or branch left at close.** `taskq_close` refuses and names the track or the leftover. Retire a decided track first; remove an unregistered leftover by hand, because an aborted fork can leave one.

(g) **A verified track that needs more work.** Verified is closed to new segments. The door back into the queue is a failed verification, then a repair segment.

## Invariants

- One task per worktree, one branch per task, one baseline for all tasks, a branch rather than a detached HEAD.
- The queue records only requested break points, never marks their kind, and admits a request id exactly once.
- Break points trigger in request order per task, at most once, and only through request -> scheduled -> triggered.
- One pending break point per task; the worker holds until its break point is cleared.
- Every entry references exactly one task, one worker, and one working directory, and the references are the same at trigger as at record.
- No worker write lands in the primary tree except through the primary's merge; the main tree is mutated only by the primary.
- Final verification runs only after the worker's terminal request, never mid-segment; no merge runs before it passes.
- The merge applies exactly the bring-back verdict - all, partial, or none - over the proposal the operator judged.
- Records are primary-owned; retire removes the worktree and prunes the branch; close leaves no registered worktree and no leftover branch.
