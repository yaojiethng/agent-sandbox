# Design: task-queue as a General Sequencing Primitive

**Status:** active
**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** design

## Problem

The parallel fan-out workflows couple a sequencing mechanism with a task shape. `parallel-auto.md` mixes the fork (worktree, branch, subagent dispatch), the task shape (well-specified auto units), and a gating contract (unattended) inside one prompt. This coupling is the defect the operator names: the prompt is badly shaped because it does not separate the primitive from the shape it drives. task-queue is the prerequisite this design fills in: the general sequencing primitive that the fan-out workflows can each sit on.

## The design

task-queue is a **general agent utility**, not a loop workflow. It is a sequencing primitive that defines the operational procedure for:

1. **fork** -- fan N subagent tasks out, each in its own working directory and branch, dispatched with a fresh subagent per task.
2. **join** -- synchronous clearing by the operator. Each worker result re-orients the operator and waits; the operator's review and decision rate, not the agent's turn time, sets the wall clock.
3. **re-queue** -- when the operator clears a blockage and more work is needed, the task goes back into the queue.

task-queue accepts **a variety of task shapes**; it does not define what a task is. The caller plugs the task shape in.

### Home

`src/reasoning/agent/prompts/task-queue.md` -- the general agent utilities directory, alongside `advisor.md`, `propagation-check.md`, and `package-branch.md`. It is not a loop workflow, so it does not live in `workflow/coding-agent/prompts/`.

### The segmented fork/join/re-queue model and the continuity rule

The unit of the fork-and-join is the **segment**, not the whole task. A task decomposes into segments, each ending at a **break point** where the operator's synchronous feedback is wanted. A worker runs until the next break point, holds for the operator, and on clearing continues to the next break point. This is what makes the sequencing mechanism breakable at arbitrary points in a task's own lifecycle.

`/iter` = start -> gate1 -> gate2 is the concrete illustration the operator gives: one segment can be `start -> gate1` (break here for operator feedback), the next `gate1 -> gate2` (break for the same reason), and so on until the task's own terminal end. The break points are part of the task spec, not invented by the primitive.

- **Fork:** per-task worktree and branch, one fresh subagent per task (or a resumed session), dispatched concurrently, all from one baseline commit. Wrapped dispatch with visible failure and duration. (Reused from the parallel-auto machinery.)
- **Break points requested by the worker, scheduled and triggered by the primary.** The worker runs its own validation and judges when it needs input. It requests a break point; the primary schedules and triggers it. The primary never pauses the worker at a segment the worker did not request.
- **The worker-queue sees only a queue of requested break points, and does not distinguish their kind.** The queue holds one uniform list of requested break points. "Final break point (leads to verification after)" is not a property the queue encodes; from the queue's view every entry is just a requested break point. The distinction lives in how the primary handles a break point once dequeued: a regular break point re-queues the next segment; a terminal one runs the final verification, builds the write-back proposal, and takes the bring-back verdict.
- **Join:** the primary holds at each dequeued break point, re-orients the operator, and waits for a release or decision. The operator's decision rate paces the wall clock.
- **Re-queue:** when the operator clears a break point, the task goes back into the queue for the next segment. The same worker continues, ideally -- which maps to pi's session mechanics: `--continue` or `--fork` on the same session log, in the same working directory. The operator sees no meaningful difference between "same worker" and a fresh re-dispatch on the same conversation log, because pi's active session branch supplies the conversation history either way. So "same worker continues" and "fresh dispatch on the same session log" are the same agent state by construction.
- **Per-track verification is a final check, requested by the worker and triggered by the primary.** When the worker terminates it requests verification; the primary schedules and runs it. The check is a termination audit -- it confirms the worker returned the output / wrote the report as directed. It is not a per-segment gate; in-process validation is the worker's job. Verification is, itself, a requested-and-scheduled step: the worker requests it and the primary schedules and triggers it, exactly as it does a break point.
- **Final break point:** the terminal segment ends at a break point where no further changes are queued. The only decision left is what to bring back. The primary constructs a **write-back proposal** from each worker's track -- a distilled, presentable shape of the proposed write-back -- and the operator judges that proposal at the final break point. This is what makes the acceptance judgement clean: the operator judges a written proposal, not a raw diff.
- **Single writer, no async git writes into the main tree.** The main agent is the sole writer of the main sandbox folder. A worker works only in its own worktree and branch; it never writes into the main tree. The primary merges, applies the accepted proposal, and writes the records. This extends the `parallel-auto` record-ownership rule to every main-tree write.
- **The final verdict has a bring-back scope of all, partial, or none** over the write-back proposal. The merge is parameterized by exactly the accepted proposal and its scope -- all = merge the whole proposal, partial = merge a selected subset the operator names, none = park or discard the track. The merge is not an all-or-nothing end-of-run event; each task's merge runs over exactly what its final verdict brings back.

