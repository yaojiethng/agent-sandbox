# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: seed correctness)
**Type:** Design
**Status:** Open

## Objective

Revisit the seed's cleanliness posture per the operator's question: does leaving unreachable host data (stash objects, reflogs) in the volume violate the cleanliness goal, and do `git clone` or `git bundle` offer a better transport than the native `.git` copy?

## Scope

Investigation + design record. Mechanics validated empirically in /tmp fixtures (no repo changes beyond the study doc and handover).

## Analysis summary

- The snooping surface is real: on this repo, reflog-anchored session junk dominates -- gitdir 26 MB vs 4.2 MB after prune; `fsck --unreachable` lists stash commits/blobs and session commits.
- Clone and bundle both fail on the **index**, not checkout semantics: staged blobs exist in no commit, so a HEAD bundle or `--depth 1` clone lacks the objects the index references; closing the gap means re-staging by replaying `diff --cached` -- the reconstruction class the 2026-09-04 redesign retired.
- Copy-then-prune (reflog expire + `gc --prune=now`, conditional on `fsck --unreachable` finding something, fsck-empty tripwire after) achieves the clean result with zero reconstruction; measured 0.6 s on this repo; parity unaffected (gc touches no refs/index/worktree).
- History truncation (shallow boundary at init_sha, non-HEAD ref deletion) is mechanically available but changes what the agent can *see*, not just what is reachable -- separate decision.

## Recommendation

Adopt copy-then-prune (Option B): `fsck` probe -> conditional `reflog expire` + `gc --prune=now` -> fsck-empty tripwire; supersede the ADR's "residual recorded, accepted" paragraph.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Study doc exists with mechanism findings, clone/bundle rejection grounded in the index gap, and a recommendation | read | Agent -- pass |
| AC2 | Prune mechanics validated empirically (gc removes all unreachable; parity unaffected; timing measured) | rerun /tmp experiment | Agent -- pass |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20260911-study-seed_object_store_cleanliness.md`](devlog/discussions/20260911-study-seed_object_store_cleanliness.md) | New study: findings, four-option comparison, recommendation |

## Deferred items

Implementation of Option B (roadmap item on adoption); history-truncation decision (separate).

## What's Next

Operator adopt decision on Option B, then a single impl iteration.
