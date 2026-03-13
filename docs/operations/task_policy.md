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

## Investigation Documents

Investigation documents live in `docs/discussions/` with the prefix `investigation_`. They are the working record for a specific option within a user story — one investigation per candidate, each linked to a parent story.

### Required sections

Investigations follow a fixed section sequence. The fixed order makes section-level navigation by header grep reliable without reading the full file.

| Section | When added | Purpose |
|---|---|---|
| **Status line** | At creation | One line immediately after the title: current status, key blocker or outcome |
| **Direction + Parent story** | At creation | Which investigation direction this belongs to; link to parent story |
| **Required reading** | At creation | Prerequisite documents; links only, no prose |
| **Summary** | At creation | What this option is and how it works; 2–4 sentences |
| **Architecture / Findings** | During investigation | What was discovered; may be iterative subsections |
| **Open Questions** | During investigation | Unresolved questions blocking a recommendation |
| **Constraints** | At creation or during investigation | Non-negotiable requirements |
| **Next Steps** | During investigation | Immediate actions; replaced by Resolution at closure |
| **Resolution / Conclusion** | At closure | Decision reached, where work went, why |

### Lifecycle states

| Status | Meaning |
|---|---|
| `Not started` | Stub — structure created, investigation not begun |
| `In progress` | Active — open questions remain |
| `Resolved` | Closed — Conclusion/Resolution section complete; work promoted or absorbed |
| `Superseded` | Closed — made obsolete by a broader decision; redirect to superseding document |

---

## Agent Working Discipline

### Read discipline — grep before opening

Before opening any file in full, run a targeted search to confirm the file contains relevant content and identify the specific lines needed. Full reads are only justified when the entire file is the subject of the work.

**For change passes across multiple files:**
```bash
grep -rn "TERM" path/to/scope/
```
Build the complete change list from grep output. Open only files that appear in results, and use `view_range` to read only the relevant lines.

**For section navigation within a known file:**
```bash
grep -n "^##" filename.md
```
Use the section map to target `view_range` rather than reading from the top.

A full file read without a prior grep is a signal the discipline is not being applied.

### When full reads are justified

- The file is the direct subject of the current task (e.g. rewriting a section)
- The file is under 40 lines
- The file is being read for the first time in a session and its structure is unknown

---

## Session Handover

A handover is a session log, not a document. It records what was done and what comes next — enough for a new agent to continue without re-reading the session history. It is not part of the documentation system and is not subject to documentation policy.

If handover conventions grow to cover retention, review process, or tooling, extract to a dedicated `handover_policy.md`. For now this section is sufficient.

### File naming

```
YYYYMMDD_agent_handover.md
```

Stored at the repo root alongside `agent_context_brief.md`. Multiple handovers accumulate — do not overwrite previous ones. The most recent date is the active handover.

### Required sections

```markdown
# Agent Handover

**Session date:** YYYY-MM-DD
**Milestone:** <milestone ID and name>
**Session type:** <Implementation | Documentation | Housekeeping | Investigation>

## Completed this session
<table: file | one-line change summary>

## Next task
<milestone section heading from roadmap>
<files needed from operator if known>
<grep to run at session start if applicable>

## Watch out for
<max three items>
```

### Rules

- **Completed this session** is a table, not prose. One row per file. If no files changed, write "No file changes this session."
- **Next task** points to the milestone section in the roadmap — include the section heading so the agent can find it immediately. The agent reads the full milestone entry at session start: open decisions, task list, whatever is currently there. The handover does not filter or summarise the milestone. If the milestone entry is incomplete, that is fine — the agent determines what to do from what is there.
- **Watch out for** is capped at three items. More than three is a signal the session was not scoped tightly enough; record the rest in the relevant document instead.
- Do not summarise decisions or reasoning — that belongs in the documents where decisions were recorded. The handover trusts the next agent to read `doc_status.md` and follow links.
- Handover does not replace: story Resolution sections, roadmap task checkboxes, or changelog entries.

---

## References

| Document | Purpose |
|---|---|
| [`task_lifecycle.md`](../concepts/task_lifecycle.md) | Full lifecycle description |
| [`documentation_policy.md`](documentation_policy.md) | Documentation structure and enforcement rules |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update sequence and cleanup rules |
