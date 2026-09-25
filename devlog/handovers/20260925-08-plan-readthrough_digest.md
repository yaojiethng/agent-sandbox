# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Plan
**Status:** Closed

## Objective

Assign every unresolved read-through finding to a track, a campaign, or a named instance, and open the operator-surface design that the digest surfaced.

## Scope

The read-through close's second half: the digest. It reads the 312 findings and the process review, decides the track for each sector and each design note, creates the two tracks the read-through needed and had nowhere to put, reframes one, and writes the operator-surface design document. It implements nothing.

## Carried forward

| Item | From handover |
|---|---|
| The read-through close: the plan session that decides which findings become roadmap tasks and in what grouping | `20260925-07-refactor-structured_findings_and_json_tooling` |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| Every unresolved finding is attached to a track, a campaign, or a named instance | the roadmap rows and the review's remaining-work table | Agent [x] |
| Each of the five proposed sector notes has a home | the roadmap: A and B as row sets in T10 and T11, C and I in M3.1, F split between T9 and T4 | Agent [x] |
| The design notes that had no home have one | T7's git item subsumes two, T10 takes the CLI and interactive notes, T9 takes the image rows | Agent [x] |
| The operator-surface design follows the required section order | the doc's Context, Options Considered, Decision, Consequences | Agent [x] |
| The design offers at least two real options | four, each with a cost | Agent [x] |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | every assignment lands here: T1, T4, T7, T8, T9, T10, T11 and M3.1 |
| [`devlog/discussions/20260925-design-draft-operator_surface.md`](../discussions/20260925-design-draft-operator_surface.md) | new: the operator-surface design |
| [`devlog/discussions/20260925-design-draft-readthrough_process_review.md`](../discussions/20260925-design-draft-readthrough_process_review.md) | its decision items and remaining-work table now name the tracks |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.md`](../discussions/20260924-design-active-test_suite_readthrough.md) | the proposed-order section cites the data file's counts |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| M3.1 stays the gate-and-feedback milestone | its text is already specific; absorbing the read-through's tail would make it mean whatever the pass found | the roadmap's M3.1 rows |
| Track boundaries follow the unit of approval, and a group gets its own track only when it would extract as a milestone | the rule the operator set for tracks as rough groups | the roadmap |
| Review-workflow refinement is a T1 draft row | the context is current and T1 owns the workflow surface, but this milestone does not own the feature | T1's review-pass workflow row |
| Two new tracks: T10 for the argument, configuration and operator surface, T11 for the persisted record formats | 58 note rows had no home, and neither group fits an existing track: T10's rows are not records and T11's rows are not arguments | T10 and T11 |
| T9 is reframed as identity labels, grouped by stage: stamp, carry, read, validate | the identity is a label set carried by the pipeline, not a subsystem beside it, so T9 owns the invariant across carriers | T9's lead-in |
| The image, container and build-path contracts go to T9, and onboarding to T4 | the labels are carried by the docker artifacts, and onboarding is the install surface T4 already owns | T9 and T4 |
| One T7 item for the git-related work, subsuming the pipeline and workflow notes | they share one undefined boundary: which files may run git | T7's git row |
| J was a relational bucket, not a concern, and its six rows attach individually | the read-through's own classes for those rows are cohesion, propagation, boundary and channel hygiene, none of which is a subject | the roadmap |
| The rectification campaign takes the conventions edit first | the campaign needs to know where a unit belongs before it writes 130 of them | M3.1's rectification row |
| The whole session lands as one Plan handover and one commit | the digest is scoping work, and Plan maps to the `docs` commit type | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The register's five proposed sector notes and the tree's six written design notes overlap in one file only | contradiction | the discussion-corpus pass is now a T8 row, with this mismatch as its first evidence |
| Note F has no residue: with the build layer distributed, its sections are all owned elsewhere | scope change | recorded as the first candidate for the corpus pass rather than written |
| The read-through's sector H is three surfaces, not one, and seven of its rows close with a single gate | steering | the operator-surface design |
| The mutation suite's gate placement cannot be decided before its runtime is measured | blocker | named inside the mutation row rather than left implicit |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | M3.1: the rectification row rewritten, the verdict row, the dry-run row, the mutation gate note, and the digest recorded in the close row; T1: the review-pass workflow row and host requirements; T4: onboarding and refresh, and the architecture row's named instances; T7: one git item in four parts; T8: the discussion-corpus pass; T9: reframed, with four image and container rows; T10 and T11 created |
| `devlog/discussions/20260925-design-draft-operator_surface.md` | new: the three surfaces, four options, the recommended vocabulary and gate, and the consequences |
| `devlog/discussions/20260925-design-draft-readthrough_process_review.md` | the two open decision items name their T1 row, and the remaining-work table names tracks |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.md` | the proposed-order section reads its counts from the findings data file |

## Deferred items

None. The design doc stays at draft until it settles, and settling it produces an ADR per the design-doc policy.

## What's Next

The next iteration is implementation. M3.1 holds four rows: the rectification campaign (its conventions edit first), the verdict vocabulary, the dry-run harness, and the mutation gate decision. T7's git item is the largest single row the digest created.

Watch-outs (three): the design notes are drafts, so a track row names a design that still needs settling before its implementation; the coverage campaign must not start before the conventions edit lands, or it will file 130 units in the wrong places; the register's findings data carries no assignment field, so a track's evidence rows are named in the roadmap row and not queryable from the data yet.

Read at iteration start: this handover, the roadmap rows it created, and the register's Format section.

**Conclusions from this iteration:** the read-through's tail is now fully assigned, and the two tracks it needed - the argument and operator surface, and the persisted record formats - were the ones no existing track could hold.
