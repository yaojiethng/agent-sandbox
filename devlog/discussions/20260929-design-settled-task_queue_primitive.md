# Design: Task-Queue as a General Sequencing Primitive

**Status:** settled
**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** design (consolidated record: requirements, procedure, findings)

## Context

The parallel fan-out workflows couple a sequencing mechanism with a task shape. `parallel-auto.md` mixes the fork (worktree, branch, subagent dispatch), the task shape (well-specified auto units), and a gating contract (unattended) inside one prompt. This coupling is the defect: the prompt is badly shaped because it does not separate the primitive from the shape it drives. The task-queue is the primitive that fills this gap: a general sequencing mechanism that the fan-out workflows each sit on, without defining a task.

This document is the consolidated record of the primitive. It replaces the earlier design draft, the fan-out comparison contract, and the comparison report. It carries the requirements (I1-I13 plus the design decisions), the procedure (the fork/join/re-queue mechanism and the evaluation rubric), and the findings (the language and adopt-vs-roll decisions and the open issues). The immutable invariant set and the decision rationale live here once, not across three files.

## Requirements

### The invariant set I1-I13

The task-queue mechanism satisfies these invariants. They are the standing requirements any implementation must hold; the score table in the Findings section judges candidates against them by name.

**Queue integrity.**

- **I1 - No loss, no duplication.** Every enqueued break point is dequeued exactly once for triggering; a re-enqueued break point re-enters exactly once.
- **I2 - Order preservation.** Break points trigger in request order per task. Cross-task order is the primary's choice, not constrained by the queue.
- **I3 - Referential integrity.** Every queue entry references exactly one task, one worker, and one working directory, and the referenced task/worker/directory exist and are the same on dequeue as on enqueue.

**State machine.**

- **I4 - Legal transitions only.** A break point transitions request -> scheduled -> triggered only in that order. Triggering a break point that was not requested is an error. A scheduled break point not yet triggered cannot be re-scheduled.
- **I5 - Single trigger.** A break point triggers at most once.

**Single writer.**

- **I6 - No worker write to the main tree.** No worker's worktree write lands in the primary tree except through the primary's merge. The main tree is mutated only by the primary.
- **I7 - Write-back scope discipline.** The merge applies exactly the bring-back verdict (all, partial, or none) the operator's final verdict named, neither more nor less.

**Verification.**

- **I8 - Verification only at termination request.** Final verification runs only after the worker requests it (the terminal break point), never mid-segment.
- **I9 - Verification-before-merge ordering.** No track merges before its final verification confirms the output and report landed as directed.

**Lifecycle.**

- **I10 - Worktree hygiene.** Every worktree and branch is retired or pruned at a clean close; no registered worktree or leftover branch survives a clean close. A close that encounters an already-absent target (a worktree or branch already removed) treats it as success, not failure, so a close interrupted and re-run completes.

**Durability and atomicity.** This class is the load-bearing addition. The queue is durable state; its file-backed persistence exists to survive interrupted writes and process crashes. The invariants above govern the steady state; this class governs the transitions that change it. A durable queue whose transitions are non-atomic or whose close is not resumable cannot hold I1-I10 under any real failure, and a parse or write failure must never leave the queue in an unrecoverable state.

- **I11 - Single atomic transition.** Every state transition is one atomic write (a single rename, or an equivalent atomic rewrite), not a sequence of writes whose partial completion leaves a corrupt or half-applied state. A transition either commits whole or leaves the prior state intact and the queue resumable at that prior state.
- **I12 - No loss, no orphan on failure.** No operation that fails mid-way may spend, consume, or erase a resource (a re-queue arm, a queue entry, a verification mark, a verdict) unless the whole operation committed. A failed operation leaves every resource it touched in its pre-operation state, and a retry of the operation is safe.
- **I13 - Resumable close.** A close is idempotent and resumable: if it is interrupted, a re-run completes it. It never permanently fails on a target that is already absent, and it never leaves the queue in a state from which no API can recover.

**Structural preference.** A transition should be *structurally* atomic (state encoded so each change is a single atomic rename) rather than made atomic by bolted-on rollback of a multi-write sequence. Cheap rollback is acceptable only where the failure window cannot cross a resource-ownership boundary. The preference is that I1/I4/I5 hold by construction, not by enforced checks.

