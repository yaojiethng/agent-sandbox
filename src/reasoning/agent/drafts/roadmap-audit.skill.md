# Skill — Roadmap Audit

## Purpose

Audit `devlog/roadmap.md` for policy compliance and structural integrity. Use this skill when asked to check the roadmap for deviations from `docs/operations/roadmap_policy.md`, to verify compaction state, or to prepare for a compaction pass.

---

## Before Acting

Read `docs/operations/roadmap_policy.md` for the current rules. Read `audit.skill.md` if extending the audit to handover chain integrity. This skill covers roadmap-internal checks only.

---

## Audit Checks

### A. Format compliance — `- [x]` / `- [ ]` syntax

Run through every task entry in the active sub-milestone.

**A1. Marker format** — all items use markdown task list syntax (`- [x]` or `- [ ]`), not emoji (`✅` / `❌`) or bold headers alone. Flag unconverted items.

**A2. Nesting format** — sub-items are indented `- [x]` / `- [ ]` bullets, not embedded in prose paragraphs. Flag prose-wrapped sub-items that need restructuring.

**A3. Partial completion format** — for items with both done and pending sub-items: the parent item uses `- [ ]` with a description of what IS complete, completed sub-items use `- [x]` indented under the parent, pending sub-items use `- [ ]` indented under the parent. Flag items where done sub-items lack `- [x]` markers or where the parent carries no completion context.

### B. Compaction compliance

For each item in the active sub-milestone:

**B1. Completion-state compaction** — a task group with all sub-items `- [x]` must be compacted to a 1–3 sentence outcome summary, not retain an expanded checklist. Flag any fully-completed group still carrying a checklist.

**B2. Outcome summary format** — the `- [x]` marker persists after compaction. Flag compacted items missing the marker.

**B3. Survival table** — for each compacted task group, verify component-by-component:

| Component | Rule | Check |
|---|---|---|
| Design document links | Survive | Present if item had one |
| "Not in scope" / deferred tags | Survive | Present if item had them |
| File lists (parentheses after item name) | Removed | Absent from header |
| Implementation notes / partial specs | Removed | Absent from summary |
| Sub-item checklists / task breakdowns | Removed | Absent from summary |
| "Depends on" → now-completed items | Removed | Absent from summary |
| "Prerequisite for" | Removed | Absent from summary |

Flag any component present where it should be absent, or absent where it should survive.

**B4. Multi-level compaction depth** — when ALL sub-groups of a parent item are compacted, the parent should compact to a single task-level summary, not retain individual child summaries. Flag un-compacted parent items where all children are done.

**B5. Nested sub-group compaction** — a fully-completed sub-group within an incomplete parent must be compacted to an outcome summary. Flag un-compacted sub-groups within partially-complete items.

### C. Structural integrity

**C1. Floating prose summaries** — remove any "Prior completed items (X–Y)" or similar manual summary that duplicates the task list. Flag remaining prose summaries.

**C2. Superseded items** — any item superseded by later work must be removed entirely. Flag remaining superseded items.

**C3. Empty sections** — after removing items during compaction, any section that becomes empty must be removed (per Rules: "Empty sections — remove immediately"). Flag empty sections.

**C4. Redundant ordering blocks** — standalone "Implementation order" blocks that duplicate information already present in "Depends on" lines should be removed. Flag redundant blocks.

**C5. Dangling dependencies** — no active item should carry a "Depends on" line pointing to a now-removed or compacted item. Flag dangling dependency references.

### D. Pre-compaction readiness

Before a compaction pass, verify:

1. All tasks in groups to be compacted are `- [x]` (not `- [ ]`)
2. No task was prematurely marked `- [x]` without operator verification (check the handover for Step 7 AC status)
3. The compaction proposal text is drafted and ready for operator review

---

## Output Shape

Audit findings in a table:

| # | Section / Item | Finding | Category | Severity |
|---|---|---|---|---|
| 1 | M2.7 item 8 | Fully-completed group not compacted — checklist still expanded | B1 | High |
| 2 | M2.7 summary line | Floating prose summary "Prior completed items (8–12)" | C1 | Medium |

Severity levels:
- **High** — policy violation that blocks a clean compaction or would cause the next agent to misinterpret roadmap state
- **Medium** — format deviation that does not affect correctness but violates the standard
- **Low** — cosmetic issue or legacy artifact

---

## Constraints

- Do not fix issues during the audit — report them and wait for operator direction
- Do not audit closed handovers unless explicitly asked (handover chain audit is in `audit.skill.md`)
- If a finding requires interpretation of policy, state your interpretation and ask for confirmation before flagging
