# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: seed correctness)
**Type:** Design
**Status:** Closed

## Objective

Record, in the design record owning the seed contract, the operator-raised question: can the seeder avoid copying the entire `.git`?

## Scope

Chat analysis from the stash study follow-up, formalized. No code changes; no contract change.

## Analysis summary

- History is functionally unnecessary: no copy-mode consumer walks below `init_sha`.
- A subset transport must reconstruct the index (staging state is a verified invariant) and would need repack/bundle machinery over `objects/` -- the transform class the 2026-09-04 redesign retired.
- Decision: full native copy stands; stashes are removed surgically post-copy (`git stash clear` on the volume, roadmap item open); history-trim rejected absent a measured seed-cost driver, where the mount model is the designed answer.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | ADR entry dated 2026-09-11 records the analysis and decisions | read ADR | Agent -- pass |
| AC2 | Study status settled; Resolution points at the ADR | read study | Agent -- pass |
| AC3 | ADR Current marker updated | read | Agent -- pass |

## Completed

| File | Change |
|---|---|
| [`docs/adr/sandbox_delivery_model.md`](docs/adr/sandbox_delivery_model.md) | New 2026-09-11 entry: full `.git` copy is deliberate; stash disposition (post-copy clear) and history-trim disposition (rejected) |
| [`devlog/discussions/20260911-study-stash_copy_prevention.md`](devlog/discussions/20260911-study-stash_copy_prevention.md) | Status settled; Resolution references the ADR entry |

## Deferred items

Seeder stash-clear implementation (roadmap item) -- unchanged.

## What's Next

Implement the seeder stash-clear with its test to close the roadmap item.