### The design decisions

| Decision | Rationale |
|---|---|
| task-queue is a general agent utility in `src/reasoning/agent/prompts/`, not a loop workflow | it is a sequencing primitive that accepts many task shapes; the workflow directory holds loop templates |
| Keep worktree and branch in the primitive's contract | it is what makes the coding-agent fork safe, mergeable, and verifiable per-track |
| Re-queue = same worker continues, via the same directory and the same pi session log | pi's active session branch supplies the conversation history, so "same worker" and "fresh dispatch on the same log" are the same agent state |
| This iteration delivers the primitive only | `fanout` and `parallel-auto` refactor onto it later |
| `parallel-auto` is badly shaped and will be rewritten to sit on this primitive | it mixes fork with task shape and gating contract |
| The unit of the fork-and-join is the segment, not the whole task | a task can have multiple break points; the operator's feedback is wanted at each, and the sequencing mechanism must be breakable at arbitrary points in the task's lifecycle |
| The break points are part of the task spec, supplied by the caller | the primitive does not invent the task's segmentation |
| Acceptance judgement = the final break point | it is the same hold/join with no further changes queued, plus a bring-back verdict |
| Bring-back scope is all, partial, or none | the merge is parameterized by exactly what the operator brings back, so it is not an all-or-nothing end-of-run event |
| The final verdict judges a write-back proposal, not a raw diff | the primary distills each worker's track into a presentable proposal; that is the unit of judgement at the final break point |
| Single writer on the main sandbox; workers never write into the main tree | no async git write raced into the main tree; the record-ownership rule extends to every main-tree write |
| The worker owns its validation and drives its own break points | the worker judges when it needs input; the primary does not pause it per segment |
| Per-track verification is a final check at worker termination, not a per-segment gate | it confirms the worker returned the output / wrote the report as directed |
| Verification is requested by the worker, scheduled and triggered by the primary | the primary controls when the check runs and what it means; the worker signals readiness |
| The worker-queue records only requested break points and does not mark their kind | final-versus-regular is not a queue property; it is how the primary handles a break point once dequeued |
| Durability and atomicity are a first-class invariant class (I11-I13), not an afterthought | both independent thermo-nuclear reviews converged on non-atomic transitions and non-resumable close as the blocker; the queue is durable state whose failure paths are load-bearing |
| Transitions are structurally atomic by preference (single rename / pathname-as-state), not made atomic by bolted-on rollback | the reviewers' guidance is that I1/I4/I5 should hold by construction |
| Track B is adopt-vs-roll-our-own, decided by a comparison, not an immediate fold-back | the operator found a battle-tested extension claiming similar behavior; compare it against our candidate for learning points before adopting or building |

## Procedure

### The fork/join/re-queue mechanism

The unit of the fork-and-join is the segment, not the whole task. A task decomposes into segments, each ending at a break point where the operator's synchronous feedback is wanted. A worker runs until the next break point, holds for the operator, and on clearing continues to the next break point. This is what makes the sequencing mechanism breakable at arbitrary points in a task's own lifecycle.