The acceptance judgement at the final break point is structurally the same hold as any other break point -- it reuses the join -- with a terminal verdict added on top. Non-final break points decide the next segment; the final break point decides the write-back proposal and its bring-back scope. A regular break point never makes a bring-back decision; the final break point is the sole place that decision is made for a task.

### What task-queue owns and does not own

Owns: the fork procedure, the synchronous operator-join, the re-queue rule, the write-back proposal construction, the single-writer rule, the final per-track verification (scheduled and triggered by the primary), the merge, and the records (primary-owned).

Does not own: the task shape. A caller supplies the task's break points (the segmentation) and what a well-specified task is. The primitive owns the machinery of the break-point hold, the continue decision, and the final bring-back verdict; it does not interpret the task's content. `fanout` (design-option exploration) and a rewritten `parallel-auto` sit on this primitive.

The single "return contract" is replaced by the segmentation: the primitive does not assume one completed return per task. The worker advances under its own validation until it judges it needs input or is done. A task with no defined break points is a single-segment task that runs to completion, at which point the worker terminates and requests its final verification.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| task-queue is a general agent utility in `src/reasoning/agent/prompts/`, not a loop workflow | it is a sequencing primitive that accepts many task shapes; the workflow directory holds loop templates | this design |
| Keep worktree and branch in the primitive's contract | it is what makes the coding-agent fork safe, mergeable, and verifiable per-track | this design |
| Re-queue = same worker continues, via the same directory and the same pi session log | pi's active session branch supplies the conversation history, so "same worker" and "fresh dispatch on the same log" are the same agent state | this design |
| This iteration delivers the primitive only | `fanout` and `parallel-auto` refactor onto it later | this design |
| `parallel-auto` is badly shaped and will be rewritten to sit on this primitive | it mixes fork with task shape and gating contract | this design |
| The unit of the fork-and-join is the segment, not the whole task | a task can have multiple break points; the operator's feedback is wanted at each, and the sequencing mechanism must be breakable at arbitrary points in the task's lifecycle | this design |
| The break points are part of the task spec, supplied by the caller | the primitive does not invent the task's segmentation | this design |
| Acceptance judgement = the final break point | it is the same hold/join with no further changes queued, plus a bring-back verdict | this design |
| Bring-back scope is all, partial, or none | the merge is parameterized by exactly what the operator brings back, so it is not an all-or-nothing end-of-run event | this design |
| The final verdict judges a write-back proposal, not a raw diff | the primary distills each worker's track into a presentable proposal; that is the unit of judgement at the final break point | this design |
| Single writer on the main sandbox; workers never write into the main tree | no async git write raced into the main tree; the record-ownership rule extends to every main-tree write | this design |
| The worker owns its validation and drives its own break points | the worker judges when it needs input; the primary does not pause it per segment | this design |
| Per-track verification is a final check at worker termination, not a per-segment gate | it confirms the worker returned the output / wrote the report as directed | this design |
| Verification is requested by the worker, scheduled and triggered by the primary | the primary controls when the check runs and what it means; the worker signals readiness | this design |
| The worker-queue records only requested break points and does not mark their kind | final-versus-regular is not a queue property; it is how the primary handles a break point once dequeued | this design |
| Durability and atomicity are a first-class invariant class (I11-I13 in the fan-out contract), not an afterthought | both independent thermo-nuclear reviews converged on non-atomic transitions and non-resumable close as the blocker; the queue is durable state whose failure paths are load-bearing | fan-out contract + this design |
| Transitions are structurally atomic by preference (single rename / pathname-as-state), not made atomic by bolted-on rollback | the reviewers' guidance is that I1/I4/I5 should hold by construction | fan-out contract + this design |
| Track B is adopt-vs-roll-our-own, decided by a comparison, not an immediate fold-back | the operator found a battle-tested extension claiming similar behavior; compare it against our candidate for learning points before adopting or building | roadmap T-track comparison task + this design |

## Open questions

- Does `/auto` also need the primitive generalization (so `/auto` becomes `/auto` as an `/iter` specialization)? Raised by the operator as a consideration point for the M3.2.1 roadmap.
- How does a caller express break points for a task that has no natural segmentation -- is a single-segment task the degenerate case, or does the caller need a way to declare "no break points, run to completion"? The design assumes the former.

## Follow-on work

- The primitive lands first; `fanout` and a rewritten `parallel-auto` consume it later.
- The `/auto` generalization consideration is logged in the M3.2.1 roadmap for a future session.
