# Change model

**Current:** 2026-11-06

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Derived mergeability | The state is a git predicate over the trunk head and the branch tip, never a stored variable. |
| R2 | Atomic accept | The trunk advances by a compare-and-swap; a failed accept writes nothing. |
| R3 | The trunk never authors | Prepare resolves every conflict; accept only fast-forwards. |
| R4 | One model | The states, primitives and graph are stated once; the branch's own work is a separate machine. |
| R5 | The defect flow is a branch | A shared change is prepared, queued and accepted; a consumer is `not-ready` until it is. |

## 2026-11-06 -- The change flow is prepare, queue and accept

**Decision:** The change flow is three primitives over one derived mergeability value. A branch is `not-ready` when the trunk head is not an ancestor of its tip, `ready` when the head is a proper ancestor, and `accepted` when the tip is an ancestor of the head. `prepare-rebase` rebases the branch onto the head and resolves every conflict; `/merge-queue` orders the ready branches; `accept-fast-forward` stages the branch at the head and advances the trunk by a compare-and-swap. Prepare may hand directly to accept; the queue is a view over the ready set, not a gate. The trunk has one state, `stable`; accept is an atomic transition, not a state. The branch-work machine (`cut`, `working`, `blocked`, `parked`) is separate and is not mergeability.

**Rationale:** The earlier chart was over the branch's work, with mergeability mixed into it. The trunk asks a smaller question -- can this branch be accepted now? -- and every answer is a git predicate, so the value is derived and cannot go stale in a record. The accept used to replay and resolve, which made the trunk an author and the compare-and-swap impossible; a fast-forward is total once prepare has resolved every conflict, so the only failures left are environmental and the CAS catches exactly those. The "request" vocabulary came from a human review protocol; with one operator ordering and one consumer accepting, the deliverable is a prepared branch and the queue is an order. The model is checked in [the reference](../reference/change_model.md): TLC reaches 11 states and 22 steps, the chart draws 3 states and 3 arrows, and `TypeOK` and `NoDeadlock` hold.

**Rejected alternatives:**

- *A replay accept that resolves on the trunk.* **Intent failure**: the trunk authors the merge, so it resolves conflicts and the atomic compare-and-swap is impossible; the replay belongs to prepare.
- *Model mergeability as a stored branch state.* **Execution failure**: the value is a git predicate, and a stored copy goes stale silently. `stale` is the event "the head advanced" applied to a ready branch, not a state.
- *Keep `stale` as a fourth state.* **Execution failure**: it doubles the ready state with no distinct predicate; the event lands the branch back in `not-ready`.
- *Make the queue a gate every accept passes.* **Intent failure**: the queue is a view over the ready set; a ready branch may accept directly.
- *Keep the branch-work states in the same machine.* **Intent failure**: the branch has its own lifecycle; only the mergeability question is the trunk's.
- *Treat the change flow as recovery.* **Intent failure**: a live prepare and accept is the normal path. Recovery is a repair at the claimed state, and mergeability is not recovery.
- *Keep the "merge request" vocabulary.* **Intent failure**: there is no reviewer and no click; the terms name a process the system does not have.
- *Let a slice queue as a sub-range of a longer branch.* **Intent failure**: the accept fast-forwards to the branch tip, so a sub-range lands the remainder too. A slice is cut onto its own branch and is its own delivery commit.

**Edge cases / drivers:** A branch whose trunk moved is `not-ready` and re-prepares; the queue never holds it. The accept's guard is the queue head, so a `ready` branch that is not at the head waits. An early change is its own delivery commit on its own branch, with its own closed handover; the remainder is a child. A stack is a contiguous run: when the parent is accepted without a rewrite, the child's tip already descends from the new head and needs no re-prepare; when the parent's prepare rewrote the shared base, the child re-prepares. The model leaves out the branch-work machine, the commit graph, the queue's order, the operator's grain reason, and the set of simultaneous branches.