- **Fork:** per-task worktree and branch, one fresh subagent per task (or a resumed session), dispatched concurrently, all from one baseline commit. Wrapped dispatch with visible failure and duration.
- **Break points requested by the worker, scheduled and triggered by the primary.** The worker runs its own validation and judges when it needs input. It requests a break point; the primary schedules and triggers it. The primary never pauses the worker at a segment the worker did not request.
- **The worker-queue sees only a queue of requested break points, and does not distinguish their kind.** The queue holds one uniform list of requested break points. "Final break point (leads to verification after)" is not a property the queue encodes; from the queue's view every entry is just a requested break point. The distinction lives in how the primary handles a break point once dequeued: a regular break point re-queues the next segment; a terminal one runs the final verification, builds the write-back proposal, and takes the bring-back verdict.
- **Join:** the primary holds at each dequeued break point, re-orients the operator, and waits for a release or decision. The operator's decision rate paces the wall clock.
- **Re-queue:** when the operator clears a break point, the task goes back into the queue for the next segment. The same worker continues, which maps to pi's session mechanics: `--continue` or `--fork` on the same session log, in the same working directory. The operator sees no meaningful difference between "same worker" and a fresh re-dispatch on the same conversation log, because pi's active session branch supplies the conversation history either way. So "same worker continues" and "fresh dispatch on the same session log" are the same agent state by construction.
- **Per-track verification is a final check, requested by the worker and triggered by the primary.** When the worker terminates it requests verification; the primary schedules and runs it. The check is a termination audit -- it confirms the worker returned the output / wrote the report as directed. It is not a per-segment gate; in-process validation is the worker's job. Verification is, itself, a requested-and-scheduled step: the worker requests it and the primary schedules and triggers it, exactly as it does a break point.
- **Final break point:** the terminal segment ends at a break point where no further changes are queued. The only decision left is what to bring back. The primary constructs a write-back proposal from each worker's track -- a distilled, presentable shape of the proposed write-back -- and the operator judges that proposal at the final break point. This is what makes the acceptance judgement clean: the operator judges a written proposal, not a raw diff.
- **Single writer, no async git writes into the main tree.** The main agent is the sole writer of the main sandbox folder. A worker works only in its own worktree and branch; it never writes into the main tree. The primary merges, applies the accepted proposal, and writes the records. This extends the record-ownership rule to every main-tree write.
- **The final verdict has a bring-back scope of all, partial, or none** over the write-back proposal. The merge is parameterized by exactly the accepted proposal and its scope -- all = merge the whole proposal, partial = merge a selected subset the operator names, none = park or discard the track. The merge is not an all-or-nothing end-of-run event; each task's merge runs over exactly what its final verdict brings back.

The acceptance judgement at the final break point is structurally the same hold as any other break point -- it reuses the join -- with a terminal verdict added on top. Non-final break points decide the next segment; the final break point decides the write-back proposal and its bring-back scope. A regular break point never makes a bring-back decision; the final break point is the sole place that decision is made for a task.

### What the primitive owns and does not own

Owns: the fork procedure, the synchronous operator-join, the re-queue rule, the write-back proposal construction, the single-writer rule, the final per-track verification (scheduled and triggered by the primary), the merge, and the records (primary-owned).

Does not own: the task shape. A caller supplies the task's break points (the segmentation) and what a well-specified task is. The primitive owns the machinery of the break-point hold, the continue decision, and the final bring-back verdict; it does not interpret the task's content. `fanout` (design-option exploration) and a rewritten `parallel-auto` sit on this primitive.

The single "return contract" is replaced by the segmentation: the primitive does not assume one completed return per task. The worker advances under its own validation until it judges it needs input or is done. A task with no defined break points is a single-segment task that runs to completion, at which point the worker terminates and requests its final verification.

### The evaluation rubric for a candidate implementation

A candidate implementation of the primitive is scored on five criteria. **Correctness and performance are primary priorities; maintainability is secondary (readability and modularity are sub-components of maintainability); testability is tertiary.** Correctness ties directly to the invariant set: the candidate holds I1-I13, verifiable by a machine-checkable conformance suite.

| Criterion | Priority | Sub-components |
|---|---|---|
| Correctness | primary | holds I1-I13; verifiable by a machine-checkable conformance suite |
| Performance | primary | measured per-operation cost (enqueue, dequeue, trigger, verify, merge) on the same uncontended host |
| Maintainability | secondary | composed of readability + modularity |
| -- Readability | (sub) | named concepts, self-documenting structure |
| -- Modularity | (sub) | clean separation of queue / state / worktree / merge / record |
| Testability | tertiary | ease of unit testing under the harness; the conformance suite runs in the implementation's own test runner |

**Dispatch contract for a comparison.** Each candidate runs in its own worktree and branch, cut from the same baseline commit, one fresh subagent per candidate, dispatched concurrently. A candidate may read this requirements and procedure section; a candidate implements the primitive per the mechanism and holds every invariant it can. **Suite runs are serialized**: only one subagent runs the suite at a time, because a per-file deadline counts wall time and a verdict measured under load is not a verdict. The verdict is recorded by the primary, not by a candidate. A rejected return becomes a repair brief to the same candidate.

