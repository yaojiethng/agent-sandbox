# Design: the `/auto` smart dispatcher and the `-work` dispatch family (M3.2.3, M4)

**Status:** settled -- captures the 2026-10-01 plan walk. The `/auto` smart dispatcher and `/goal` are M4's; the `-work` family and the `/auto` keyword reservation are M3.2.3's.

## Purpose and scope

`/auto` changes semantics from a sequential autopilot into a generalized smart dispatcher, a plan iteration and stub work that M4 implements and M3.2.3 reserves. This record fixes the semantics, the ownership split, and the naming deconfliction before any implementation.

## The dispatch command surface

The agent's dispatch surface is a curated set of dispatch commands the operator invokes deliberately, plus one `/auto` smart dispatcher. Each curated command is one dispatch shape.

| Command | Shape | Owner |
|---|---|---|
| `/sequential-work` | sequential dispatch (was `/auto`) | M3.2.3 |
| `/parallel-work` | concurrent independent tracks (was `/parallel-auto`) | M3.2.3 |
| `/task-queue` | operator-gated fan-out | M3.2.1 / curated |
| `fanout` | design-option exploration | curated |
| `/auto` | smart dispatcher (Option A) | M4 (stub reserved in M3.2.3) |
| `/goal` | loose-goal decomposition (Option B) | M4 |

## `/auto` -- the smart dispatcher (Option A)

`/auto` takes a roadmap task list that the operator provides, possibly out of order, with subtasks each carrying an execution rank. It:

1. resolves the execution order from the dependency structure;
2. decomposes the work into units and assigns each an execution rank;
3. picks the dispatch shape per the work structure, from the curated command surface;
4. orchestrates and queues the units, running everything it can and parking any unit that genuinely requires operator input.

The dispatcher reads a provided decomposition; it does not derive one from a loose goal. The curated dispatch shapes are its building blocks. Distinct from `/goal`.

## `/goal` -- loose-goal decomposition (Option B)

`/goal` takes a loose goal, decomposes it into units itself, and schedules every unit it can run, asking the operator only when a unit genuinely needs a decision. It is the decomposition-and-schedule engine. The external `/goal` extension is stale and broken and was removed; M4 rebuilds the semantics as a first-class prompt or extension.

## The `-run` and `-work` naming families

`-run` names a family of one-shot draft tasks refined in M3.2.2 (churn-analysis, read-through, review-loop, review-pass). `-work` names the dispatch-command family refined in M3.2.3 (`sequential-work`, `parallel-work`). The `-work` suffix is temporary, placeholder-pending final naming, and it is removed when the feature lands and final names are decided.

## Ownership split

- The loop taxonomy proper (the four loops: `/iter`, `/milestone-close`, `/milestone-start`, `/plan`) stays owned by M3.2.1.
- The `/iter` work-loop expansions (`/auto`, `/parallel-auto`) move from M3.2.1 to M3.2.3, which owns them from hereon, rendered as the `-work` family.
- The new `/auto` smart dispatcher and `/goal` are M4's, not `/iter` work-loop expansions.

## The `/auto` keyword reservation

M3.2.3 reserves the `/auto` keyword by renaming the old sequential autopilot to `/sequential-work` and standing a stub in its place. The stub fails closed: it routes a single well-ordered unit list to `/sequential-work` and refuses any shape the dispatcher is not yet equipped to handle, rather than guessing. M4 implements the smart dispatcher.

## Deferred to M4

- The `/auto` smart-dispatcher implementation.
- The `/goal` loose-goal decomposition rebuild.
- The `execution_model.md` dispatch-model update (M4.3).
