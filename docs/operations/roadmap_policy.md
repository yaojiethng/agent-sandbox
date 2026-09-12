# Roadmap Policy

Policy rules for `devlog/roadmap.md`, `devlog/roadmap_future.md`, and `devlog/changelog.md`.

**Role of this file.** This file owns all roadmap update procedure and record shape. It answers, in order: when the roadmap is touched (invocation moments), how updates are executed (bookkeeping, promotion), what the record must look like (structure and filing rules), and how records retire (changelog, corrections). Other documents link here; they do not restate these rules.

---

## When the Roadmap Is Touched

The roadmap is not updated continuously during an iteration. It is touched at defined moments in the minor loop and at major loop close. Do not update it outside these moments.

**Roadmap-update timing rule:** a roadmap task is marked `- [x]` in the same iteration its resolving handover closes — the handover's Closed state is the trigger, not a later cleanup pass. If the operator rejects a completion claim at the pre-close gate, revert the marker to `- [ ]` and record the discrepancy as a resolved mid-iteration finding. When an iteration generates a task (an explicit named roadmap entry), add it to the roadmap at iteration end. The roadmap is the sole task list. Do not leave new tasks in the handover alone; a task without a roadmap destination can fall through.

### Iteration start (Step 1)

1. Read `roadmap.md`
2. Read the task list as this iteration's pending work; do not copy it into the handover

### Step 7 — Pre-close verification

