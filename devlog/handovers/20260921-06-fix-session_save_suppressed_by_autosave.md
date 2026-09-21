# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** impl
**Status:** Closed
**Index:** 06

## Objective

Fix the session/autosave save count mismatch: the latest autosave checkpoint has no corresponding session save, even though the autosave holds real work (5 commits). The session export is being suppressed by its own no-op guard. Close the dry-run gap that cannot see the failure.

## Scope

- Fix `_session_export` so the session export resolves its baseline from the durable branch point (`SESSION_STATE.init_sha`), not from the ephemeral autosave checkpoint.
- Extract the exit-time session-export decision into a sourceable function so the entrypoint, the dry-run capability probe, and the unit tests invoke the same shipped logic.
- Add a dry-run capability section that exercises the decision on an isolated temp fixture (committed + uncommitted changes, nonempty autosave) and asserts a session save would run, without touching the live volume.
- Add an integration-style unit test asserting the coupling (autosave nonempty -> session export runs).
- Update the affected docs.
- Add the roadmap task under T6.
- Run the test suite and the lint gate; keep the suite green and lint Clean.

## Carried forward

None.

## Open questions

_None -- operator directives captured in chat._

## Acceptance criteria

- [ ] A session with real work relative to the branch point always produces a session export at exit, regardless of autosave state
- [ ] A session with no work (clean tree at the branch point) still skips the session export
- [ ] The dry-run capability probe detects the session-export suppression and asserts a session save would run (committed and uncommitted content)
- [ ] The session-export decision is sourced from one function shared by entrypoint, dry-run, and tests
- [ ] Dry-run and unit tests never pollute the live session volume
- [ ] Test suite green; markdown lint Clean

## Decisions

| Decision | Rationale |
|---|---|
| Session export baseline is the durable branch point (init_sha), never the autosave checkpoint | the operator: the sandbox branch point is already the durable baseline and needs no amendment; the autosave dir is an ephemeral overwritten fallback slot, not a durable record |
| Extract `session_export_needed` into `session_save_policy.sh` | one shipped decision function shared by entrypoint, dry-run, and tests; prevents mirrored logic from drifting |
| Dry-run exercises the decision on a temp fixture, not the live volume | the probe must not pollute the real session-diffs |

## Hot files

| File | Why in scope |
|---|---|
| `src/capability/entrypoint.sh` | `_session_export` baseline bug |
| `src/libs/session_save_policy.sh` | new `session_export_needed` |
| `scripts/dry_run_capability.sh` | dry-run gap |
| `tests/test_session_save_guard.sh` | coupling test |
| `devlog/roadmap.md` | T6 task row |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `_session_export` fed the autosave dir into `save_decision`; its moving HEAD is treated as the baseline and suppresses the export | bug | durable session exit record lost in the common case (autosave current with the final state) |
| `dry_run_capability.sh` never exercises the session-export decision | gap | green dry-run carries no signal about this failure |

## Completed

| File | Change | Status |
|---|---|---|
| `devlog/handovers/20260921-06-fix-session_save_suppressed_by_autosave.md` | opened this handover | done |
| `devlog/roadmap.md` | added the T6 task row | done |
| `src/libs/session_save_policy.sh` | added `session_export_needed` (branch-point baseline) | done |
| `src/capability/entrypoint.sh` | `_session_export` uses `session_export_needed`, drops the autosave baseline | done |
| `scripts/dry_run_capability.sh` | added the `session_data session-export decision` section (temp fixture, committed + uncommitted) | done |
| `tests/test_session_save_guard.sh` | added 2 tests pinning the coupling and the skip arm | done |
| `docs/architecture/sandbox_lifecycle.md` | rewrote the No-op guard section: autosave and session export have distinct baselines | done |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| _none_ |  |  |

## What's Next

The session save must survive the exit-time decision. The durable branch point is the baseline.
