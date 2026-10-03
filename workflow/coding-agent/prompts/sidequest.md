---
description: "Run a sidequest: operator-directed work raised while an iteration is open. Pauses the open iteration, runs the standard lifecycle at the sidequest's own grain - one handover, one scope gate, one delivery commit, one close - records the handover to resume, and returns to it. Use when work arrives that the open iteration does not own and cannot wait for the next iteration. Run /iter to open a normal iteration from the roadmap."
argument-hint: "<what the sidequest does - required>"
---

> $@

# Sidequest - Operator-Directed Interruption

**Scope:** an operator-directed work item raised while an iteration is open. The runbook pauses the open iteration, runs the standard lifecycle at the sidequest's own grain, and returns control to the handover the open iteration was working. It owns the interruption and the return; the lifecycle steps are [`/iter`](iter.md)'s and [`/wrapup`](wrapup.md)'s, and the invariants are [`iteration_policy.md`](../../../docs/operations/iteration_policy.md#sidequests)'s.

## When to use

Run `/sidequest` when the operator raises work the open iteration does not own and that cannot wait for the next iteration.

- A task inside the open iteration's scope is that iteration's work. Amend the scope; do not open a sidequest.
- No iteration is open, or none is `Active`: the work is a normal iteration. Run `/iter`.
- The work needs decisions before it can be shaped: run `/plan`.

The operator invokes a sidequest. The agent does not open one on its own.

## Orient

Read the most recent handover and the roadmap, as `/iter` Orient does.

## Identify the interrupted iteration

The interrupted iteration is the handover whose status is `Active`. When more than one is `Active`, the one the operator names is the parent; when none is, stop and say so, because the work is then a normal iteration and `/iter` owns it.

Record the parent's handle. The sidequest names it twice: in its own Scope continuation line, and in the parent's Findings.

## Create the sidequest handover

Create the handover per [`handover_policy.md`](../../../docs/operations/handover_policy.md), as `/iter` Create the handover does, with Status `Active`. Set the type from the work, not from the parent.

Two writes belong to this step, and both land before the scope gate:

1. The sidequest handover's Scope opens with one continuation line naming the interrupted handover.
2. The interrupted handover's Findings gains one row naming the sidequest and its reason.

## Scope gate

The scope gate is `/iter`'s. The difference is where the scope comes from: the operator's direction supplies the task, and no roadmap row is required at open. Present the scope and the acceptance criteria together, and wait for the operator's release.

Confirm the sidequest sits outside the interrupted iteration's scope. A sidequest that turns out to sit inside it stops here and becomes a scope amendment on the parent.

## Implement

Run `/iter` Step 6 as written: produce changes against the confirmed scope, write tests alongside, and keep the handover's Decisions, Findings and Completed current as the work proceeds.

## Pre-close and release

Present the pre-close summary and wait for the release gate, per `/iter` Step 7 and Release gate. The five sections are unchanged.

## Close

Run the consolidated close from [`/wrapup`](wrapup.md) Part B, as `/iter` Steps 8-9 do. The sidequest is one delivery commit.

**Roadmap write-back.** A durable outcome raises a roadmap row and marks it `[x]` in the sidequest's own close commit, per [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md). A fix, check or record with no roadmap home states that as the write-back outcome; the step is never skipped.

## Return

After the close, state the handover to resume and the step it reached. `/iter` continues that handover; the sidequest does not carry the parent's remaining work.

## Non-goals

- A sidequest does not change the interrupted iteration's scope.
- A sidequest does not close the interrupted handover. The parent keeps its `Active` status; only the resumed iteration closes it.
- A sidequest does not renumber or re-order the roadmap.

## Failure modes and invariants

| Failure | Response |
|---|---|
| No `Active` handover | stop and say so; the work is a normal iteration, and `/iter` owns it |
| Two `Active` handovers and the operator has not named the parent | ask which one is paused |
| The work turns out to sit inside the parent's scope | stop at the scope gate and amend the parent's scope instead |
| The sidequest grows past one slice | split it; each part closes on its own handover, or the excess is written back as an open roadmap row |
