---
name: task-list
description: "agent-sandbox's task-list convention - the roadmap, the future roadmap and the changelog: their shape, their states, their numbering, and the rules for filing into them. Use when a workflow procedure reads or writes the task list."
---

# task-list

| Record | Path |
|---|---|
| The current sub-milestone and its pending tasks | `devlog/roadmap.md` |
| The sub-milestones planned but not active | `devlog/roadmap_future.md` |
| The completed sub-milestones, newest first | `devlog/changelog.md` |

The roadmap and its two companions are one record: a milestone title, a status, or an anchor that disagrees across them is one defect, whichever file it sits in.

`devlog/roadmap_future.md` is a planning document, not a historical record: its sections may be rewritten freely as understanding evolves, and the changelog is the permanent record.

## The milestone identifier

The roadmap's `active-milestone` frontmatter and a handover's `milestone` field carry the same value: the milestone's identifier, a space-hyphen-space, then its name. The identifier is a dotted path (`M3.3.1`, `T12`) and the name is the one the milestone carries in the roadmap. If a handover's `milestone` field names a milestone the roadmap does not carry, the handover is unassigned.

## Marking a task done

**The invariant.** A completed task is marked, and the mark is committed. The roadmap is the sole task list: a task an iteration generates lands on the roadmap, not only in a handover.

**The marker obeys the nesting.** A parent row is `- [x]` only when every row beneath it is `- [x]`, however complete the parent's own text reads.

**A rejected completion reverts.** When the operator rejects a completion claim, the marker returns to `- [ ]`.

**Every roadmap edit is a targeted change**, not a full-file rewrite.

## Milestone states

A milestone is a node in the roadmap's tree, not a workflow with a record of its own. Tasks are grouped by functional area, and a group becomes a sub-milestone. The fractal numbering applies at every level of the nesting. A node is in one of four states:

| State | Meaning |
|---|---|
| `shaped` | the milestone exists, is titled, and holds filed tasks; it is not active |
| `active` | the milestone is the one iterations run against |
| `closing` | every row is `[x]`; the close is running |
| `closed` | the close landed; the detail moved to the changelog |

The milestone workflow does not begin before the prior top-level milestone is closed in the changelog. At close, no new decisions are made and no substantive work occurs.

Escalated far-reaching correctness work defers the close; the node stays `active` until the escalation completes. There is no `close-blocked` state: a deferred close is an `active` node whose close has not run.

## Milestone numbering

Milestones use fractal numbering that nests without limit:

```text
M{n}          - top-level milestone (e.g. M2)
M{n}.{m}      - sub-milestone (e.g. M2.6)
M{n}.{m}.{o}  - sub-sub-milestone (e.g. M2.6.1)
```

Non-integer labels ("Phase 1", "Phase 1.5", "Step A") are prohibited. A milestone with phases numbers them as discrete sub-milestones with distinct integers (M2.6.1, M2.6.2, ...).

## The record's shape

**Active sub-milestone task list** - the active sub-milestone carries a full task checklist grouped by functional area. This is the canonical task list; a handover references it and does not copy it.

**Acceptance criteria** - the active sub-milestone carries an `**Acceptance criteria:**` block listing the end-to-end operator checks that must pass before the sub-milestone is complete. The task list records what is built; the criteria describe what the operator runs and observes, not what files contain or what tasks are checked off. A criterion that duplicates a task checklist item is not an acceptance criterion.

**Non-active sub-milestones** - carry an objective and scope paragraph, and their task rows may be written before the milestone becomes active, because task rows written only in a plan document are not tracked anywhere. A milestone holding an open row is never `Complete`, whatever its status column says. Deferred work from prior sub-milestones is filed in `roadmap_future.md`, not accumulated in the scope paragraph.

**Objective** - a milestone's objective is stated in one sentence. The scope paragraph beneath it carries the rest of the framing.

**Dependencies** - a sub-milestone names the prior sub-milestones it depends on, explicitly.

**Task granularity** - identify the file and nature of change. Omit implementation detail; link to the discussion document if context is needed.

**The Milestone Summary table** uses indentation to show parent-child nesting via the fractal numbering. Each sub-milestone is indented under its parent with `&nbsp;&nbsp;` prefixes. Links point to specific sections (roadmap anchors, future-roadmap anchors or changelog section anchors), never to file roots. A link names the whole heading of its target, so a heading that carries a suffix yields a longer fragment; a status or a removal note belongs in the entry body, not in the heading.

**Persistent sections** - Milestone Summary table, Upcoming Milestones, Future Security & Network Hardening, and Governance Hardening are structural and must not be removed. Remove an empty section immediately.

