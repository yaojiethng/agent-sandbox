# Roadmap Policy

Policy rules for `devlog/roadmap.md`, `devlog/roadmap_future.md`, and `devlog/changelog.md`.

**Role of this file.** This file owns the roadmap update invariants and record shape. It answers, in order: when the roadmap is touched (invocation moments), how updates are normalized (roadmap maintenance, promotion), what the record must look like (structure and filing rules), and how records retire (changelog, corrections). Other documents link here; they do not restate these rules.

**Decoupling principle.** The runbook and the invariants are independent layers. The runbook is expected to evolve as the model improves. The invariant set below should be insensitive to runbook changes: a change to a runbook should never *require* a change here. Improving the invariant set is welcome and autonomous; what signals coupling is not that it was edited, but *why* -- an edit forced by a runbook rename or renumber is entanglement, while an edit stating a better durable rule is healthy evolution.

**Two forms of rule.** Policy may state an invariant (a property of the state, holding at every commit gate) or a canonical procedure (a deterministic code-block guaranteed to satisfy an invariant). A loose procedure -- one with a large agent-decision space where the shape is not canonical -- is not stated here; it lives in the runbook that owns the moment and references these invariants rather than restating them.

---

## When the Roadmap Is Touched

The roadmap is not updated continuously during an iteration. It is touched at defined moments in the iteration and at milestone-workflow close. Do not update it outside these moments.

**Roadmap-update timing invariant:** the roadmap is the sole task list. A task is marked `- [x]` in the same iteration its resolving handover closes -- the handover's Closed state is the trigger, not a later cleanup pass. When an iteration generates a named task, it lands on the roadmap at iteration end, never in the handover alone: a task without a roadmap destination can fall through. If the operator rejects a completion claim, the marker reverts to `- [ ]` before the close.

The runbooks execute the moments; this policy states the invariants they satisfy. Every roadmap edit is a targeted change, not a full-file rewrite.

---

## Roadmap maintenance

Roadmap maintenance is a mechanical normalization step, not an event or a gate. It always runs after an iteration close and after a milestone close, on every node in the fractal tree whose children were modified. The canonical procedures below are deterministic, so they stay here as the single source; multiple runbooks invoke them and do not restate them.

### Compaction cascading

Invoked by [`/milestone-close`](../../workflow/coding-agent/prompts/milestone-close.md) and [`/wrapup`](../../workflow/coding-agent/prompts/wrapup.md); neither restates it. For each node whose direct children are all complete:

1. **Compact the node** -- replace each child's checklist with a `- [x]` outcome summary (1-3 sentences describing what was built). Keep design document links and "Not in scope" / deferred tags. Remove task breakdowns, file lists, and implementation notes (the handover retains them). Flip the node's heading status to `Complete` when one is shown.
2. **Check the node's own parent** -- if all siblings of this node are also compacted, compact the parent node (its sibling list becomes a single `- [x]` entry).
3. **Repeat upward** until reaching a node whose siblings are not all complete, or the top-level milestone is reached.
4. If compaction reaches the top-level milestone (all direct sub-milestones complete), run **Top-level milestone close** (see below).

### Top-level milestone close

Invoked by [`/milestone-close`](../../workflow/coding-agent/prompts/milestone-close.md) and the cascade it closes; the runbook does not restate it. When roadmap maintenance determines that all direct children of a top-level milestone are complete:

