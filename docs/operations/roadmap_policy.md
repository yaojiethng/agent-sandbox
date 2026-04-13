# Roadmap Policy

Policy rules for `docs/devlog/roadmap.md`, `docs/devlog/roadmap_future.md`, and `docs/devlog/changelog.md`.

---

## When the Roadmap Is Touched

The roadmap is not updated continuously during a session. It is touched at two defined moments in the minor loop and once at major loop close. Do not update it outside these moments.

### Session open (Step 1)
1. Read `roadmap.md`
2. Compact any fully-completed task groups from the previous session — replace the group header and checklist with a conceptual outcome sentence describing what the system can now do
3. Read the remaining task list as the session's pending work; do not copy it into the handover

### Session close (Step 8)
1. Mark all tasks completed this session with `[x]`
2. Do not compact — leave checked items in place for the next session's Step 1 to collapse
3. If all tasks in the sub-milestone are now complete and acceptance criteria are met, run [Sub-milestone close (Trigger B)](#sub-milestone-close-trigger-b) before closing the handover

### Sub-milestone close (Trigger B)

Trigger B fires when all tasks in the active sub-milestone are complete and acceptance criteria are met. **The agent must explicitly confirm with the operator that manual acceptance criteria (AC) have been verified on the host before running Trigger B.** It runs at Step 8, after tasks are marked and before the handover is closed. If the chat boundary falls before Trigger B has run, the next session's Step 1 must run it before compacting or creating the new handover — the roadmap will still show the completed sub-milestone as active, which is the signal that Trigger B has not run.

1. **Remove** the completed sub-milestone section from `roadmap.md` entirely — do not collapse it to outcome sentences, remove it. This mirrors how Trigger A removes completed major milestones: the sub-milestone is gone from the active roadmap, not summarised within it.
2. File any deferred items against the relevant future sub-milestone in `roadmap_future.md`
3. Promote the next sub-milestone's section into `roadmap.md` with scope paragraph and task list
4. Non-current sub-milestones retain scope paragraphs only — no accumulated deferrals from prior sub-milestones

### Major loop close (Trigger A)
1. Read `roadmap.md` and `changelog.md`
2. Write and output the changelog entry for the completed milestone (see [Changelog Format](#changelog-format))
3. Remove the completed milestone section from `roadmap.md` Upcoming Milestones
4. Update the Milestone Summary table row: remove anchor link, set status to `[Complete — see changelog](changelog.md)`
5. Promote the next milestone from `roadmap_future.md` into `roadmap.md` under `## Upcoming Milestones` (see [Milestone Promotion](#milestone-promotion) below)

**The separation between Step 8 and Step 1 is load-bearing.** Compacting at the same session that marks completions removes the only verification point — the operator cannot confirm what was done if the evidence is already collapsed. The session boundary enforces this: Step 8 marks, the next Step 1 compacts.

Produce all roadmap edits as targeted changes, not full-file rewrites.

---

## Rules

**Completed milestones** — extract to `changelog.md` using the format below, then remove the milestone entry from the roadmap entirely. Update the Milestone Summary table row to link to the changelog instead of the milestone anchor.

**Completed task groups** — replace the group header and checklist with a conceptual outcome sentence describing what the system can now do. Individual task completion is recorded in session handovers; the roadmap preserves group-level outcomes only.

**Decisions** — design decisions made during a session are recorded in the roadmap under the active sub-milestone entry. Format: short decision statement, rationale, and a link to the full record in the relevant architecture or discussion document. The roadmap is the accumulated decision log for the milestone; session handovers log which decisions were made per session.

**Active sub-milestone task list** — the active sub-milestone carries a full task checklist grouped by functional area. This is the canonical task list; the handover references it, does not copy it.

**Acceptance criteria** — the active sub-milestone carries an `**Acceptance criteria:**` block listing the end-to-end operator checks that must pass before the sub-milestone is considered complete. The task list records what is built; acceptance criteria record what the operator can verify once it is built. Criteria describe what the operator runs and observes — not what files contain or what tasks are checked off. A criterion that duplicates a task checklist item is not an acceptance criterion.

**Non-active sub-milestones** — carry an objective and scope paragraph only. No task checklist until the sub-milestone becomes active. Deferred items from prior sub-milestones are filed in `roadmap_future.md`, not accumulated in the scope paragraph.

**Task granularity** — identify the file and nature of change. Omit implementation detail; link to the discussion document if context is needed.

**Persistent sections** — Milestone Summary table, Upcoming Milestones, Known Limitations, Future Security & Network Hardening, and Governance Hardening are structural and must not be removed.

**Empty sections** — remove immediately.

---

## Milestone Promotion

Future milestone detail lives in `roadmap_future.md` to keep `roadmap.md` focused on the active milestone. When a milestone completes (Trigger A), the next milestone is promoted from `roadmap_future.md` into `roadmap.md`.

**Promotion steps:**
1. Move the milestone section from `roadmap_future.md` into `roadmap.md` under `## Upcoming Milestones`
2. Update the Milestone Summary table row in `roadmap.md`: add anchor link, set status to `In progress`
3. Remove the section from `roadmap_future.md`

**Which milestone to promote:** the next incomplete milestone in the Milestone Summary table order. If the next milestone has sub-milestones (e.g. M2.1, M2.2), promote the parent section and all sub-milestone sections together as a single block.

`roadmap_future.md` is a planning document, not a historical record — sections may be rewritten freely as understanding evolves. The changelog is the permanent record.

---

## Changelog Format

Changelog entries live in `docs/devlog/changelog.md`, appended in milestone order. Each entry is self-contained and can be produced without reading the rest of the file.

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
