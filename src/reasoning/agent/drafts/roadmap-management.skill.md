# Skill  --  Roadmap Management

## Purpose

Manage `devlog/roadmap.md` and `devlog/changelog.md` following project policy. Use this skill when asked to update the roadmap, mark completions, compact task groups, or extract a completed milestone.

---

## Before Acting

Read `docs/operations/roadmap_policy.md`. All rules, format specifications, and the step-by-step procedure are defined there. This skill does not restate them.

Identify the task from the operator's request before reading any other files:

- **Mark tasks**  --  during iteration, change `- [ ]` -> `- [x]` when AC is satisfied
- **Compact**  --  at Steps 8-9, replace fully-completed task group checklist with outcome summary
- **Sub-milestone close**  --  all children complete: compact, update summary table, promote next if applicable
- **Top-level milestone close**  --  all sub-milestones complete: extract to changelog, remove from roadmap, promote next major milestone

---

## Read Sequence

| Task | Read |
|---|---|
| Mark tasks | `roadmap.md` only |
| Compact | `roadmap.md` only |
| Sub-milestone close | `roadmap.md`, `roadmap_future.md` |
| Top-level milestone close | `roadmap.md`, `changelog.md`, `roadmap_future.md` |

---

## Core Rules

1. All items use markdown task list syntax: `- [x]` and `- [ ]`
2. Mark a task `- [x]` when its implementation satisfies the AC  --  the agent's completion check
3. The marker signals "ready for operator verification at Step 7"
4. If the operator disagrees at Step 7, revert to `- [ ]`, record discrepancy as resolved mid-iteration finding, reformulate scope, rewrite the incomplete task
5. Compaction: replace a fully-completed task group's checklist with a 1-3 sentence outcome summary. Keep the `- [x]` marker. Remove file lists, implementation notes, "Depends on" / "Prerequisite for" lines referencing now-completed items. Preserve design doc links and "Not in scope" / deferred tags.
6. Compaction proposal is presented at Step 7 for operator review; applied mechanically at Steps 8-9 after Gate 3 release.
7. Compaction applies at every level of nesting  --  a sub-group within an incomplete parent compacts independently once its own items are all complete.
8. Multi-level: when all subtasks are done, compact to a single task-level summary.
9. Remove superseded items immediately on supersession. Rationale in iteration handover.
10. Remove floating prose summary lines (e.g. "Prior completed items (8-12)")  --  the `- [x]` list is the visual summary.

---

## Output Shape

- Roadmap changes: targeted edits only  --  section removal, table row update, `- [x]` marks, checklist -> outcome summary replacements. No full-file rewrites.
- Changelog entry (top-level milestone close): fenced `changelog` block, ready to append verbatim.
- State what you changed and what the operator needs to do (e.g. "append changelog block, apply roadmap edits").

---

## Constraints

- Do not rewrite sections not affected by the current task
- Do not mark tasks `- [x]` before AC is satisfied
