# Milestone Policy

Governs the major loop: the planning process that runs after a major milestone closes and before session work on the next major milestone begins. Defines how sub-milestones are scoped, how stories and investigations are used as planning tools, and what "ready to session" means for a milestone.

This document is read during the major loop. For session execution, see [`iteration_policy.md`](iteration_policy.md).

---

## Purpose of the Major Loop

A major milestone (M1, M2, M3...) is a capability boundary — a meaningful change in what the system can do. Sub-milestones (M2.1, M2.2...) are the implementation increments that deliver it. The major loop exists to scope those increments before coding begins.

The output of the major loop is not a complete plan for every sub-milestone. It is:
- A scoped and ready M2.1 (the first sub-milestone to session)
- Sufficient understanding of M2.2 onward to sequence them correctly
- Explicit records of what cannot yet be scoped and why

Sub-milestones that depend on earlier implementation decisions are flagged and deferred. Their stories remain open. They are scoped during the design step of the relevant minor loop session, not during the major loop.

---

## Trigger

The major loop triggers when `roadmap_policy.md` Trigger A fires — a major milestone has been extracted to the changelog and the next major milestone has been promoted from `roadmap_future.md` into `roadmap.md`.

Do not begin the major loop before the prior milestone is fully closed in the changelog.

---

## Inputs

Before beginning, read:
- The promoted milestone section in `roadmap.md` — objective, sub-milestones, any existing task lists or open decisions
- `roadmap_future.md` — remaining future milestone context
- `changelog.md` — the most recent entry, to confirm the prior milestone is fully closed
- Any open stories or investigations in `docs/discussions/` that were deferred from the prior major loop

---

## Scoping Criteria

A sub-milestone is **ready to session** when:
- Its objective is stated in one sentence
- Its design decisions are resolved and recorded with rationale — not just listed as open questions
- Its task list is specific enough that each item identifies a file and a nature of change
- Its dependencies on prior sub-milestones are named explicitly

A sub-milestone is **not ready to session** when:
- It has open design questions that can be answered now (these must be resolved before closing the major loop)
- It has open design questions that depend on earlier implementation decisions (these are explicitly deferred and flagged)
- Its task list is aspirational rather than specific

---

## Stories in the Major Loop

Stories are the planning tool for areas where the design is not settled. A story frames the problem and the investigation space — it does not propose a solution.

Open a story when:
- A sub-milestone objective is understood but the approach is not agreed
- Multiple candidate approaches exist and need evaluation before a direction can be chosen
- A constraint or threat surface needs investigation before the design can be confirmed

Do not open a story when:
- The design is already agreed and recorded (write the roadmap entry directly)
- The uncertainty depends on an earlier sub-milestone's implementation decisions (defer and flag — the story opens during the relevant minor loop)

See [`story_policy.md`](story_policy.md) for story format, lifecycle, and graduation rules.

---

## Investigations in the Major Loop

Investigations evaluate a specific candidate approach within a story. One investigation per candidate. An investigation runs until it can produce a recommendation.

Commission an investigation when:
- A story has identified two or more candidate approaches that need comparative evaluation
- A specific option requires research, feasibility testing, or threat modelling before it can be recommended

An investigation is not required when a story has only one viable approach — evaluate that approach within the story itself.

See [`investigation_policy.md`](investigation_policy.md) for investigation format, lifecycle, and recommendation rules.

---

## Roadmap Entry Production

When a story's open questions are resolved, graduate it to a roadmap entry:

1. Close the story: add a Resolution section, update Status to `Resolved`, remove from the roadmap User Stories list. See [`story_policy.md`](story_policy.md) — Closure.
2. Write the sub-milestone entry: objective, resolved design decisions with rationale, task list. Place in `roadmap_future.md` if the sub-milestone is not yet active; place directly in `roadmap.md` under the current milestone if it is next.
3. Confirm the entry meets the scoping criteria above before marking the story closed.

The roadmap entry is the canonical record of the scoped sub-milestone. The story is the reasoning record for how the design was reached. Both must exist before the sub-milestone is sessioned.

---

## Closing the Major Loop

The major loop closes when:
- M2.1 (or the first active sub-milestone) has a complete, confirmed roadmap entry
- All stories that could be resolved have been resolved and graduated
- All stories that cannot be resolved (deferred dependencies) are explicitly flagged in the roadmap entry for the sub-milestone whose session will resolve them
- The next handover stub has been created and its Hot files section populated

At this point, minor loop sessions may begin.

---

## References

| Document | Purpose |
|---|---|
| [`iteration_policy.md`](iteration_policy.md) | Full two-loop workflow; minor loop session steps |
| [`story_policy.md`](story_policy.md) | Story creation, lifecycle, graduation, closure |
| [`investigation_policy.md`](investigation_policy.md) | Investigation structure, lifecycle, recommendation |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update sequence, milestone promotion, changelog format |
