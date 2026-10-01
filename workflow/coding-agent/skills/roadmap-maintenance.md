---
name: roadmap-maintenance
description: "Maintains devlog/roadmap.md and leaves it correct. Use when the operator asks to check the roadmap against policy, verify compaction state, or prepare a compaction pass."
---

# roadmap-maintenance

<!-- Source: this skill subsumes workflow/coding-agent/audits/roadmap-audit.skill.md. That file is superseded and its removal belongs to the operator's roadmap task. -->

## Purpose

Maintains `devlog/roadmap.md`. The run finds each defect, corrects it, and records what it changed, so the roadmap is correct when the run ends. An audit only reports and leaves the defect in place. This runbook therefore corrects what it finds and holds back only what needs the operator's judgement.

This runbook is a convenience copy of the checks. The rules live in [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md). Read that document for the authoritative form before acting. Where this runbook and the policy disagree, the policy wins.

The subject is the roadmap alone. Handover content and handover chain maintenance belong to [`handover-maintenance.md`](handover-maintenance.md).

## When to run

- At iteration start, in the roadmap check that opens the iteration.
- Before a compaction pass, to confirm the pass is safe (Step 4).
- When the operator asks to check the roadmap against `roadmap_policy.md`.

Do not run it as a closed-history sweep. A compacted roadmap has, by design, dropped the detail this runbook checks.

## Procedure

### Step 1 - Format compliance

Run through every task entry in the active sub-milestone.

**1.1 Marker format.** Every item uses markdown task list syntax (`- [x]` or `- [ ]`), not an emoji checkmark and not a bold header alone. Convert an unconverted item.

**1.2 Nesting format.** Sub-items are indented `- [x]` and `- [ ]` bullets, not embedded in a prose paragraph. Restructure a prose-wrapped sub-item into bullets.

**1.3 Partial completion format.** For an item that has both done and pending sub-items, the parent item uses `- [ ]` and describes what is complete, the completed sub-items use `- [x]` indented under the parent, and the pending sub-items use `- [ ]` indented under the parent. An item is a defect when a done sub-item lacks its `- [x]` marker, or when the parent carries no completion context.

Completion criterion: no unconverted marker remains, no sub-item sits inside prose, and every partially complete parent describes what is complete.

### Step 2 - Compaction compliance

Run this step over each item in the active sub-milestone.

**2.1 Completion-state compaction.** A task group whose sub-items are all `- [x]` becomes a 1 to 3 sentence outcome summary. It does not keep an expanded checklist. Compact a fully completed group that still carries one.

**2.2 Outcome summary marker.** The `- [x]` marker survives the compaction. A compacted item without the marker is a defect.

**2.3 Survival table.** For each compacted task group, verify component by component.

| Component | Rule | Check |
|---|---|---|
| Design document links | Survive | Present when the item had one |
| Not-in-scope and deferred tags | Survive | Present when the item had them |
| File lists in parentheses after the item name | Removed | Absent from the header |
| Implementation notes and partial specs | Removed | Absent from the summary |
| Sub-item checklists and task breakdowns | Removed | Absent from the summary |
| "Depends on" pointing at a now-completed item | Removed | Absent from the summary |
| "Prerequisite for" | Removed | Absent from the summary |

A component that should survive and is gone, or one that should be removed and is present, is a defect in either direction.

**2.4 Multi-level compaction depth.** When every sub-group of a parent item is compacted, the parent becomes a single task-level summary. It does not retain the child summaries. Compact a parent whose children are all done.

**2.5 Nested sub-group compaction.** A fully completed sub-group inside an incomplete parent becomes an outcome summary. Compact an expanded sub-group inside a partially complete item.

Completion criterion: no expanded checklist survives under a fully completed group, and every compaction satisfies the survival table.

### Step 3 - Structural integrity

**3.1 Floating prose summaries.** Remove a manual summary such as "Prior completed items" that repeats the task list.

**3.2 Superseded items.** Remove an item that later work superseded.

**3.3 Empty sections.** Remove a section that Step 3.2 or Step 2 emptied. `roadmap_policy.md` requires removal rather than an empty heading.

**3.4 Redundant ordering blocks.** Remove a standalone "Implementation order" block that repeats information already carried by "Depends on" lines.

**3.5 Dangling dependencies.** Remove a "Depends on" line on an active item that points at a removed or compacted item, or repoint it at the surviving item.

Completion criterion: no floating prose summary, superseded item, empty section, redundant ordering block, or dangling dependency remains in the active sub-milestone.

### Step 4 - Pre-compaction readiness

This step changes nothing. It decides whether a compaction pass is safe to propose.

1. Every task in a group that is a compaction candidate is `- [x]`, not `- [ ]`.
2. No task was marked `- [x]` before the operator verified it. Check the handover for its Step 7 acceptance-criteria status.
3. The compaction proposal text is drafted and ready for operator review.

Completion criterion: all three hold, or the run stops with the failing condition named. A premature `- [x]` blocks the pass until the operator resolves it.

### Step 5 - Record the run

Report the changes per `roadmap_policy.md`. A correction that is purely mechanical is applied and reported. A correction that changes what the roadmap asserts needs the operator's release first. Report it, mark it High severity, and stop.

## Output shape

The report is one table, one row per correction or per defect left for the operator.

| Section / item | Change applied or held | Category | Severity |
|---|---|---|---|
| M2.7 pre-flight checks | Compacted a fully completed group that still carried a checklist | 2.1 | Medium |
| M2.7 summary line | Held a floating prose summary for operator release | 3.1 | High |

The report closes with the counts by category and the state of the Step 4 gate.

Severity routes the correction:

- **High** -- the defect is a policy violation that blocks a clean compaction, or it would make the next agent misread roadmap state. Hold it for the operator.
- **Medium** -- the defect is a format deviation that does not change what the roadmap asserts. Apply it.
- **Low** -- the defect is cosmetic or a legacy artifact. Apply it.

## Non-goals

- Does not check closed handovers or the handover chain. That is [`handover-maintenance.md`](handover-maintenance.md).
- Does not write policy. A check that no policy text covers is a gap to report, not a rule to add here.
- Does not open, re-scope, or close an iteration.
- Does not change a milestone's task set. Adding or removing a task is a roadmap decision, not a maintenance correction.

## Failure modes

- **A premature `- [x]` looks like a finished group.** Step 2 then compacts an unverified claim and the loss is permanent. Step 4 exists to catch it; when Step 4 fails, stop rather than compact.
- **Over-compaction drops surviving detail.** A compaction that removes a design link or a deferred tag loses information the policy keeps. Check the survival table before writing a summary.
- **Scope creep into task content.** Adding a task to make a format check pass turns maintenance into a roadmap decision. Report the need instead.
- **Interpretation of a policy gap.** When a finding needs a reading of `roadmap_policy.md` that the document does not settle, state the reading and ask for confirmation before flagging or fixing.
