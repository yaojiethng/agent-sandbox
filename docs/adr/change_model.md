# Change model

**Current:** 2026-11-16

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Derived mergeability | The state is a git predicate over the trunk head and the branch tip, never a stored variable. |
| R2 | Atomic accept | The trunk advances by a compare-and-swap; a failed accept writes nothing. |
| R3 | The trunk never authors | Prepare resolves every conflict; accept only fast-forwards. |
| R4 | One model | The states, primitives and graph are stated once; the branch's own work is a separate machine. |
| R5 | The defect flow is a branch | A shared change is prepared, queued and accepted; a consumer is `not-ready` until it is. |
| R6 | The host lane is the operator's | The host lane includes the operator's raw git operations, not only the verbs; a competent operation re-derives the state. |
| R7 | A mistake has a stated remediation | A broken draft is discarded by `make reject` and rebuilt by `make draft`; the bundle and the branch are unchanged. |

## 2026-11-06 -- The change flow is prepare, queue and accept

**Decision:** The change flow is three primitives -- prepare, queue and accept -- over one derived mergeability value. Prepare resolves every conflict; accept advances the trunk by a compare-and-swap; the queue orders what is ready and is a view over the ready set, not a gate. The trunk never authors or resolves, and the branch's own lifecycle is a separate machine. The states, their predicates, the transitions and the commands are the reference's: [the change model](../reference/change_model.md).

**Rationale:** The earlier chart was over the branch's work, with mergeability mixed into it. The trunk asks a smaller question -- can this branch be accepted now? -- and every answer is a git predicate, so the value is derived and cannot go stale in a record. The accept used to replay and resolve, which made the trunk an author and the compare-and-swap impossible; a fast-forward is total once prepare has resolved every conflict, so the only failures left are environmental and the CAS catches exactly those. The accept is the `make draft` / `make confirm` shape: draft stages and verifies, confirm is the CAS. Verify before the CAS and there is nothing to roll back; move first and verify after, and the rollback is a second write that can fail. The "request" vocabulary came from a human review protocol; with one operator ordering and one consumer accepting, the deliverable is a prepared branch and the queue is an order. There is no forbidden path to mark, because the guard is the machine: an accept from `not-ready` is not a transition. The model is checked in [the reference](../reference/change_model.md).

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

## 2026-11-12 -- The host lane is the operator's, and a mistake is rejected and redrafted

**Decision:** The change model is two lanes. The agent lane prepares, cleans the series and exports; the host lane drafts, reviews, confirms or rejects, or applies. The lanes meet at the bundle and the draft worktree. The host lane's actor is the operator, and it includes the operator's raw git operations, not only the verbs. A mistaken operation is remediated by `make reject` then a new `make draft`: the bundle and the branch are unchanged, and only the draft is replaced. The host surface stays the four verbs; a repair verb is not added. Delivery is a parameter of the agent lane's entry: copy and mount change the workspace and the visibility assertions, not the handoff. The states, the transitions, the chart and the TLA+ model are [the reference](../reference/change_model.md)'s.

**Rationale:** The 2026-11-06 model presented the host as a passive acceptor and the primitives as prompts. It hid the manual review and the operator's git, so a raw `git reset` or a broken draft had no stated place in the model. The operator does run git; a model that denies it is false. The reject-and-draft remediation already exists and composes the two host verbs, so it is cheaper than a new repair verb and leaves the bundle and the branch as the evidence. Delivery was modelled as a separate mechanism; the diff pipeline is indifferent to it, so delivery belongs at the agent lane's entry, not in the handoff.

**Rejected alternatives:**

- *Make the host lane verb-only.* **Intent failure**: the operator may run raw git; the model would be false and a mistake would have no stated path.
- *Treat a host mistake as recovery.* **Intent failure**: recovery repairs the unit's claim; a broken draft is the host flow's object, and reject and draft restore it without touching the claim.
- *Add a repair verb.* **Intent failure**: the existing reject and draft already compose; a new verb is a second surface to learn.
- *Model delivery as a second pipeline.* **Intent failure**: the diff pipeline is delivery-indifferent; copy and mount change the agent lane's entry, not the handoff.
- *Keep the change flow in prompts.* **Intent failure**: a prompt that mirrors a host verb is a second surface; the host verbs are the user surface and the agent operations are primitives.

**Edge cases / drivers:** A competent raw git operation re-derives the mergeability; a branch left `working` re-prepares. A mistaken operation leaves the draft inconsistent; `make reject` restores the source and deletes the draft, and `make draft` rebuilds it from the unchanged bundle. A raw git operation on the trunk is a head advance: every ready branch re-checks. The model leaves out the draft's internal confirm steps, which are [the reference's confirm section](../reference/change_model.md#the-confirm-sequence)'s, the branch-work machine, and the queue's order.

## 2026-11-16 -- One lifecycle from fork to deletion

**Decision:** The change model is one lifecycle. The states are the mergeability relation and the host's staging of it: `working` (the head is not an ancestor of the tip), `ready` (mergeable; the operator's choice is the queue), `drafted` (a draft exists), `accepted` (on the trunk) and `deleted` (the ref is gone). The lanes are the actors, delivery is a parameter of the fork, and the draft's package and confirm detail are sections of the same model. `draft_branch_statechart.md` is retired; its content is in the reference. `branching.md`'s lifecycle links the model.

**Rationale:** The 2026-11-06 entry split the branch work from mergeability, and the draft chart became a third document. The split was the interim: the branch's work, its mergeability and the draft are one object's life, and a reader had to assemble it from three sources. The meaningful axis is mergeability, not a branch-work state: `blocked` and `parked` named why the operator had not taken a branch, and both are the queue, not a state. The 2026-11-06 rejection of keeping the branch-work states in the same machine stands, because the model keeps no branch-work state beyond `working`, which is the absent mergeability.

**Rejected alternatives:**

- *Keep `blocked` and `parked` as states.* **Intent failure**: a dependency and a decision both leave the branch `working` or `ready`; the reason is not a git predicate and would need a declared store.
- *Keep the draft chart as a peer document.* **Intent failure**: one subject in one mode has one source; the package and confirm detail is a section of the model.
- *Keep both gates.* **Intent failure**: two gates over one model are a second source for the same claim.
- *Keep the branch-work lifecycle in `branching.md`.* **Intent failure**: the fork-to-deletion life is the model's; the convention owns the track topology and the prepare obligation, not a second lifecycle.

**Edge cases / drivers:** A ready branch that is not chosen is `ready` and waits in the queue. A head advance returns `ready` to `working`. A rejected draft returns the branch to `ready`. A stale branch is abandoned from `working` or `ready`. The model leaves out the queue's order, the commit graph, the package's byte-level form and the confirm's internal steps, which are the confirm section's.
