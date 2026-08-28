# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Roadmap bullet "container_sig defects": resolve the `current_sig` memoization defect and the zero-file-set stdin-read hazard in `src/libs/container_sig.sh`.

## Investigation findings (scope-shaping)

Probing before fixing changed the shape of the fix:

1. **The memoization is provably inert.** The only production path is three nested command substitutions (`prune.sh → record_image_stale → image_is_stale → "$(current_sig …)"`); every `$()` forks a subshell, so `_current_sig_cache` writes evaporate with the innermost fork. Empirically: two in-shell calls, cache stays `()`. The cache has never cached anything through any production path since baseline `4159e93`.
2. **The roadmap's defect (key omits `repo_root`) is second-order** — latent inside the dead mechanism; reachable only via direct in-process calls, which only tests make.
3. **The optimization was never worth its cost**: full recompute measured at ~4 ms (30 files); worst-case redundant work across a 50-record inventory ≈ 0.2 s per prune invocation.
4. Zero-file set: GNU `xargs` without `-r` runs `sha256sum` once on empty input → reads stdin. In this pipeline stdin happens to be an EOF pipe (no real hang), but the no-hang property is accidental, not designed; the digest for an empty set is semantically meaningless ("hash of one empty file").
5. Adjacent latent edge found during scoping: an **empty sources array** makes bare `find` search the caller's cwd → wrong-tree hash. Callers don't produce this today; guard anyway (fail-closed, matching the lib's existing missing-path stance).

**Operator decision recorded:** option A chosen over repairing the cache — delete memoization entirely rather than fix the key and wire subshell-free calling (out-param convention) for a fraction-of-a-second payoff. Rationale: §3.3 no-speculative-infra; dead code removed beats dead code repaired.

## Scope

| File | Change |
|---|---|
| [`src/libs/container_sig.sh`](../../src/libs/container_sig.sh) | Delete `_current_sig_cache` + memo logic; `current_sig` becomes pure function of `(type, repo_root, provider)`; add `xargs -r`; fail closed on empty sources array; header comment updated |
| [`tests/test_container_sig.sh`](../../tests/test_container_sig.sh) | Replace two cache tests with recompute-per-call contract test; pin empty-set digest; new stub-based test proving `sha256sum` is never invoked on an empty set; new empty-sources-array fails-closed test |

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | No memoization remains; `current_sig` recomputes honestly per call and reflects live tree state between calls | grep clean (`_current_sig_cache` 0 hits in src/); `test_current_sig_recomputes_on_live_tree` green | accepted |
| AC2 | Empty file-set returns deterministic pinned digest without stdin-read behavior | pinned-digest test (e3b0c4…, the `-r` value) green | accepted |
| AC3 | Empty sources array fails closed with rc≠0 (no cwd search) | `test_container_sig_empty_sources_fails_closed` green | accepted |
| AC4 | Direct-execution behavior of prune/build/resume unchanged | test_prune, test_trace_build, test_session_inventory all green | accepted |
| AC5 | Full suite green and deterministic ×2 | 629 tests / 38 files / 0 failed ×2 | accepted |
| AC6 | No test comment anywhere asserts the removed memoization as live behavior | grep `memoiz` across scripts/ src/ tests/ docs/: only intentional historical-context comments remain | accepted |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Memoization inert since baseline (subshell indirection) — roadmap bullet text ("key ignores repo_root") described a symptom inside dead code | design flaw | Roadmap updated to record root cause; mechanism deleted |
| Empty-sources-array → `find` searches caller cwd (wrong-tree hash) | latent edge | Fail-closed guard added |

## Completed

| File | Change |
|---|---|
| [`src/libs/container_sig.sh`](../../src/libs/container_sig.sh) | `_current_sig_cache` + memo logic deleted; header comment updated; `xargs -r`; empty-sources-array fail-closed guard |
| [`tests/test_container_sig.sh`](../../tests/test_container_sig.sh) | Memoization tests → live-recompute contract test; empty-set test now pins the exact `-r` digest; new empty-args fail-closed test; stale memoization comment fixed. Net +1 assertion group (19 in file) |
| [`tests/test_trace_build.sh`](../../tests/test_trace_build.sh) | `test_current_sig_deterministic` comment + assertion messages: memoization contract language removed (was asserting "deterministic and memoized per (type, provider)" with O(2N)-hoisting rationale); deletion context noted |
| [`tests/test_session_inventory.sh`](../../tests/test_session_inventory.sh) | `fresh_sigs` comment: rationale updated from cache-isolation to plain process isolation |
| [`devlog/GOTCHAS.md`](../../devlog/GOTCHAS.md) | Recorded: close-out propagation greps must sweep the full tests tree |

Roadmap "container_sig defects" bullet marked complete with root-cause note.

## Decisions

| Decision | Rationale |
|---|---|
| Delete memoization instead of repairing (operator-approved option A) | Inert dead code since baseline — subshell indirection defeats it on every production path; payoff ~0.2 s worst case; §3.3 |
| Pinned-digest assertion over stub-based never-invoked assertion | A PATH-stubbed `sha256sum` shadows both pipeline stages including the legitimate outer hash; the pin alone distinguishes `-r` behavior from the stdin-read regression |

## Findings (added at operator review)

The initial close-out residue grep covered `src/`, `scripts/`, and the directly-edited
test file — not the whole tests tree — so two stale "memoized" contract comments
survived in `test_trace_build.sh` and `test_session_inventory.sh`. Caught by operator
challenge; fixed within this handover's scope. Process rule recorded in GOTCHAS: the
AC "no references remain" sweep is always `grep -rn <term> scripts/ src/ tests/ docs/ Makefile`,
never a file subset, and test comments asserting removed behavior count as residue.

## Deferred items

- Remaining M2.6 refactor-track bullets unchanged: empty-diff decision, savepoint rollback decision, error-message/control-flow coherence, naming one-liners.
