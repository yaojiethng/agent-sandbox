# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: seed correctness)
**Type:** Impl
**Status:** Closed

## Objective
Implement the roadmap item "Seeder stash-clear": the seeder removes the host stash stack from the volume copy after the native `.git` copy, per the settled ADR entry (2026-09-11) and study `20260911-study-stash_copy_prevention.md`.

## Scope
- `src/capability/seed_volume.sh`: after the `.git` copy, clear stashes on the volume copy only (`git stash clear`); fail closed on error; add the empty-stash assertion to the self-verification.
- `tests/test_seed_volume.sh`: new test -- a fixture repo with stash entries seeds successfully, the host stash stack is untouched, and the volume has an empty stash stack.
- Roadmap: item marked done.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | A fixture repo with stash entries seeds; volume `git stash list` is empty; host `git stash list` unchanged | test | Agent -- pass |
| AC2 | Self-verification asserts the empty stash stack | read + test | Agent -- pass |
| AC3 | Full suite passes | suite | Agent -- pass (734/734) |
| AC4 | Roadmap item closed | grep | Agent -- pass |

## Completed

| File | Change |
|---|---|
| [`src/capability/seed_volume.sh`](src/capability/seed_volume.sh) | `git stash clear` on the volume copy after the `.git` copy; empty-stash tripwire in the self-verification |
| [`tests/test_seed_volume.sh`](tests/test_seed_volume.sh) | `test_seeder_clears_host_stash`: two-stash fixture seeds, volume stack empty, host stack untouched |
| [`devlog/roadmap.md`](devlog/roadmap.md) | Item marked done |

## Deferred items

None.