## Findings

### The language decision

Both the bash (Track A) and TypeScript (Track B) candidates reached a reviewer PASS against the strengthened invariant set. The deciding measure is the wall-clock to deliver I1-I13, not the end state, where the two candidates tie on correctness.

**Track B (TypeScript) passed at round 3** ("Consensus reached -- no remaining defects"; 4 minors + 4 nits as follow-ups). Node test suite 101/101; post-merge harness suite 1004/1004. It models the queue as a state machine over one `state.json` outside the main tree; operations are pure functions returning the next state plus journal events, so I1/I4/I5/I11 hold by construction rather than by conventions a reviewer must keep re-deriving. It leads on modularity (12 explicit TS source files with clean queue/state/worktree/merge/record separation) and testability (pure functions over state, node test suite). Performance is recorded as relative-only: the initial driving comparison measured an order-of-magnitude lead, but the exact multiple is not pinned in a committed benchmark artifact.

**Track A (bash) passed at round 8** (`1260106`, suite 1087/1087 across 67 files, 85 conformance units, lint clean) after 8 repair rounds plus the initial review. It chased I7/I11-I13 through bash's non-atomic state: a crash inside a record write left a temp file every reader read as a queue entry; a partial bring-back of a branch-deleted file could not be resumed; an unchecked `reset --hard` let the intent record lie and reopened the merge-none bypass; the residue recognizer was rebuilt four times before the intent-record restructure. Structural atomicity (pathname-as-state, one rename per transition) exists in bash, but bash offers no enforced module boundary, so most safety came from reviewer-discovered fixes rather than from the language. The 1142-line monolith had to be split manually into sourced leaves communicating through implicit globals.

**Decision: land Track B; shelve Track A** with the package-branch bundle (`task_queue_bash_primitive`, 10 numbered diffs), tied to the nushell-revisit (roadmap T4) and bash-architecture (T4/T8) rows.

### The adopt-vs-roll decision

The comparison read the third-party `pi-subagents` v0.73.1 source and docs in full (`src/` = 284 files across 15 modules, `docs/` = 10 files) and scored it against our Track B extension on five dimensions: mechanism overlap, invariant coverage, atomicity and durability, pi-extension integration, and behavior each side lacks.

**Mechanism overlap.** `pi-subagents` is a delegation and orchestration platform. A parent Pi session calls its `subagent` tool once; the tool either launches child Pi sessions from `{ agent, task }` or runs a JavaScript program passed as `workflowScript`, sequenced by `runs.run`/`runs.all`/`runs.lanes`. The sequence is written by the orchestrating model in JavaScript source text held in the memory of one tool call and discarded when the call returns; no queue survives the call. The only worker-to-parent channel is `contact_supervisor` (a question-and-answer channel scoped to a session id), not a break-point queue. The closest things to our concepts are retained `resume` (re-queue on parent action, not on a worker-requested break point), acceptance gates (judge one child result, not a terminal break point), and lane merge evidence (records a merge somebody else performed; no `git apply`, `git am`, or `git cherry-pick` appears anywhere in its source). The overlap is one mechanism out of six: the per-task worktree fork.

**Invariant coverage.** `pi-subagents` holds no queue-class invariant (I1-I5) at all, because it has no queue. It holds the single-writer and hygiene halves of I6 and I10 by construction of its worktree engine, and the per-file half of I11 through a shared atomic writer. It does not hold I7, the invariant the whole primitive exists to serve: the extension never writes a worker patch into the main tree, so there is no scope to discipline.

**Atomicity and durability approach.** Both packages are file-backed; they differ in what the file holds. `pi-subagents` treats durability as per-artifact (every JSON write goes through one atomic writer; the artifacts are run artifacts), with a fail-closed, retain-for-reconciliation philosophy. Ours treats durability as per-run-state: one `state.json` holds the queue, the task records, and the exactly-once request map; operations are pure functions, so every invariant is unit-testable without I/O. The consequence is asymmetric: ours makes I1/I4/I5 hold by construction under a single atomic write; `pi-subagents` makes crash recovery safe by policy across artifacts it never declared as one unit, and its worktree lock is in-process by its own documentation, leaving the cross-queue fork-ownership window open.

