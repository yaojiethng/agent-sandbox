# Autonomous Task Execution

This document marks the boundary between the interactive workflow and the future autonomous workflow introduced in M3.

---

## The Boundary

The interactive workflow — defined in [`iteration_policy.md`](../operations/iteration_policy.md) — is a human-in-the-loop process. An operator and an agent collaborate through a session: the operator confirms designs, reviews proposals, and commits outputs. The agent does not act unilaterally.

M3 introduces structured autonomous task execution: a single headless agent run, no interactive session, driven by a task brief prepared in advance. The operator's role shifts from session participant to brief author and output reviewer.

The interactive workflow governs how briefs are produced. The autonomous workflow governs what the agent does with them inside the container. The two are complementary — the interactive lifecycle stages (design, spec, acceptance criteria) are the upstream process that makes a brief trustworthy enough to run autonomously.

---

## TASK.md

The artifact that crosses the boundary is `TASK.md` — a per-run brief placed in `SANDBOX_DIR/.agent-input/input/` before the container starts. It carries the agreed scope, constraints, and expected outputs into the container. The agent reads it alongside `agent_context_brief.md`.

`TASK.md` is the runtime expression of a task that has already completed the interactive workflow's design and spec stages. It does not replace those stages — it is produced by them.

The format and content of `TASK.md` are defined in M3.

---

## References

| Document | Purpose |
|---|---|
| [`iteration_policy.md`](../operations/iteration_policy.md) | Interactive workflow — how TASK.md is produced |
| [`execution_model.md`](../architecture/execution_model.md) | Operator input channel — how TASK.md reaches the container |
| [`roadmap.md`](../development/roadmap.md) | M3 milestone — autonomous task execution scope |
