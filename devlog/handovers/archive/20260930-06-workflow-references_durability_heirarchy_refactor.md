# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Centralize the document durability hierarchy in one `### Durability` home and make every other section reference it, so the durable/transient taxonomy is specified once instead of per section.

## Scope

The consolidated refactor consolidated from the pointers raised in the reopened `20260930-05` session and this one: the References merge, handoff-points and link-anchors as reference-rule special cases, the durability-home placement, the Concepts-docs conflation, and the Record-Lifecycle durability mixing. One unit, one vertical slice; landed as one commit.

## Carried forward

Consolidates the pointers from the reopened `20260930-05` session, all claimed here.

## Acceptance criteria

1. The durable/transient taxonomy lives in exactly one home, `### Durability` under `## Document Types`. Accepted.
2. `### References` is a link and number styling convention that applies the taxonomy without re-specifying it. Accepted.
3. The handoff-points and link-anchors rules fold into `### References` as special cases; no stale anchor remains. Accepted.
4. `### Concepts docs` tells apart the concept doc, the ADR, and the discussion; ADR-creation guidance moves to `adr_policy.md`. Accepted.
5. `### Records state, not session history` keeps its procedural core and defers durability to Document Types. Accepted.
6. Lint clean; no stale references to the retired subsections. Accepted.

## Hot files

| File | Why in scope |
|---|---|
| `docs/operations/documentation_policy.md` | `### Durability` home; `### References` merge; Concepts docs and Records state re-homed |
| `docs/operations/adr_policy.md` | receives the suggest-an-ADR and distill-a-design-doc guidance |
| `AGENTS.md` | retarget the numbering link to `#references`; `persistent record` to durable |
| `devlog/AGENT_FEEDBACK.md` | retarget the section reference to `### References` |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Document Types owns the durability taxonomy | durability is a classification of document types; Document Types already notes handover as a session log | `## Document Types -- Durability` |
| `### References` stays a link/number styling convention (single responsibility) | it applies durable/transient, it does not define it | `## Communication Standards -- References` |
| `### References` keeps the one-indexable-axis concrete example | the advisor flagged the review/options example as load-bearing; AGENT_FEEDBACK numbering depends on it | Reference axis paragraph |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The durability taxonomy was re-specified per section (operator, 2026-09-30) | steering | current iteration - centralized in Document Types |
| Making `### References` the durability home would conflate concerns (operator, 2026-09-30) | steering | current iteration - References stays styling; taxonomy moves to Document Types |
| `### Concepts docs` could not distinguish concept, ADR, and discussion (operator, 2026-09-30) | steering | current iteration - disentangled into the three roles with their durability |

## Completed

| File | Change |
|---|---|
| `docs/operations/documentation_policy.md` | added `### Durability` under Document Types; merged Numbering + Link sparingly + handoff points + Link anchors into one `### References`; disentangled `### Concepts docs` into concept/ADR/discussion; Records state defers durability to Document Types |
| `docs/operations/adr_policy.md` | moved "Suggest an ADR when" and "Distill a design doc into an ADR" into `## When an ADR begins` |
| `AGENTS.md` | Context-aware numbering links to `#references`; `persistent record` became `durable artifact` |
| `devlog/AGENT_FEEDBACK.md` | retargeted the section reference to `### References` |

## Deferred items

None.

## What's Next

Next sub-milestone: M3.2.2 - Audit and Review Workflow Cleanup.

No sub-milestone completed this iteration; no roadmap maintenance needed.

The provider-layer AGENTS shadow still carries two compact bullets (`Numbering:` and `Link sparingly.`) that reflect the merged `### References`; they carry no anchor and remain valid. Optionally align their labels to the unified home in a later pass if desired.