1. **Write the changelog entry** -- produce the entry for the completed milestone using [Changelog Format](#changelog-format). Output as a fenced block so the operator can append it verbatim to `changelog.md`.
2. **Remove the milestone section** -- delete the completed milestone's detail section from `roadmap.md` Upcoming Milestones. The detailed task breakdown is now in the changelog.
3. **Update the Summary table** -- change the milestone row to `[Complete -- see changelog](changelog.md#m{n}--{title})` linking to the specific milestone section anchor.
4. **Promote the next milestone** -- move the next incomplete milestone from `roadmap_future.md` into `roadmap.md` under `## Upcoming Milestones` (see [Milestone Promotion](#milestone-promotion)).

This is part of roadmap maintenance -- no separate trigger, no event gate. It runs automatically when the condition is met.

### Summary table update

After compaction, update the Milestone Summary table:

- A node that was compacted to a single `- [x]` entry gets its status updated in the table.
- A completed sub-milestone (all tasks done, no remaining items) shows as `Complete` with a changelog link.
- The parent milestone's status remains `In progress` until all direct children are complete.

---

## Milestone Promotion

Future milestone detail lives in `roadmap_future.md` to keep `roadmap.md` focused on the active milestone. `roadmap_future.md` is a planning document, not a historical record -- sections may be rewritten freely as understanding evolves. The changelog is the permanent record.

### Promotion invariant

The promotion rule is the durable invariant: promote the next incomplete milestone in the Milestone Summary table order. If the next milestone has sub-milestones (e.g. M2.1, M2.2), promote the parent section and all sub-milestone sections together as a single block.

The milestones' promotion moments are owned by the runbooks. [`/milestone-start`](../../workflow/coding-agent/prompts/milestone-start.md) Promote and record selects a next active milestone at a milestone open and flips its summary row to `In progress`. [`/iter`](../../workflow/coding-agent/prompts/iter.md) Scope gate runs the promotion check at an iteration scope gate: it catches the first iteration targeting a previously `Not started` milestone and flips it to `In progress` -- self-healing, because it reconciles stale summaries as they are targeted. [`/milestone-close`](../../workflow/coding-agent/prompts/milestone-close.md) Update the records runs the promotion transport at a full top-level close: it removes the completed milestone's detail section from `roadmap.md`, moves the next incomplete milestone from `roadmap_future.md` into `roadmap.md` under `## Upcoming Milestones`, updates the Milestone Summary table row (anchor link, status `In progress`), and removes the section from `roadmap_future.md`.

---

## Structure and Filing Rules

### Fractal Milestone Numbering

Milestones use a fractal numbering system that nests arbitrarily:

```text
M{n}          — top-level milestone (e.g. M2)
M{n}.{m}      — sub-milestone (e.g. M2.6)
M{n}.{m}.{o}  — sub-sub-milestone (e.g. M2.6.1)
...           — extends infinitely
```

**Rules:**

- Non-integer labels ("Phase 1", "Phase 1.5", "Step A") are prohibited in milestone numbering. If a milestone has phases, they are numbered as discrete sub-milestones with distinct integers (M2.6.1, M2.6.2, ...).
- The summary table in `roadmap.md` uses indentation to show parent-child nesting. The table displays each sub-milestone indented under its parent.
- Completed nesting levels are shown as `[Complete -- see changelog](changelog.md#...)` with a link to the relevant changelog section anchor.
- Changelog links point to the individual milestone or sub-milestone section in `changelog.md`, not to the file root.

### Record shape

**Active sub-milestone task list** -- the active sub-milestone carries a full task checklist grouped by functional area. This is the canonical task list; the handover references it, does not copy it.

**Acceptance criteria** -- the active sub-milestone carries an `**Acceptance criteria:**` block listing the end-to-end operator checks that must pass before the sub-milestone is considered complete. The task list records what is built; acceptance criteria record what the operator can verify once it is built. Criteria describe what the operator runs and observes -- not what files contain or what tasks are checked off. A criterion that duplicates a task checklist item is not an acceptance criterion.

**Non-active sub-milestones** -- carry an objective and scope paragraph only. No task checklist until the sub-milestone becomes active. Deferred work from prior sub-milestones is filed in `roadmap_future.md`, not accumulated in the scope paragraph.

**Task granularity** -- identify the file and nature of change. Omit implementation detail; link to the discussion document if context is needed.

**Summary table format** -- the Milestone Summary table uses indentation to show parent-child nesting via the fractal numbering scheme. Each sub-milestone is indented under its parent with `&nbsp;&nbsp;` prefixes. Links point to specific sections (roadmap.md anchors or changelog.md section anchors), never to file roots.

**Persistent sections** -- Milestone Summary table, Upcoming Milestones, Future Security & Network Hardening, and Governance Hardening are structural and must not be removed.

**Empty sections** -- remove immediately.

### Filing rules

**Decisions** -- design decisions made during an iteration are recorded in the roadmap under the active sub-milestone entry. Format: short decision statement, rationale, and a link to the full record in the relevant architecture or discussion document. The roadmap is the accumulated decision log for the milestone; iteration handovers log which decisions were made per iteration.

**Open questions** -- open design questions live in the design document, not the roadmap. The roadmap carries a single task entry referencing the design document (e.g. "Resolve open design questions -- see [design doc]"). When questions are resolved, the decision is recorded in the design document (not as Q&A -- as a named decision with rationale). The roadmap task is checked off. Design documents must not contain Q&A-style sections ("Q: ... A: ..." or numbered question/answer pairs).

**Not in scope** -- each milestone carries a `#### Not in scope` sub-section nested under its milestone header, listing items indefinitely deferred or explicitly excluded from that milestone's scope, in point form. One sentence per item with a link to the relevant discussion or architecture document if context is needed. This replaces the former `## Known Limitations` global section -- limitations are scoped to the milestone that produced them, not accumulated in a catch-all. At milestone close, deferred items carry forward to `roadmap_future.md` or to the next active milestone's Not in scope section.

**Roadmap task placement** -- a deferred item escalated to the roadmap lands as a named task entry nested under the current sub-milestone's task list unless directed otherwise. Do not re-list an item that already exists in `roadmap.md` or `roadmap_future.md`; name it, do not duplicate it. Whether an item escalates to the roadmap or is re-deferred is the finding write-back decision, owned by the `iteration_policy.md` [carry-forward-resolution close invariant](iteration_policy.md#iteration-invariants) and applied by [`/wrapup`](../../workflow/coding-agent/prompts/wrapup.md) and [`/milestone-close`](../../workflow/coding-agent/prompts/milestone-close.md); this policy owns only where the entry lands.

---

## Changelog Format

Changelog entries live in `devlog/changelog.md`, appended in milestone order. Each entry is self-contained and can be produced without reading the rest of the file.

### Entry structure

```text
## M{n} — {Title}

*{One sentence: what the system can now do.}*

{Two to four sentences: what was built — mechanisms, key decisions, concrete outcomes. No file lists. No future language. Capability first, mechanism second.}

---
```

### Writing guidance

- The italicised summary is the capability sentence. Write it as a statement of what an operator or agent can now do that they could not before.
- The body sentences describe the mechanism -- what was built to enable the capability and any key decisions made. Mention concrete components (scripts, pipeline stages, config patterns) without listing files.
- Do not use future language (`will`, `plan`, `eventually`). The changelog describes completed work only.
- Balance: M1/M1.1-style entries are too abstract; M1.2/M1.3-style entries from the old roadmap are too implementation-heavy. Aim for one capability sentence plus two to three mechanism sentences.

### Agent snippet output

When producing a changelog entry during a milestone completion pass, output the entry as a fenced block so it can be appended to `changelog.md` without reading the existing file:

````text
```changelog
## M{n} -- {Title}

*{Capability sentence.}*

{Mechanism sentences.}

---
```
````

The operator appends the block contents verbatim to `changelog.md`.

---

## Corrections to Closed Roadmap and Changelog Entries

A closed roadmap entry or changelog entry does not change. It keeps its text, gains the marker below, and gains the successor entry that carries the correction. The changelog is the roadmap's archived half and is corrected the same way.

**Markers.**

- `[SUPERSEDED in MX.X]` -- the row is closed and a later milestone carries the correction. The row stays.
- `[REMOVED in MX.X]` -- the row is closed and the content it claimed is gone from the active system description. The row stays.

**The anchor** names the milestone that carries the correction, open or closed. A correction landing inside the current milestone is marked `[SUPERSEDED in M3]`. Work belonging to no milestone is marked with its iteration: `[SUPERSEDED in 20260927-06]`.

**The successor entry** is written where the roadmap puts new work, under the current sub-milestone, in the row form the milestone requires. Do not rewrite the marked row, and do not delete it.

**A correction may reopen the record.** The record ends closed, with the metadata it carried before. A correction that cannot be finished leaves the record as it was.

The shared principle, the direction, the propagation rule and the agent's checks are in [`documentation_policy.md`](documentation_policy.md#post-close-document-corrections). The decisions behind this section are in [`closed_record_corrections.md`](../adr/closed_record_corrections.md).
