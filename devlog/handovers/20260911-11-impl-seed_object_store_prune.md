# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: seed correctness)
**Type:** Impl
**Status:** Closed

## Objective
Implement Option B from study `20260911-study-seed_object_store_cleanliness.md`: the seeder prunes unreachable objects from the volume copy so the sandbox baseline carries no host archaeology.

## Scope
- `src/capability/seed_volume.sh`: after the stash clear, probe `git fsck --unreachable`; if anything is found, `git reflog expire --expire=now --all` + `git gc --prune=now --quiet`; fail closed if the probe errors or unreachable objects survive the prune.
- `tests/test_seed_volume.sh`: new test -- a fixture with stash entries and a dangling blob seeds; the volume has zero unreachable objects and the dangling object is absent; the host stack is untouched.
- `docs/adr/sandbox_delivery_model.md`: supersede the "residual recorded, accepted" paragraph with the prune mechanism.
- `devlog/roadmap.md`: add + close the item.
- Study: Resolution set to adopted.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Fixture with stash + dangling blob seeds; dest `fsck --unreachable` empty; dangling object unreadable in dest; host untouched | test | Agent -- pass |
| AC2 | Probe/prune failures die with readable errors (fail closed) | read | Agent -- pass |
| AC3 | ADR residual paragraph superseded | read | Agent -- pass |
| AC4 | Full suite passes | suite | Agent -- pass (738/738) |

## Completed

| File | Change |
|---|---|
| [`src/capability/seed_volume.sh`](src/capability/seed_volume.sh) | fsck probe -> conditional reflog expire + `gc --prune=now` -> fsck-empty tripwire, all fail closed |
| [`tests/test_seed_volume.sh`](tests/test_seed_volume.sh) | `test_seeder_prunes_unreachable_objects`: stash + dangling-blob fixture; volume fsck-clean, dangling blob absent, host untouched |
| [`docs/adr/sandbox_delivery_model.md`](docs/adr/sandbox_delivery_model.md) | 2026-09-11 entry: residual paragraph superseded by the prune mechanism |
| [`devlog/discussions/20260911-study-seed_object_store_cleanliness.md`](devlog/discussions/20260911-study-seed_object_store_cleanliness.md) | Study settled; Resolution records adoption |
| [`devlog/roadmap.md`](devlog/roadmap.md) | New item recorded and closed |

## Deferred items
History truncation (shallow boundary, non-HEAD ref deletion) -- separate decision, not in scope.
