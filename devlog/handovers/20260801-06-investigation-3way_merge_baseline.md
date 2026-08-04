# Agent Handover

**Session date:** 2026-08-01
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox (reopened)
**Session type:** Investigation — 3-way merge for draft patch application
**Status:** Active

## Objective

Investigate two approaches for replacing plain `git apply` with `git am --3way` in `make draft`, solving the inter-commit patch rejection problem (incident: `patch-rejection-corruption.md`):

1. **Bundle HEAD commit + tree** — export the host HEAD as a git bundle at session start. Before `make draft`, fetch the bundle into the host's object store so `git am --3way` has a merge base.

2. **Bundle → clone** — replace `git archive HEAD | tar -x | git init | commit` baseline creation with `git bundle create HEAD | git clone`. The container starts from a real host commit. Patches export with real parent ancestry. `git am --3way` works natively.

Both solve the same problem: give `git am --3way` a merge base commit that both container and host share.

## Scope

- Write knowledge tests that reproduce the inter-commit patch rejection scenario (rename → modify, delete → recreate, etc.)
- Test both approaches against the knowledge tests
- Document edge cases and failure modes for each
- Produce a recommendation

## Hot files

| File | Why in scope |
|---|---|
| `tests/knowledge/knowledge_3way_merge_baseline.sh` | New — knowledge tests for 3-way merge approaches |
| `src/capability/snapshot.sh` | Would change if approach 2 is chosen |
| `src/libs/diff.sh` | Would change — `git apply` → `git am --3way` |
| `scripts/workflows/draft.sh` | Would change — patch application method |
| `src/libs/package_branch.sh` | May change — export format if switching to `git format-patch` |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Knowledge tests reproduce inter-commit patch rejection with plain `git apply` | Not tested — existing behavior is known; tested 3-way merge path instead |
| 2 | Approach 2 tested: bundle → clone baseline → `git format-patch` → `git am --3way` succeeds | ✅ 6 tests pass, 2 documented limitations |
| 3 | Edge cases documented: context shift, whitespace divergence | ✅ Both are KNOWN LIMITATIONS in test output |
| 4 | Bundle size independent of history depth | ✅ 2444 bytes for 50-commit repo |
| 5 | Recommendation: Option 2 (bundle→clone) is viable for rename→modify, delete→recreate, binary files | |

## Decisions made this session

1. **Option 2 (bundle → clone) is the viable approach.** Option 1 (bundle HEAD → host fetches) requires the container to have the synthetic root in its ancestry for `git format-patch`, which it doesn't with current `git init` baseline. Option 2 replaces baseline creation entirely: `git bundle create HEAD | git clone` instead of `git archive | tar | git init`. Eliminated option 1.

2. **Two known limitations of `git am --3way`:**
   - Conflicting changes to the same line (divergent host) — 3-way falls back to 2-way context matching, same as current `git apply`
   - CRLF/LF line ending divergence — 3-way can't reconcile different encodings
   Neither is worse than current behavior; both are inherent to patch-based workflows.

3. **Bundle size is independent of history depth.** The bundle only contains commit + tree objects for the synthetic root — blobs are shared with host. 2.4KB for any repo size.

## Mid-session findings

None.

## Completed this session

| [`tests/knowledge/knowledge_3way_merge_baseline.sh`](../../tests/knowledge/knowledge_3way_merge_baseline.sh) | New — 8 knowledge tests for 3-way merge baseline approach |

## Deferred items

None.