**The four crash windows.** Both sides use temp-file-plus-rename for a record write; theirs is the more robust writer (randomized temp name, retry, best-effort cleanup), ours holds a whole-run unit. On the branch-deleted bring-back window, theirs avoids it by capturing the patch to a file before any removal and refusing cleanup until the manifest records that patch -- ours still carries this window in `merge.ts`, which diffs the branch in the main tree. On rollback failure, ours has no multi-step rollback (a transition is a single atomic write); theirs has one, `compensateSetup`, and handles it well but scoped to setup only. On cross-queue fork ownership, ours resolves it with a baseline captured at run open plus a close sweep that refuses an unregistered leftover; theirs serializes allocation with an in-process promise chain that is not a cross-process lock.

**Verdict: roll our own.** Keep the Track B TypeScript extension; do not adopt `pi-subagents` as the primitive. The measure that decides it is structural: our single atomic state write makes the queue invariants hold by construction, while `pi-subagents` reaches comparable safety by policy over artifacts it never declared as one unit. Its worktree engine is genuinely stronger in places -- patch capture before removal, which closes a crash window we still carry, and a fail-closed rollback that poisons the module rather than guessing at ownership -- so the right outcome is to adopt it as an adjacent dependency for delegation and to borrow its patch-capture ordering as a Track B follow-up.

**The learning points.**

1. Adjacency is not overlap. `pi-subagents` and task-queue share a git-worktree lifecycle and nothing else; start an audit from the contract's mechanism list, not the descriptions.
2. "It records merges" is not "it merges". No `git apply`, `git am`, or `git cherry-pick` appears in the package source; I7 is unreachable by adoption.
3. Names invite false matches. `runs.lanes`, retained `resume`, lane merge evidence, and `worktree.cleanup` all look like queue concepts and differ in trigger, durability, or authority. Check the state machine, not the noun.
4. Patch capture before removal is the strongest single idea to steal; it closes a crash window our extension still carries.
5. Structural atomicity beats rollback policy; the contract's structural preference is the right tiebreaker, and the source evidence supports it.
6. An in-process lock is not a lock. Cross-queue fork ownership must serialize across processes.
7. Tool-surface size is not the adoption cost. `pi-subagents` registers two tools, but adopting it puts our protocol on a tool outside the project's control.
8. Reuse is still available; installing `pi-subagents` for delegation, background runs, and steering is independent of keeping task-queue ours.

### Interface issues on our own extension

These come from a review of how the extension behaves for an operator-driving primary, not from the invariants, which the extension holds.

**Open issue 1 -- the wait/join leg is badly construed and undocumented.** The extension has no blocking wait. A primary that has forked workers must discover a worker's break point by polling `taskq_poll` or by sleeping in a shell loop; a real operator session resorted to `sleep` to wait. `pi-subagents` makes wait a first-class async primitive (`await runs.run`, `bg_wait`); ours does not. The fix: a first-class wait -- either a `taskq_wait` that blocks until a break point arrives (with a timeout) and returns the join payload, collapsing poll-to-record-to-schedule-to-trigger into one operation, or a documented join loop taught as one named operation rather than left to free-form discovery.

**Open issue 2 -- the fork `workdir` contract is under-documented.** `taskq_fork` requires the worktree path outside the main tree (or it throws `task-workdir-inside-main`). The prohibition is correct -- workers never write in the main tree -- but an operator-facing agent repeatedly passes the main tree and gets rejected five times, then pre-creates worktrees with `git worktree add` and fails with a branch-exists error because the tool cuts the worktree itself. The error names the prohibition but not the remedy. The fix: the fork tool's description must state that it cuts the worktree itself (never pre-create one), and it should either own a canonical worktree location with a sensible default or prescribe one (for example, under `<repo>/.worktrees/<task>`), so a caller is not guessing where worktrees live.