Per [`iteration_policy.md` Step 7](iteration_policy.md#step-7--pre-close-verification), the agent presents a pre-close summary whose Roadmap write-back section states, per task touched, the exact row change — including compaction proposals for fully-completed task groups (outcome summaries that would replace their checklists if the operator accepts at Gate 3).

The operator reviews the compaction proposal alongside AC verification at Gate 3. Accepted compaction text is applied mechanically at Steps 8–9.

### Iteration end (Steps 8–9)

Apply the approved write-back: compaction summaries replace completed groups' checklists; generated tasks land as named entries. The mechanical rules are under [Post-close Bookkeeping](#post-close-bookkeeping); the compaction format under [Compaction cascading](#compaction-cascading).

Produce all roadmap edits as targeted changes, not full-file rewrites.

---

## Post-close Bookkeeping

After every iteration end (Steps 8–9), run bookkeeping on every node in the fractal tree whose children were modified files. Bookkeeping is not an event or gate — it is a mechanical normalization step that always runs.

### Compaction cascading

For each node whose direct children were all completed in this iteration:

1. **Compact the node** — replace each child's checklist with a `- [x]` outcome summary (1–3 sentences describing what was built). Keep design document links and "Not in scope" / deferred tags. Remove task breakdowns, file lists, and implementation notes (the handover retains them).
2. **Check the node's own parent** — if all siblings of this node are also compacted, compact the parent node (its sibling list becomes a single `- [x]` entry).
3. **Repeat upward** until reaching a node whose siblings are not all complete, or the top-level milestone is reached.
4. If compaction reaches the top-level milestone (all direct sub-milestones complete), run **Top-level milestone close** (see below).

### Top-level milestone close

When post-close bookkeeping determines that all direct children of a top-level milestone are complete:

1. **Write the changelog entry** — produce the entry for the completed milestone using [Changelog Format](#changelog-format). Output as a fenced block so the operator can append it verbatim to `changelog.md`.
2. **Remove the milestone section** — delete the completed milestone's detail section from `roadmap.md` Upcoming Milestones. The detailed task breakdown is now in the changelog.
3. **Update the Summary table** — change the milestone row to `[Complete — see changelog](changelog.md#m{n}--{title})` linking to the specific milestone section anchor.
4. **Promote the next milestone** — move the next incomplete milestone from `roadmap_future.md` into `roadmap.md` under `## Upcoming Milestones` (see [Milestone Promotion](#milestone-promotion)).

This is part of bookkeeping — no separate trigger, no event gate. It runs automatically when the condition is met.

### Summary table update

After compaction, update the Milestone Summary table:

- A node that was compacted to a single `- [x]` entry gets its status updated in the table.
- A completed sub-milestone (all tasks done, no remaining items) shows as `Complete` with a changelog link.
- The parent milestone's status remains `In progress` until all direct children are complete.

### Carry-forward escalation

If a deferred item will not be picked up in the next iteration, add it as a named task entry to the roadmap. Do not re-list an item that already exists in `roadmap.md` or `roadmap_future.md`. Nest new tasks under the current sub-milestone's task list unless directed otherwise.

---

## Milestone Promotion

Future milestone detail lives in `roadmap_future.md` to keep `roadmap.md` focused on the active milestone. `roadmap_future.md` is a planning document, not a historical record — sections may be rewritten freely as understanding evolves. The changelog is the permanent record.

### Promotion check

At minor loop Step 2 (scope confirmation), before presenting the scope proposal:

1. Read the Milestone Summary table.
2. Identify the milestone targeted by this iteration (from roadmap frontmatter or iteration context).
3. If the target milestone's status implies less progress than this iteration intends (e.g. `Not started` when starting an iteration), update the status to `In progress`.
4. Record the promotion in the handover's Completed table.

This check is self-healing — it catches both stale summaries and the first iteration targeting a new milestone.

### Promotion transport

When top-level milestone close runs (bookkeeping compaction reaches the root), the next milestone is promoted from `roadmap_future.md` into `roadmap.md`.

1. Move the milestone section from `roadmap_future.md` into `roadmap.md` under `## Upcoming Milestones`
2. Update the Milestone Summary table row in `roadmap.md`: add anchor link, set status to `In progress`
3. Remove the section from `roadmap_future.md`

**Which milestone to promote:** the next incomplete milestone in the Milestone Summary table order. If the next milestone has sub-milestones (e.g. M2.1, M2.2), promote the parent section and all sub-milestone sections together as a single block.

---

## Structure and Filing Rules

### Fractal Milestone Numbering

Milestones use a fractal numbering system that nests arbitrarily:

```
M{n}          — top-level milestone (e.g. M2)
M{n}.{m}      — sub-milestone (e.g. M2.6)
M{n}.{m}.{o}  — sub-sub-milestone (e.g. M2.6.1)
...           — extends infinitely
```

**Rules:**
- Non-integer labels ("Phase 1", "Phase 1.5", "Step A") are prohibited in milestone numbering. If a milestone has phases, they are numbered as discrete sub-milestones with distinct integers (M2.6.1, M2.6.2, ...).
- The summary table in `roadmap.md` uses indentation to show parent-child nesting. The table displays each sub-milestone indented under its parent.
- Completed nesting levels are shown as `[Complete — see changelog](changelog.md#...)` with a link to the relevant changelog section anchor.
- Changelog links point to the individual milestone or sub-milestone section in `changelog.md`, not to the file root.

### Record shape

**Active sub-milestone task list** — the active sub-milestone carries a full task checklist grouped by functional area. This is the canonical task list; the handover references it, does not copy it.

**Acceptance criteria** — the active sub-milestone carries an `**Acceptance criteria:**` block listing the end-to-end operator checks that must pass before the sub-milestone is considered complete. The task list records what is built; acceptance criteria record what the operator can verify once it is built. Criteria describe what the operator runs and observes — not what files contain or what tasks are checked off. A criterion that duplicates a task checklist item is not an acceptance criterion.

**Non-active sub-milestones** — carry an objective and scope paragraph only. No task checklist until the sub-milestone becomes active. Deferred items from prior sub-milestones are filed in `roadmap_future.md`, not accumulated in the scope paragraph.

**Task granularity** — identify the file and nature of change. Omit implementation detail; link to the discussion document if context is needed.

**Summary table format** — the Milestone Summary table uses indentation to show parent-child nesting via the fractal numbering scheme. Each sub-milestone is indented under its parent with `&nbsp;&nbsp;` prefixes. Links point to specific sections (roadmap.md anchors or changelog.md section anchors), never to file roots.

**Persistent sections** — Milestone Summary table, Upcoming Milestones, Future Security & Network Hardening, and Governance Hardening are structural and must not be removed.

**Empty sections** — remove immediately.

### Filing rules

**Decisions** — design decisions made during an iteration are recorded in the roadmap under the active sub-milestone entry. Format: short decision statement, rationale, and a link to the full record in the relevant architecture or discussion document. The roadmap is the accumulated decision log for the milestone; iteration handovers log which decisions were made per iteration.

**Open questions** — open design questions live in the design document, not the roadmap. The roadmap carries a single task entry referencing the design document (e.g. "Resolve open design questions — see [design doc]"). When questions are resolved, the decision is recorded in the design document (not as Q&A — as a named decision with rationale). The roadmap task is checked off. Design documents must not contain Q&A-style sections ("Q: ... A: ..." or numbered question/answer pairs).

**Not in scope** — each milestone carries a `#### Not in scope` sub-section nested under its milestone header, listing items indefinitely deferred or explicitly excluded from that milestone's scope, in point form. One sentence per item with a link to the relevant discussion or architecture document if context is needed. This replaces the former `## Known Limitations` global section — limitations are scoped to the milestone that produced them, not accumulated in a catch-all. At milestone close, deferred items carry forward to `roadmap_future.md` or to the next active milestone's Not in scope section.

---

## Changelog Format

Changelog entries live in `devlog/changelog.md`, appended in milestone order. Each entry is self-contained and can be produced without reading the rest of the file.

### Entry structure

```
## M{n} — {Title}

*{One sentence: what the system can now do.}*

{Two to four sentences: what was built — mechanisms, key decisions, concrete outcomes. No file lists. No future language. Capability first, mechanism second.}

---
```

### Writing guidance

- The italicised summary is the capability sentence. Write it as a statement of what an operator or agent can now do that they could not before.
- The body sentences describe the mechanism — what was built to enable the capability and any key decisions made. Mention concrete components (scripts, pipeline stages, config patterns) without listing files.
- Do not use future language (`will`, `plan`, `eventually`). The changelog describes completed work only.
- Balance: M1/M1.1-style entries are too abstract; M1.2/M1.3-style entries from the old roadmap are too implementation-heavy. Aim for one capability sentence plus two to three mechanism sentences.

### Agent snippet output

When producing a changelog entry during a milestone completion pass, output the entry as a fenced block so it can be appended to `changelog.md` without reading the existing file:

````
```changelog
## M{n} — {Title}

*{Capability sentence.}*

{Mechanism sentences.}

---
```
````

The operator appends the block contents verbatim to `changelog.md`.

---

## Corrections to Closed Roadmap and Changelog Entries

Closed roadmap entries and changelog entries are corrected in-place by appending a `[SUPERSEDED in MX.X]` or `[REMOVED in MX.X]` tag to the affected sentence or claim. The tag names the milestone that superseded or removed the content. The original text is preserved — the tag marks it as stale without deleting it.

- `[SUPERSEDED in M2.3]` — the claim is still valid but has been superseded by a later implementation
- `[REMOVED in M2.4]` — the claim is no longer accurate and has been removed from the active system description

Do not rewrite the entry. The tag is sufficient notice that the reader must consult the referenced milestone.
