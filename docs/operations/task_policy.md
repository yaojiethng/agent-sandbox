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

### Where they live

User stories live in `docs/development/` with the prefix `story_` (e.g. `story_website_dev.md`). They are investigation documents, not architecture. No live links from architecture or concepts documents are required.

Workflow-specific stories that predate the `story_` convention (e.g. `workflow/knowledge-vault/story.md`) are kept in place as historical records. New stories always follow the `story_` convention.

### Required sections

A user story accumulates sections as it progresses. Not all sections are present from the start — they are added as the investigation advances.

| Section | When added | Purpose |
|---|---|---|
| **Context** | At creation | What the use case is and why it matters |
| **Pain Points** | At creation | The concrete problems being investigated |
| **Investigation Findings** | During investigation | What was discovered; may be iterative |
| **Open Questions** | During investigation | Unresolved questions blocking progress |
| **Constraints** | At creation or during investigation | Non-negotiable requirements any solution must satisfy |
| **Resolution** | At closure | What was decided, where the work went, why |

A story is a reasoning record, not a task list. The **Resolution** section is what makes a closed story navigable — it must be complete before the story is marked closed.

### Lifecycle states

Stories carry a **Status** line immediately after the title.

| Status | Meaning |
|---|---|
| `Investigation in progress` | Active — open questions, investigation ongoing |
| `Resolved` | Closed — Resolution section complete; work promoted to milestone or explicitly deferred |
| `Superseded` | Closed — made obsolete by a broader architectural decision; Resolution section points to the superseding document |

### Graduation criteria

A story graduates to milestone tasks when:
- The pain point is fully understood
- All open questions are resolved
- A concrete solution approach is agreed
- The tasks are scoped enough to enter the stage sequence

When a story graduates, the relevant tasks are added to the roadmap. The story document stays in place as background reading and is marked `Resolved`. Tasks are not duplicated back into the story.

### Closure convention

When closing a story:
1. Add a `## Resolution` section covering: the decision reached, where the work went (milestone reference or explicit deferral), and why
2. Update the **Status** line to `Resolved` or `Superseded`
3. Remove the story from the roadmap **User Stories** list
4. If the story is superseded by a broader decision, add a blockquote marker at the top pointing to the superseding document

A closed story is never deleted. It is the reasoning record for the decision.

### Roadmap reference

Open stories are listed in the roadmap **User Stories** section with a single line and a short description. Closed stories are removed from this list — the story document itself is the permanent record.

---

## References

| Document | Purpose |
|---|---|
| [`task_lifecycle.md`](../concepts/task_lifecycle.md) | Full lifecycle description |
| [`documentation_policy.md`](documentation_policy.md) | Documentation structure and enforcement rules |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update sequence and cleanup rules |