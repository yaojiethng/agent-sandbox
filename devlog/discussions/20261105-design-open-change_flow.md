# The change flow: prepare, queue, accept

**Status:** open

## Context

The earlier chart was over the branch's work, with mergeability mixed into it. That is the wrong subject: the branch has its own lifecycle, and only a small part of it is the question the trunk asks -- can this branch be accepted now? The machine over that question has three states, and every one is a git predicate.

The "request" vocabulary came from a human review protocol: a pull or merge request exists so a person can read, approve and click. There is no reviewer here. One operator orders the work; one consumer accepts it. So the unit is a **prepared branch**, and the queue is an **order**.

## Decision

Three primitives:

- **Prepare** -- a worker rebases a branch onto the current head and resolves every conflict. The branch is **ready** when the head is a proper ancestor of its tip, so it fast-forwards.
- **Queue** -- the operator orders the ready branches. A **stack** is a contiguous run in which each branch is prepared on the one before it.
- **Accept** -- the consumer fast-forwards the trunk to the next ready branch. The head advances.

The branch-work machine (`cut`, `working`, `blocked`, `parked`) is a separate machine. It is not mergeability.

The trunk has one state, **`stable`**. The head is a value. `accept` is an atomic transition back to `stable`, not a state named `accepting` or `advanced`.

## The chart

```mermaid
---
title: "The mergeability of a branch"
---
stateDiagram-v2
  state "Legend" as legend {
    lg0: notReady
    lg1: ready
    lg2: accepted
  }
  class lg0 orange
  class lg1 teal
  class lg2 blue
  s0: Not ready
  s1: Ready
  s2: Accepted
  [*] --> s0
  s0 --> s1: prepare
  s1 --> s0: the head advances
  s1 --> s2: accept
  class s0 orange
  class s1 teal
  class s2 blue
```

## The three states

| State | Predicate | Meaning |
|---|---|---|
| `not-ready` | the head is not an ancestor of the tip | it cannot be fast-forwarded |
| `ready` | the head is a proper ancestor of the tip | it fast-forwards |
| `accepted` | the tip is an ancestor of the head | it is on the trunk |

`stale` is not a state. It is the event "the head advanced" applied to a `ready` branch, which lands it back in `not-ready`. The worker may label that edge "re-prepare," but the mergeability value is `not-ready`.

The transitions are three: `not-ready -> ready` on prepare, `ready -> accepted` on accept, and `ready -> not-ready` when the head advances. `accepted` and `not-ready` are stable under a head advance.

Mergeability is derived, not stored. `ready` is `git merge-base --is-ancestor <head> <tip>`, `accepted` is the inverse, and `not-ready` is neither. The chart is a diagnostic over the repository, not a variable the system writes.

## The accept operation

`accept` is a guarded atomic transition, not a state:

- **Guard:** the branch is `ready` and it is at the head of the queue.
- **Stage:** verify it at the head in a scratch worktree: the suite and the lint gate.
- **Commit:** `update-ref refs/heads/trunk <tip> <head>` -- a compare-and-swap against the head that was checked.
- **Success:** the head becomes the tip.
- **Failure:** nothing is written; the head is unchanged.

`ready` makes the fast-forward total: a pointer move cannot fail for a semantic reason, because the branch resolved every conflict during prepare. The only remaining failures are environmental -- the head moved between the check and the CAS, a lock, an I/O error -- and the CAS catches exactly that.

This is the `make draft` / `make confirm` shape. Draft stages and verifies; confirm is the CAS. Verify before the CAS and there is nothing to roll back. Move first and verify after, and the rollback is the inverse CAS, which is why the old head is captured in the transaction.

The runbook does not need an `accepting` state, an `advanced` state, or a rollback state. It needs the guard, the stage and the CAS.

## The early-change workflow

A change is made available early when another branch needs it before the branch's milestone is complete. The change is a prepared unit like any other.