**Open issue 3 -- the state machine surface is larger than the conceptual loop.** The operator's read of the loop is: fork, executing, waiting, join (operator processes), processing, done. The extension surfaces 7 task phases (forked, active, verified, failed, merged, discarded, retired) plus 3 queue-entry states (requested, scheduled, triggered) across 12 tools. Part of this is legitimate: the queue entries genuinely have the minimal 3 states, and the task phases are not sequence states but the bring-back and retirement lifecycle that makes the merge and close safe and crash-recoverable, the same lifecycle `pi-subagents` hides inside its runner. The critique is that we surface lifecycle bookkeeping as first-class work the primary must drive, so the extension reads as more complex than the loop it serves. The reachable fix is to reduce the surface, not the state count: consolidate the per-break-point drive (poll, record, schedule) into one higher-level join, and document the conceptual five-state loop and map each task phase onto it so the tool suite reads as one lifecycle rather than a roll of arbitrary states.

All three are closed by the fork and join surface, recorded in [`task_queue_primitive.md`](../../docs/adr/task_queue_primitive.md) under "The fork and join surface": `taskq_join` is the one blocking call that waits for and delivers a break point, the four intermediate tools are gone, `taskq_fork` owns a run-scoped worktree path derived from the run id and the task id, and the prompt maps the task phases and entry states onto the loop.

The seven task phases and twelve tools this record describes are themselves superseded. The lifecycle is four phases - `forked`, `active`, `terminated`, `retired` - the termination audit is a task record with a `usable` or `not-usable` outcome, the re-queue has two routes, and the bring-back writes a file set and prunes the worktree in one call. The invariant set and the reasoning above stand; the phase list in open issue 3 and the verdict object in the procedure section are the record of the surface as it was, not as it is. The current decisions are in [`task_queue_primitive.md`](../../docs/adr/task_queue_primitive.md) under "The task lifecycle, the fused bring-back, and the ownership lock".

## Consequences

### Follow-on work

- The primitive lands first; `fanout` and a rewritten `parallel-auto` consume it later.
- The `/auto` generalization consideration is logged in the M3.2.1 roadmap for a future session.
- The nushell-revisit (T4), patch-capture-before-removal, and per-prompt quality-pass rows carry the remaining follow-ups.

### Deferred, non-blocking

A thermo-nuclear review of the four-phase surface left these open. Each is recorded rather than fixed. None blocks the round; each is a later iteration's row.

- m1 - the re-queue's head check restates what the git call the route just ran already proved, so it belongs in a comment beside the check rather than in the op.
- m2 - the close's phase gate names `retired` where `nextPhase` would keep the gate and the transition table in step.
- m6 - `writeWorkerRequest` tests the document's absence and then writes it, where `O_EXCL` is the one atomic test; the same window the fork's cut closed is still open on the worker side.
- m8 - the lock-holder fixture carries two more modes worth adding: a delivery in flight, and a long section that beats.
- m9 - dead code the round left behind.
- m10 - every join poll re-reads every request document of every worktree, joinable or not, so a long wait costs O(polls) reads per document. It is a read cost, not a correctness one; the fix is to skip a worktree whose requests directory has not changed.
- m11 - the archive writes its diff directly where a temp file and a rename would survive a crash mid-write.
- m12 - `syncSleep` spins the clock out for a runtime without `Atomics.wait`.

### Open questions

- Does `/auto` also need the primitive generalization (so `/auto` becomes `/auto` as an `/iter` specialization)? Raised by the operator as a consideration point for the M3.2.1 roadmap.
- How does a caller express break points for a task that has no natural segmentation -- is a single-segment task the degenerate case, or does the caller need a way to declare "no break points, run to completion"? The design assumes the former.

### Durable decision

The standing principle behind this record is distilled into the ADR `task_queue_primitive.md`, which records the chosen mechanism, the rejected alternatives (bash Track A, adopt-`pi-subagents`), and the edge cases that shaped the choice.

## Records this supersedes

This document supersedes two earlier committed records, folded into the sections above: the design draft `20260929-design-draft-task_queue_general_sequencing_primitive.md` (context, decisions, procedure) and the fan-out comparison contract `20260929-spec-task_queue_fanout_contract.md` (invariants, rubric, dispatch contract), each now marked `superseded` and retained for reference. An uncommitted comparison report from this session (findings, learnings, open issues) was also folded in and deleted rather than committed as a superseded stub. This document is the single durable home.
