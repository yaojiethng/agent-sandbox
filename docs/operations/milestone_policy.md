# Milestone Policy

Governs the major loop: the planning process that runs after a major milestone closes and before session execution on the next major milestone begins. Defines how sub-milestones are scoped, how stories and investigations are used as planning tools, and what "ready to proceed" means for a milestone.

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

The major loop triggers when a top-level milestone closes (via post-close bookkeeping in `roadmap_policy.md`) — the milestone has been extracted to the changelog and the next major milestone promoted from `roadmap_future.md` into `roadmap.md`.

Do not begin the major loop before the prior milestone is fully closed in the changelog.

---

## Inputs

Before beginning, read:
- The promoted milestone section in `roadmap.md` — objective, sub-milestones, any existing task lists or open decisions
- `roadmap_future.md` — remaining future milestone context
- `changelog.md` — the most recent entry, to confirm the prior milestone is fully closed
- Any open stories or investigations in `devlog/discussions/` that were deferred from the prior major loop

---

## Scoping Criteria

A sub-milestone is **ready to proceed** when:
- Its objective is stated in one sentence
- Its design decisions are resolved and recorded with rationale — not just listed as open questions
- Its task list is specific enough that each item identifies a file and a nature of change
- Its dependencies on prior sub-milestones are named explicitly

A sub-milestone is **not ready to proceed** when:
- It has open design questions that can be answered now (these must be resolved before closing the major loop)
- It has open design questions that depend on earlier implementation decisions (these are explicitly deferred and flagged)
- Its task list is aspirational rather than specific

---

## Stories in the Major Loop

Stories frame the problem space when the approach is not yet settled. See [`story_policy.md`](story_policy.md) for when to open or skip a story, and for format, lifecycle, and graduation rules.

---

## Investigations in the Major Loop

Investigations evaluate a specific candidate approach within a story. See [`study_policy.md`](study_policy.md) for when to commission an investigation, and for format, lifecycle, and recommendation rules.

---

## Roadmap Entry Production

When a story's open questions are resolved, graduate it to a roadmap entry per [`story_policy.md`](story_policy.md) (closure) and [`roadmap_policy.md`](roadmap_policy.md) (entry format and placement). Before marking the story closed, confirm the entry meets the scoping criteria above. Both the roadmap entry and the closed story must exist before the sub-milestone is sessioned.

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
| [`study_policy.md`](study_policy.md) | Study structure, lifecycle, recommendation |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update sequence, milestone promotion, changelog format |
