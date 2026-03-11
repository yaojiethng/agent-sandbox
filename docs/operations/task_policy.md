# Task Policy

Working principles for advancing tasks in agent-sandbox. These principles are the agent-facing realization of the task lifecycle defined in [`task_lifecycle.md`](../concepts/task_lifecycle.md).

Read this document before beginning any task. Read [`documentation_policy.md`](documentation_policy.md) and [`roadmap_policy.md`](roadmap_policy.md) before touching documentation or the roadmap.

---

## Principles

**Pain points before solutions.** A task begins with a concrete problem, not a feature. Understand the problem accurately before proposing a shape for the solution.

**Resolve open questions before advancing.** If a question about design, scope, or interface cannot be answered, the stage does not advance. Surface the question explicitly — do not assume an answer and proceed.

**Record decisions where the work lives.** Decisions belong in the discussion document or roadmap, not only in chat. If the reasoning is not recorded, it does not exist for the next agent instance.

**Confirm the spec before writing code.** The implementation spec — files, interfaces, naming — is confirmed by the operator before any code or documentation is produced. It is the agreement, not a starting point.

**Scope is fixed at spec time.** Adjacent issues discovered during implementation are flagged and deferred. They do not enter the current task silently. One task, one scope.

**Documentation is part of the task.** A task is not complete until architecture documents reflect the new system reality. Marking tasks complete before documentation is done is a violation.

**All outputs are proposals.** The operator reviews, approves, and commits. The agent does not decide what is final.

**Tests for non-trivial logic.** Any function with meaningful branching, error handling, or external dependencies gets tests. Tests are produced alongside the implementation, not deferred.

**Roadmap reflects reality.** The roadmap entry is created before implementation begins. Completed items are marked promptly. Cleanup follows `roadmap_policy.md`.

---

## Stage Sequence

For the full description of each stage, see [`task_lifecycle.md`](../concepts/task_lifecycle.md).

| Stage | Entry condition | Exit condition |
|---|---|---|
| Pain Point | Operator surfaces a concrete problem | Problem is understood accurately |
| Conceptual Design | Problem understood | All open questions resolved; decisions recorded |
| Implementation Spec | Design agreed | Files, interfaces, naming confirmed by operator |
| Task Tracking | Spec confirmed | Roadmap entry created with objective and task list |
| Implementation | Roadmap entry exists | All tasks complete including tests |
| Documentation | Implementation complete | Architecture docs updated; roadmap marked |

---

## User Stories (Optional)

Not every pain point is ready to become a task. When a use case requires investigation before a design can be agreed — open questions about feasibility, threat surface, or workflow fit — capture it as a user story first.

User stories live in `docs/development/` with the prefix `story_` (e.g. `story_website_dev.md`). They are investigation documents, not architecture. No live links from architecture or concepts documents are required.

A user story contains: the context, the pain points, open questions and current thinking, constraints, and next steps. It is not a task list — it is a reasoning record. When investigation is complete and a design is agreed, the relevant tasks are pulled into a milestone and the story is left as background reading.

User stories are referenced from the roadmap under the **User Stories** section with a single line and a short description. They do not get milestone entries until they are ready for implementation.

---

## References

| Document | Purpose |
|---|---|
| [`task_lifecycle.md`](../concepts/task_lifecycle.md) | Full lifecycle description |
| [`documentation_policy.md`](documentation_policy.md) | Documentation structure and enforcement rules |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update sequence and cleanup rules |
