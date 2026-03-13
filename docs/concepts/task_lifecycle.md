# Task Lifecycle

This document describes how work advances from a pain point to a completed, documented change in agent-sandbox. It is the conceptual model underlying the development workflow and the basis for working principles in [`task_policy.md`](../operations/task_policy.md).

---

## Stages

### 1. Pain Point

Work begins with a concrete problem observed during real use — not a feature request in the abstract. The operator surfaces the frustration; the agent's first job is to understand it accurately before proposing anything.

A pain point is not yet a task. It becomes one only after the conceptual design stage produces a clear, agreed scope.

---

### 2. Conceptual Design

The shape of the solution is discussed before any implementation detail is decided. Open questions are identified explicitly and resolved before moving forward. Decisions are recorded in a discussion document (e.g. `m1_4-discussion.md`) so the reasoning is preserved alongside the outcome.

Key discipline: if an open question cannot be resolved, the stage does not advance. Unresolved questions surface as implementation risks, not implementation tasks.

---

### 3. Implementation Spec

Once the conceptual design is agreed, the implementation is specified: which files change, what interfaces are added or modified, what naming conventions apply. This is the agreement the agent works to — not a suggestion, not a starting point.

The spec is confirmed by the operator before any code or documentation is written. Scope is fixed at this stage; adjacent issues discovered during spec are flagged separately and do not enter the current task.

---

### 4. Task Tracking

Before implementation begins, the task is entered in `roadmap.md` under the appropriate milestone, with the objective and task list reflecting the agreed spec. The roadmap entry is the canonical record of what is in scope for this task.

Tasks are not marked complete until all items in the list are done, including documentation.

---

### 5. Implementation

Code and documentation are produced against the agreed spec. Tests are written for non-trivial logic. The agent does not make scope decisions during implementation — if a gap or adjacent issue is found, it is flagged and deferred, never silently resolved.

All outputs are proposals. The operator reviews, approves, and commits.

---

### 6. Documentation

Architecture documents are updated to reflect the new system reality before the task is considered complete. The roadmap is updated: completed tasks are marked, and the next cleanup pass collapses them into outcome sentences per `roadmap_policy.md`.

---

## Relationship to TASK.md

M2 introduces structured autonomous task execution, including a per-run `TASK.md` brief passed to the agent alongside `agent_context_brief.md`. `TASK.md` is the runtime expression of a task that has already completed stages 1–4 of this lifecycle — it carries the agreed scope, constraints, and expected outputs into the container.

The lifecycle stages above govern how `TASK.md` is produced by the operator; `TASK.md` governs what the agent does with it inside the container. The two are complementary, not overlapping.

The format and content of `TASK.md` are defined in M2. This section is a forward reference only.

---

## References

| Document | Purpose |
|---|---|
| [`task_policy.md`](../operations/task_policy.md) | Agent-facing working principles derived from this lifecycle |
| [`roadmap_policy.md`](../operations/roadmap_policy.md) | Roadmap update sequence and cleanup rules |
| [`documentation_policy.md`](../operations/documentation_policy.md) | Documentation structure and enforcement rules |
| [`roadmap.md`](../development/roadmap.md) | Current milestone and task detail |
