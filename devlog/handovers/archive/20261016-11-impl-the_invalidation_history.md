---
date: 2026-10-16
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - The invalidation history

## Objective

Count what invalidates each reasoning tier and measure the rebuild cost, so the layer install design weighs the trigger frequency against the build cost instead of recalling a rough figure from the chat logs.

## Scope

One new study record, [`devlog/discussions/20261016-study-settled-invalidation_history.md`](../../discussions/20261016-study-settled-invalidation_history.md). No Dockerfile, build script or source file changed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The per-tier trigger count is counted | `git log --oneline -- <path>` over 13 input paths: tier 1 one commit, tier 2 twenty-two across three Dockerfiles, tier 3 forty-six across its Dockerfiles plus 402 across its payload roots | Agent [x] |
| Every number states its command and reproduces | the record states the command beside each number, and a reviewer re-ran them across both sides | Agent [x] |
| The rebuild and cost side is measured, or its gap is named | the session store carries real builds in four transcripts only, all before the current tiering; the gap is named and no duration is estimated | Agent [x] |
| A count over a growing store reproduces | counts bound to transcripts dated before 2026-10-01, and the self-contamination finding is recorded with its exclusion rule | Agent [x] |
| The record follows the discussion convention | study skeleton and section order, the naming rule, `**Status:** active` | Agent [x] |
| Gates clean | `bash scripts/lint.sh`, clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The measurement is bounded to transcripts dated before 2026-10-01 | the store holds the transcript of the session doing the measuring, so a whole-store count grows during the measurement and does not reproduce | the study |
| The git invalidation count stands as the counted per-tier rebuild proxy | under the cache model, a change to a gated tier's Dockerfile is exactly what makes it rebuild | the study |

## Decisions pending

None. The study's open questions are filed with it and feed the layer install design row.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The session store cannot supply the rebuild cost, or an invocation-level rebuild count for the current tier shape, because real builds appear in four transcripts only, all before the current tiering. | measurement gap | M3.6.2 host build probe |
| The store is self-contaminating. It holds the transcript of the session doing the measuring, so any whole-store count grows during the measurement, and a transcript that quotes a build line adds a match. | method | any future count over the store |
| The trigger asymmetry the design must weigh: tier 1 changed once, tier 2 twenty-two times, tier 3 four hundred and forty-eight times across its Dockerfiles and payload roots. | measurement | the layer install design row |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261016-study-settled-invalidation_history.md`](../../discussions/20261016-study-settled-invalidation_history.md) | the new study |
| [`devlog/roadmap.md`](../../roadmap.md) | the invalidation-history row is complete |