1. **Prepare.** The worker rebases the change onto the head, resolves every conflict, and makes it fast-forwardable. The change is its own unit: a typed commit with its own closed handover.
2. **Queue.** The operator orders it. The grain is which range is queued now: a slice, or the whole milestone.
3. **Accept.** The consumer CASes the head forward.
4. **Re-evaluate.** Every queued branch is re-checked. A branch no longer based on the head is `not-ready` and re-prepares.
5. **Continue.** The branch that opened the slice re-prepares its remaining commits as their own unit.

A stack is a contiguous run. After the parent is accepted, the child's tip already descends from the new head, so its accept is also a fast-forward and needs no re-prepare.

## Critical workflow bugs

| Bug | Carrier | Why it blocks |
|---|---|---|
| The normal integration path is documented only as recovery. | `references/recovery.md`; `workflow_statechart.md`'s `recovery` region. | Prepare and accept are the normal path. The only entry says the work is lost. |
| The accept is a replay, not a fast-forward. | `merge.md`'s cherry-pick replay. | The trunk authors the replay and resolves conflicts, so the CAS is impossible and the consumer is not atomic. |
| The branch model says `main` is the only long-lived branch. | `references/branching.md`. | The long-lived track we work on has no stated lifetime, name or prepare obligation. |
| Nothing obliges a branch to prepare when the head moves. | `references/branching.md`'s lifecycle. | A queued branch can become `not-ready` and no rule sends it back. |
| The early slice's unit and handover shape is undefined. | `git-discipline`'s grouping and fold rules. | A `wip:` can land on the trunk, or the slice is a partial unit with no handover. |
| `/rebase` assumes every commit carries a handover. | `rebase.md`. | The post-slice remainder contains the split-out unit, whose handover is not there to read. |

## What the model leaves out

The branch-work machine, the commit graph, the queue's order, the operator's grain reason, and the set of simultaneous branches. The mergeability value is derived in a real repository; the model stores it because TLC needs a variable. The model checks that the guard is structural: `accept` is enabled only from `ready`.

## Checked evidence

TLC reaches 11 states and 22 steps under `head <= 3`. The chart draws 3 states and 3 arrows. `TypeOK` and `NoDeadlock` hold. There is no forbidden path to mark, because the guard is the machine: an accept from `not-ready` is not a transition.

Reproduce with:

```sh
PATH="$HOME/.local/bin:$PATH" "$HOME/.pi/agent/skills/statechart/scripts/statechart" \
  Mergeability.tla --view view.mjs --out out
```

The output folder must be new or empty.

## Appendix: the model

```tla
---- MODULE Mergeability ----
EXTENDS Naturals, TLC

VARIABLES state, head

vars == <<state, head>>

TypeOK ==
  /\ state \in {"notReady", "ready", "accepted"}
  /\ head \in Nat

Init ==
  /\ state = "notReady"
  /\ head = 0

Prepare ==
  /\ state = "notReady"
  /\ state' = "ready"
  /\ UNCHANGED head

Accept ==
  /\ state = "ready"
  /\ state' = "accepted"
  /\ head' = head + 1

HeadAdvances ==
  /\ head' = head + 1
  /\ state' = IF state = "ready" THEN "notReady" ELSE state

Done ==
  /\ state \in {"accepted", "notReady"}
  /\ UNCHANGED vars

Next ==
  \/ Prepare \/ Accept \/ HeadAdvances \/ Done

Spec == Init /\ [][Next]_vars

StateConstraint == head <= 3

====
```

```js
export const state = (v) => {
  switch (v.state) {
    case "notReady":
      return "Not ready";
    case "ready":
      return "Ready";
    case "accepted":
      return "Accepted";
    default:
      return v.state;
  }
};

export const group = (v) => {
  if (v.state === "ready") return "ready";
  if (v.state === "accepted") return "accepted";
  return "notReady";
};

export const colors = {
  notReady: "orange",
  ready: "teal",
  accepted: "blue",
};

export const title = "The mergeability of a branch";

const steps = {
  Prepare: "prepare",
  Accept: "accept",
  HeadAdvances: "the head advances",
  Done: null,
};

export const step = (action, from, to) => {
  if (action === "HeadAdvances" && from.state === to.state) return null;
  return steps[action] ?? null;
};
```
