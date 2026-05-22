# Roadmap Policy

Policy rules for `docs/devlog/roadmap.md`, `docs/devlog/roadmap_future.md`, and `docs/devlog/changelog.md`.

---

## When the Roadmap Is Touched

The roadmap is not updated continuously during a session. It is touched at two defined moments in the minor loop and once at major loop close. Do not update it outside these moments.

### During the session

1. Mark a task `- [x]` when its implementation satisfies the acceptance criteria — the agent's completion check
2. The marker signals "ready for operator verification at Step 7"
3. If the operator disagrees at Step 7, revert to `- [ ]`
4. Record the discrepancy as a resolved mid-session finding, reformulate the scope, and rewrite the incomplete task

### Session open (Step 1)

1. Read `roadmap.md`
2. Read the task list as the session's pending work; do not copy it into the handover

### Step 7 — Pre-close verification

Per [`handover_policy.md`](handover_policy.md#at-pre-close-verification-step-7), the agent presents a pre-close summary including:

- AC status per criterion
- **Proposed compaction entries** — for each fully-completed task group, the outcome summary that would replace its checklist if the operator accepts at Gate 3

The operator reviews the compaction proposal alongside AC verification at Gate 3. Accepted compaction text is applied mechanically at Steps 8–9.

### Session close (Steps 8–9)

After Gate 3 is released, these steps are mechanical — the operator has already reviewed and approved the compaction text and AC status.

1. **Apply approved compaction** — replace each fully-completed task group's checklist with the outcome summary the operator reviewed at Gate 3. Keep the `- [x]` marker. Compaction applies at every level of nesting.
2. If all tasks in the sub-milestone are now complete and acceptance criteria are met, run [Trigger B](#sub-milestone-close-trigger-b)
3. **Carry-forward escalation:** if a deferred item from the handover cannot be picked up in the immediately following session, add it as a named task entry under the current sub-milestone's task list

### Sub-milestone close (Trigger B)

Trigger B fires when all tasks in the active sub-milestone are complete and acceptance criteria are met. It runs at Steps 8–9, after the operator has released Gate 3. If Trigger B is pending (the roadmap still shows the completed sub-milestone as active), the next session's Step 1 runs it after creating the handover but before presenting the scope proposal. Record the Trigger B execution in the handover's Completed table. Present the post-Trigger-B roadmap state as part of the scope proposal.

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

**Compaction and verification.** Compaction runs after the operator has confirmed acceptance criteria at Step 7 and released at Gate 3. The operator reviews proposed compaction text as part of the pre-close summary — Gate 3 is the verification surface. Steps 8–9 apply the approved changes mechanically. Compaction does not lose auditability — the `- [x]` outcome summary persists in the roadmap, and the session handover retains full file-level change detail.

Produce all roadmap edits as targeted changes, not full-file rewrites.

---

## Rules

**Completed milestones** — extract to `changelog.md` using the format below, then remove the milestone entry from the roadmap entirely. Update the Milestone Summary table row to link to the changelog instead of the milestone anchor.

**Completed task groups** — compacted to a `- [x]` markdown task list entry with a 1–3 sentence outcome summary describing what was built. Task breakdowns, file lists, implementation notes, and "Depends on" / "Prerequisite for" lines referencing now-completed items are removed — the session handover retains the detail. Design document links and "Not in scope" / deferred tags survive. The operator reviews proposed compaction text at Gate 3; accepted text is applied mechanically at Steps 8–9.

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