**Frontmatter** - `active-milestone` names the milestone work is scoped to, at the level it sits at. A milestone open, a sub-milestone close and a full top-level close each set it; the runbooks that run those moments own the settings.

## Filing rules

**Decisions** - design decisions made during an iteration are recorded in the roadmap under the active sub-milestone entry. Format: short decision statement, rationale, and a link to the full record in the relevant architecture or discussion document. The roadmap is the accumulated decision log for the milestone; iteration handovers log which decisions were made per iteration.

**Open questions and under-specified work** - open design questions live in the discussion document, not the roadmap. The roadmap carries a single task entry referencing that document. A story-backed row is the same mechanism: an under-specified task whose specification lives in the story. The task is checked off when the document resolves.

**Not in scope** - each milestone carries a `#### Not in scope` sub-section nested under its milestone header, listing items indefinitely deferred or explicitly excluded from that milestone's scope, in point form. One sentence per item, with a link to the relevant discussion or architecture document if context is needed. Limitations are scoped to the milestone that produced them, not accumulated in a catch-all section. At milestone close, deferred items carry forward to `roadmap_future.md` or to the next active milestone's Not in scope section.

**Roadmap task placement** - a deferred item escalated to the roadmap lands as a named task entry nested under the current sub-milestone's task list unless directed otherwise. Do not re-list an item that already exists in `roadmap.md` or `roadmap_future.md`; name it, do not duplicate it. Whether an item escalates to the roadmap or is re-deferred is the finding write-back decision, owned by the close invariants in [`iteration_policy.md`](../../../docs/policies/iteration_policy.md#iteration-invariants) and applied by `/wrapup` and `/milestone-close`; this convention owns only where the entry lands.

**Sub-items and follow-ons** - a task decomposes into sub-rows only when a child is work in its own right: it has its own outcome, its own acceptance, and could be worked and closed on its own. Anything else stays in the parent's text - a step of a procedure, a unit of a workflow's ordered execution, or a check the parent already carries. Record an open follow-on as its own row rather than as a sub-row of the row that raised it, unless the follow-on cannot be closed without its parent. A closed parent's summary text carries no open follow-on: the parent names it in one clause where a reader needs the link.

**Single-edit record defects** - a defect in the record layer that one edit fixes, found by a gate or a survey, is corrected in place and named in the iteration's handover. It does not become a roadmap row: write a row only when the work needs a design decision, spans iterations, or closes a policy gap. A sweep that finds several such defects produces one commit and one handover, not one row each.

**Ordering** - tasks may be ordered: a task can be sequenced after another task, or after a session that must run first. A task is *blocked* while something ordered before it has not completed. The roadmap carries no blocked marker: ordering is read from the rows at the moment a task is chosen.

## The changelog entry

Changelog entries live in `devlog/changelog.md`, appended in milestone order. Each entry is self-contained and can be produced without reading the rest of the file.

```text
## M{n} - {Title}

*{One sentence: what the system can now do.}*

{Two to four sentences: what was built - mechanisms, key decisions, concrete outcomes. No file lists. Capability first, mechanism second.}

---
```

The italicised summary is the capability sentence: what an operator or agent can now do that they could not before. Name concrete components without listing files. The changelog describes completed work only. An entry that states only abstract capability is too thin; one that recounts the implementation is too heavy. The judgement is the `communication-principle-dont-forecast-undone-work` skill at `$AGENT_HOME/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md`.

## Corrections to a closed entry

A closed roadmap or changelog entry does not change: it keeps its text, gains one of the markers below, and gains the successor entry that carries the correction.

| Marker | Meaning |
|---|---|
| `[SUPERSEDED in MX.X]` | the row is closed and a later milestone carries the correction; the row stays |
| `[REMOVED in MX.X]` | the row is closed and the content it claimed is gone from the active system description; the row stays |

**Marker order.** When more than one correction lands on a closed row, the markers read newest first, oldest last. The newest marker governs; a reader acts on it. A row never carries two markers for the same correction.

**The anchor** names the milestone that carries the correction, open or closed. A correction landing inside the current milestone is marked `[SUPERSEDED in M3]`. Work belonging to no milestone is marked with its iteration: `[SUPERSEDED in 20260927-06]`.

**The successor entry** is written where the roadmap puts new work, under the current sub-milestone, in the row form the milestone requires. Do not rewrite the marked row, and do not delete it.

A correction that cannot be finished leaves the record as it was, with the metadata it carried before. A correction that does finish reopens the record and closes it again with the successor entry; the changelog is corrected the same way.

The shared principle, the direction, the propagation rule and the form per record type are in the [`record-correction`](../../../workflow/coding-agent/prompts/record-correction.md) procedure, `## Correcting a record`. The decisions behind the correction form are in `docs/adr/closed_record_corrections.md`.
